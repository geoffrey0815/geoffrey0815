import AppIntents
#if !WIDGET_EXTENSION
import VoidCore
#endif

// These intents are compiled into both the app and the widget extension so widgets,
// Control Center and the Live Activity can reference them. The system performs
// AudioRecordingIntent and LiveActivityIntent in the app's process, so the real work
// only exists in the app build; the extension build compiles it out.

/// One tap from a widget, Control Center, the Action button or Siri: start, or stop if already recording.
struct ToggleRecordingIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "녹음 시작/정지"
    static let description = IntentDescription("void 녹음을 시작하거나 멈춥니다.")

    init() {}

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        try await RecordingController.shared.toggle()
        #endif
        return .result()
    }
}

/// Stop button on the Live Activity.
struct StopRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "녹음 정지"

    init() {}

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await RecordingController.shared.stop(reason: .manual)
        #endif
        return .result()
    }
}

/// "계속 녹음" on the silence warning.
struct KeepRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "계속 녹음"

    init() {}

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await RecordingController.shared.keepRecording()
        #endif
        return .result()
    }
}
