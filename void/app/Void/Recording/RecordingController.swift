import ActivityKit
import AVFoundation
import Foundation
import Observation
import SwiftData
import UIKit
import VoidCore

/// Single source of truth for "are we recording". Driven by the UI and by App Intents
/// (widget, Control Center, Action button, Live Activity buttons).
@MainActor
@Observable
final class RecordingController {
    static let shared = RecordingController()

    enum Phase: Equatable {
        case idle
        case recording(startedAt: Date)
    }

    private(set) var phase: Phase = .idle
    /// Non-nil while the silence warning is up.
    private(set) var autoStopAt: Date?
    private(set) var level: Float = 0
    /// True while a call or another app holds the microphone.
    private(set) var isInterrupted = false
    var lastError: String?

    private let capture = AudioCapture()
    private var monitor = SilenceMonitor()
    private var meeting: Meeting?
    private var activity: Activity<RecordingAttributes>?
    private var framesTask: Task<Void, Never>?
    private var interruptionTimeout: Task<Void, Never>?
    private var liveTranscriber: LiveTranscriber?
    private var lastFrameTime: TimeInterval = 0
    /// Set while `start` is suspended (permission prompt), so a second tap cannot start twice.
    private var isStarting = false

    var currentMeetingID: String? { meeting?.id }

    var isRecording: Bool {
        if case .recording = phase { true } else { false }
    }

    func toggle() async throws {
        if isRecording {
            await stop(reason: .manual)
        } else {
            try await start()
        }
    }

    func start() async throws {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        lastError = nil

        guard await AVAudioApplication.requestRecordPermission() else {
            lastError = "설정에서 마이크 접근을 허용해 주세요."
            throw RecordingError.microphoneDenied
        }

        let meeting = Meeting(language: AppSettings.recognitionLocale.identifier)
        guard let url = meeting.audioURL else { return }
        let live = LiveTranscriber(locale: AppSettings.recognitionLocale)
        capture.onBuffer = { live.append($0) }
        let events: AsyncStream<AudioCapture.Event>
        do {
            events = try capture.start(writingTo: url)
        } catch {
            live.cancel()
            capture.onBuffer = nil
            lastError = "녹음을 시작하지 못했습니다: \(error.localizedDescription)"
            throw error
        }

        // AudioRecordingIntent requires a Live Activity for the whole recording; without
        // one iOS stops background audio. Inside the app the recording can go on without it.
        let startedAt = meeting.startedAt
        let activityStarted = startLiveActivity(startedAt: startedAt)
        if !activityStarted, UIApplication.shared.applicationState != .active {
            capture.stop()
            capture.onBuffer = nil
            live.cancel()
            try? FileManager.default.removeItem(at: url)
            lastError = RecordingError.liveActivityUnavailable.errorDescription
            throw RecordingError.liveActivityUnavailable
        }

        let context = Persistence.container.mainContext
        context.insert(meeting)
        if !Persistence.save(context) {
            lastError = "회의를 저장하지 못했습니다. 저장 공간을 확인해 주세요."
        }
        self.meeting = meeting
        liveTranscriber = live

        phase = .recording(startedAt: startedAt)
        autoStopAt = nil
        lastFrameTime = 0
        monitor = SilenceMonitor(configuration: .init(timeout: TimeInterval(AppSettings.silenceMinutes * 60)))

        framesTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }

    func stop(reason: MeetingResult.EndReason) async {
        guard isRecording, let meeting else { return }
        capture.stop()
        capture.onBuffer = nil
        let live = liveTranscriber
        liveTranscriber = nil
        framesTask?.cancel()
        framesTask = nil
        interruptionTimeout?.cancel()
        interruptionTimeout = nil
        isInterrupted = false
        phase = .idle
        autoStopAt = nil
        level = 0
        self.meeting = nil

        meeting.endedAt = .now
        meeting.endReason = reason
        meeting.status = .transcribing
        Persistence.save(Persistence.container.mainContext)

        let id = meeting.id
        Task {
            // Recording may have been stopped from the Lock Screen; ask for time to finish.
            await withBackgroundTime("void.process") {
                // Usually only the last few seconds are left to transcribe.
                let transcript = try? await live?.finish()
                await ProcessingPipeline.shared.process(meetingID: id, liveTranscript: transcript)
            }
        }
        await endLiveActivity()
    }

    func keepRecording() async {
        guard isRecording else { return }
        if monitor.extend(at: lastFrameTime) != nil {
            autoStopAt = nil
            await updateLiveActivity()
        }
    }

    private func handle(_ event: AudioCapture.Event) async {
        switch event {
        case .frame(let frame):
            await handle(frame)
        case .interrupted:
            isInterrupted = true
            // Frames stop during an interruption, so the silence monitor is frozen.
            // If the microphone never comes back, end the meeting after the same timeout.
            let timeout = monitor.configuration.timeout
            interruptionTimeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                guard !Task.isCancelled, let self, self.isInterrupted else { return }
                await self.stop(reason: .silenceTimeout)
            }
        case .resumed:
            isInterrupted = false
            interruptionTimeout?.cancel()
            interruptionTimeout = nil
        case .failed(let message):
            lastError = message
            await stop(reason: .manual)
        }
    }

    private func handle(_ frame: AudioCapture.Frame) async {
        lastFrameTime = frame.time
        level = frame.level
        switch monitor.process(isSpeech: frame.isSpeech, at: frame.time) {
        case .warning(let remaining):
            autoStopAt = .now.addingTimeInterval(remaining)
            await updateLiveActivity()
        case .warningCancelled:
            autoStopAt = nil
            await updateLiveActivity()
        case .timeout:
            await stop(reason: .silenceTimeout)
        case nil:
            break
        }
    }

    // MARK: Live Activity

    private func startLiveActivity(startedAt: Date) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let state = RecordingAttributes.ContentState(startedAt: startedAt, autoStopAt: nil)
        activity = try? Activity.request(
            attributes: RecordingAttributes(),
            content: .init(state: state, staleDate: nil)
        )
        return activity != nil
    }

    private func updateLiveActivity() async {
        guard let activity, case .recording(let startedAt) = phase else { return }
        let state = RecordingAttributes.ContentState(startedAt: startedAt, autoStopAt: autoStopAt)
        await activity.update(.init(state: state, staleDate: nil))
    }

    private func endLiveActivity() async {
        // Detach first: a recording started while this awaits must keep its own activity.
        let ending = activity
        activity = nil
        await ending?.end(nil, dismissalPolicy: .immediate)
    }
}

/// Runs `body` with a UIKit background-task assertion so work started from the Lock Screen
/// or a widget is not suspended immediately. Launch-time recovery covers the rest.
@MainActor
func withBackgroundTime(_ name: String, _ body: () async -> Void) async {
    // The expiration handler is @Sendable, so the identifier lives in a main-actor box
    // rather than a captured var.
    @MainActor final class Assertion {
        var id = UIBackgroundTaskIdentifier.invalid
        func end() {
            guard id != .invalid else { return }
            UIApplication.shared.endBackgroundTask(id)
            id = .invalid
        }
    }
    let assertion = Assertion()
    assertion.id = UIApplication.shared.beginBackgroundTask(withName: name) {
        MainActor.assumeIsolated { assertion.end() }
    }
    await body()
    assertion.end()
}

enum RecordingError: LocalizedError {
    case microphoneDenied
    case liveActivityUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "마이크 권한이 없습니다."
        case .liveActivityUnavailable: "앱 밖에서 녹음하려면 설정 > void에서 실시간 현황(Live Activity)을 켜 주세요."
        }
    }
}
