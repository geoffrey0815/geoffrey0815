import ActivityKit
import AVFoundation
import Foundation
import Observation
import SwiftData
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
    var lastError: String?

    private let capture = AudioCapture()
    private var monitor = SilenceMonitor()
    private var meeting: Meeting?
    private var activity: Activity<RecordingAttributes>?
    private var framesTask: Task<Void, Never>?
    private var lastFrameTime: TimeInterval = 0

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
        guard !isRecording else { return }
        lastError = nil

        guard await AVAudioApplication.requestRecordPermission() else {
            lastError = "설정에서 마이크 접근을 허용해 주세요."
            throw RecordingError.microphoneDenied
        }

        let meeting = Meeting(language: AppSettings.recognitionLocale.identifier)
        guard let url = meeting.audioURL else { return }
        let frames: AsyncStream<AudioCapture.Frame>
        do {
            frames = try capture.start(writingTo: url)
        } catch {
            lastError = "녹음을 시작하지 못했습니다: \(error.localizedDescription)"
            throw error
        }

        let context = Persistence.container.mainContext
        context.insert(meeting)
        try? context.save()
        self.meeting = meeting

        let startedAt = meeting.startedAt
        phase = .recording(startedAt: startedAt)
        autoStopAt = nil
        lastFrameTime = 0
        monitor = SilenceMonitor(configuration: .init(timeout: TimeInterval(AppSettings.silenceMinutes * 60)))
        startLiveActivity(startedAt: startedAt)

        framesTask = Task { [weak self] in
            for await frame in frames {
                guard let self else { return }
                await self.handle(frame)
            }
        }
    }

    func stop(reason: MeetingResult.EndReason) async {
        guard isRecording, let meeting else { return }
        capture.stop()
        framesTask?.cancel()
        framesTask = nil
        phase = .idle
        autoStopAt = nil
        level = 0
        self.meeting = nil
        await endLiveActivity()

        meeting.endedAt = .now
        meeting.endReason = reason
        meeting.status = .transcribing
        try? Persistence.container.mainContext.save()

        let id = meeting.id
        Task { await ProcessingPipeline.shared.process(meetingID: id) }
    }

    func keepRecording() async {
        guard isRecording else { return }
        if monitor.extend(at: lastFrameTime) != nil {
            autoStopAt = nil
            await updateLiveActivity()
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

    private func startLiveActivity(startedAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RecordingAttributes.ContentState(startedAt: startedAt, autoStopAt: nil)
        activity = try? Activity.request(
            attributes: RecordingAttributes(),
            content: .init(state: state, staleDate: nil)
        )
    }

    private func updateLiveActivity() async {
        guard let activity, case .recording(let startedAt) = phase else { return }
        let state = RecordingAttributes.ContentState(startedAt: startedAt, autoStopAt: autoStopAt)
        await activity.update(.init(state: state, staleDate: nil))
    }

    private func endLiveActivity() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }
}

enum RecordingError: LocalizedError {
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "마이크 권한이 없습니다."
        }
    }
}
