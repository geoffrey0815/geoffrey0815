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
                // App-wide accent: toggles, dialogs and controls stay grayscale instead of blue/green.
                .tint(Theme.ink)
                .task {
                    #if DEBUG
                    // Seeded UI-test data is static; recovery would try to reprocess it.
                    if UITestSupport.isActive { return }
                    #endif
                    await ProcessingPipeline.shared.recoverInterruptedWork()
                }
                #if DEBUG
                .preferredColorScheme(UITestSupport.colorScheme)
                #endif
        }
        .modelContainer(Persistence.container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    ProcessingPipeline.shared.purgeExpiredAudio()
                    await ProcessingPipeline.shared.retryDueDeliveries()
                }
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
