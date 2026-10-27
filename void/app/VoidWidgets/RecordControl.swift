import AppIntents
import SwiftUI
import WidgetKit

/// Control Center / Lock Screen control / Action button: one tap to start or stop.
struct RecordControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "void.record") {
            ControlWidgetButton(action: ToggleRecordingIntent()) {
                Label("void 녹음", systemImage: "waveform")
            }
        }
        .displayName("void 녹음")
        .description("한 번 눌러 녹음을 시작하거나 멈춥니다.")
    }
}
