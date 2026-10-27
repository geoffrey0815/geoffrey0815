import Foundation
import SwiftData
import VoidCore

/// recording file → transcript → summary → webhook. Everything but the webhook is on-device.
@MainActor
final class ProcessingPipeline {
    static let shared = ProcessingPipeline()

    var transcriber: any Transcriber = SpeechAnalyzerTranscriber()
    var summarizer = Summarizer()
    var delivery = WebhookDelivery()

    private var context: ModelContext { Persistence.container.mainContext }
    /// Meetings being processed by this process, so recovery never runs one twice.
    private var inFlight: Set<String> = []
    private var didRecover = false
    /// Meetings with a webhook request in flight; a resend or retry for them is dropped.
    private var delivering: Set<String> = []

    /// - Parameter liveTranscript: transcript produced while recording; when missing or
    ///   empty (live transcription failed), the recorded file is transcribed instead.
    func process(meetingID: String, liveTranscript: [MeetingResult.Segment]? = nil) async {
        guard !inFlight.contains(meetingID), let meeting = fetch(meetingID), let audioURL = meeting.audioURL else { return }
        inFlight.insert(meetingID)
        defer { inFlight.remove(meetingID) }
        do {
            meeting.status = .transcribing
            save()
            let locale = Locale(identifier: meeting.language)
            if let liveTranscript, !liveTranscript.isEmpty {
                meeting.transcript = liveTranscript
            } else {
                meeting.transcript = try await transcriber.transcribe(fileAt: audioURL, locale: locale)
            }

            meeting.status = .summarizing
            save()
            let summary = try await summarizer.summarize(meeting.transcript, outputLanguage: AppSettings.summaryLanguage)
            meeting.title = summary.title
            meeting.summary = summary.summary
            meeting.decisions = summary.decisions
            meeting.actionItems = summary.actionItems.map {
                .init(task: $0.task, owner: $0.owner.isEmpty ? nil : $0.owner)
            }
            meeting.status = .ready
            meeting.errorMessage = nil
            save()

            if AppSettings.audioRetentionDays == 0 {
                deleteAudio(of: meeting)
                save()
            }
        } catch {
            meeting.status = .failed
            meeting.errorMessage = error.localizedDescription
            save()
            return
        }
        await deliver(meetingID: meetingID)
    }

    /// Sends a ready meeting. `manual` (the "다시 보내기" button) resets the retry budget.
    func deliver(meetingID: String, manual: Bool = false) async {
        guard !delivering.contains(meetingID), let meeting = fetch(meetingID), meeting.status == .ready else { return }
        delivering.insert(meetingID)
        defer { delivering.remove(meetingID) }
        guard let url = AppSettings.webhookURL else {
            meeting.delivery = .notConfigured
            meeting.nextDeliveryAt = nil
            save()
            return
        }
        if manual { meeting.deliveryAttempts = 0 }
        meeting.delivery = .pending
        // A lease: if the app dies mid-request, the delivery becomes due again in a minute.
        meeting.nextDeliveryAt = .now.addingTimeInterval(60)
        save()

        let outcome = await delivery.send(
            meeting.result(includeTranscript: AppSettings.includeTranscript),
            to: url,
            secret: Keychain.string(for: Keychain.webhookSecret),
            authorization: Keychain.string(for: Keychain.webhookAuthorization)
        )
        meeting.deliveryAttempts += 1
        switch outcome {
        case .delivered:
            meeting.delivery = .delivered
            meeting.errorMessage = nil
        case .rejected(let reason):
            meeting.delivery = .failed
            meeting.errorMessage = "Webhook이 거부했습니다: \(reason)"
        case .retryable(let reason):
            if let delay = WebhookDelivery.policy.delay(afterAttempt: meeting.deliveryAttempts) {
                let due = Date.now.addingTimeInterval(delay)
                meeting.nextDeliveryAt = due
                meeting.errorMessage = "Webhook 전송 실패 (\(reason)) — 다시 시도합니다."
                WebhookDelivery.scheduleBackgroundRetry(at: due)
                // While the app stays alive, retry in-process as well.
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    await self?.retryDueDeliveries()
                }
            } else {
                meeting.delivery = .failed
                meeting.errorMessage = "Webhook 전송 실패: \(reason)"
            }
        }
        save()
    }

    /// Retries every pending delivery whose time has come. Called on launch, when the app
    /// becomes active, and from the background refresh task.
    func retryDueDeliveries() async {
        let now = Date.now
        let pending = Meeting.Delivery.pending.rawValue
        let due = (try? context.fetch(FetchDescriptor<Meeting>(
            predicate: #Predicate { $0.deliveryRaw == pending && $0.nextDeliveryAt != nil }
        ))) ?? []
        for meeting in due where (meeting.nextDeliveryAt ?? .distantFuture) <= now {
            await deliver(meetingID: meeting.id)
        }
    }

    /// Picks up work the app was killed in the middle of. Runs once per launch.
    func recoverInterruptedWork() async {
        guard !didRecover else { return }
        didRecover = true
        let all = (try? context.fetch(FetchDescriptor<Meeting>())) ?? []
        for meeting in all {
            switch meeting.status {
            case .recording:
                // The app may have been launched by a widget tap that is recording right now.
                guard meeting.id != RecordingController.shared.currentMeetingID else { continue }
                // AAC files written up to the crash are usually readable; try to salvage them.
                meeting.endedAt = meeting.endedAt ?? .now
                meeting.endReason = .manual
                meeting.status = .transcribing
                save()
                await process(meetingID: meeting.id)
            case .transcribing, .summarizing:
                await process(meetingID: meeting.id)
            case .ready, .failed:
                break
            }
        }
        await retryDueDeliveries()
        purgeExpiredAudio()
    }

    /// Deletes recordings of processed meetings older than the retention setting. Failed
    /// meetings keep their audio so they can be reprocessed.
    func purgeExpiredAudio() {
        guard let days = AppSettings.audioRetentionDays, days > 0 else { return }
        let cutoff = Date.now.addingTimeInterval(-TimeInterval(days) * 86_400)
        let ready = Meeting.Status.ready.rawValue
        let expired = (try? context.fetch(FetchDescriptor<Meeting>(
            predicate: #Predicate { $0.statusRaw == ready && $0.audioFileName != nil && $0.startedAt < cutoff }
        ))) ?? []
        guard !expired.isEmpty else { return }
        expired.forEach(deleteAudio(of:))
        save()
    }

    /// Clears the reference only once the file is really gone, so nothing is orphaned.
    private func deleteAudio(of meeting: Meeting) {
        guard let url = meeting.audioURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
            meeting.audioFileName = nil
        } catch {
            meeting.errorMessage = "오디오를 삭제하지 못했습니다: \(error.localizedDescription)"
        }
    }

    private func fetch(_ id: String) -> Meeting? {
        try? context.fetch(FetchDescriptor<Meeting>(predicate: #Predicate { $0.id == id })).first
    }

    /// "다시 처리" for a failed meeting whose audio is still on the device.
    func reprocess(meetingID: String) async {
        guard let meeting = fetch(meetingID), meeting.status == .failed, meeting.audioURL != nil else { return }
        meeting.errorMessage = nil
        meeting.status = .transcribing
        save()
        await withBackgroundTime("void.reprocess") {
            await process(meetingID: meetingID)
        }
    }

    private func save() {
        Persistence.save(context)
    }
}
