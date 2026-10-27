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

    func process(meetingID: String) async {
        guard let meeting = fetch(meetingID), let audioURL = meeting.audioURL else { return }
        do {
            meeting.status = .transcribing
            save()
            let locale = Locale(identifier: meeting.language)
            meeting.transcript = try await transcriber.transcribe(fileAt: audioURL, locale: locale)

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

            if AppSettings.deleteAudioAfterProcessing {
                try? FileManager.default.removeItem(at: audioURL)
                meeting.audioFileName = nil
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

    /// Also used by the "다시 보내기" button.
    func deliver(meetingID: String) async {
        guard let meeting = fetch(meetingID), meeting.status == .ready else { return }
        guard let url = AppSettings.webhookURL else {
            meeting.delivery = .notConfigured
            save()
            return
        }
        meeting.delivery = .pending
        save()
        let outcome = await delivery.deliver(
            meeting.result(includeTranscript: AppSettings.includeTranscript),
            to: url,
            secret: Keychain.string(for: Keychain.webhookSecret),
            authorization: Keychain.string(for: Keychain.webhookAuthorization)
        )
        switch outcome {
        case .delivered:
            meeting.delivery = .delivered
        case .failed(let reason):
            meeting.delivery = .failed
            meeting.errorMessage = "Webhook 전송 실패: \(reason)"
        }
        save()
    }

    private func fetch(_ id: String) -> Meeting? {
        try? context.fetch(FetchDescriptor<Meeting>(predicate: #Predicate { $0.id == id })).first
    }

    private func save() {
        try? context.save()
    }
}
