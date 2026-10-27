import AppIntents
import SwiftData
import SwiftUI

@main
struct VoidApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(RecordingController.shared)
        }
        .modelContainer(Persistence.container)
    }
}

/// Exposes the toggle to Siri, Spotlight, Shortcuts and the Action button.
struct VoidShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleRecordingIntent(),
            phrases: [
                "\(.applicationName) 녹음",
                "Record with \(.applicationName)",
            ],
            shortTitle: "녹음",
            systemImageName: "waveform"
        )
    }
}
