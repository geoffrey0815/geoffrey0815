import AppIntents
import SwiftData
import SwiftUI

@main
struct VoidApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(RecordingController.shared)
                .task { await ProcessingPipeline.shared.recoverInterruptedWork() }
        }
        .modelContainer(Persistence.container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await ProcessingPipeline.shared.retryDueDeliveries() }
            }
        }
        .backgroundTask(.appRefresh(WebhookDelivery.refreshTaskID)) {
            await ProcessingPipeline.shared.retryDueDeliveries()
        }
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
