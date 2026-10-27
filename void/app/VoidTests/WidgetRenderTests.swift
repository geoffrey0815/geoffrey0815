import SwiftUI
import XCTest

/// Renders the Home Screen widget and the Live Activity (lock screen banner, warning state)
/// in light and dark, and keeps the images as design evidence. These surfaces never appear
/// in UI tests, because the system draws them outside the app.
@MainActor
final class WidgetRenderTests: XCTestCase {
    private let startedAt = Date.now.addingTimeInterval(-(12 * 60 + 34))

    func testLiveActivityAndWidgetRender() throws {
        for scheme in [ColorScheme.light, .dark] {
            let mode = scheme == .dark ? "dark" : "light"

            let recording = LockScreenView(state: .init(startedAt: startedAt, autoStopAt: nil))
            try attach(recording.padding(16).frame(width: 360).background(Theme.surface), scheme: scheme, name: "10-live-activity-\(mode)")

            let warning = LockScreenView(state: .init(startedAt: startedAt, autoStopAt: .now.addingTimeInterval(25)))
            try attach(warning.padding(16).frame(width: 360).background(Theme.surface), scheme: scheme, name: "11-live-activity-warning-\(mode)")

            let widget = RecordWidgetView()
                .frame(width: 170, height: 170)
                .background(Theme.surface, in: .rect(cornerRadius: 22, style: .continuous))
                .padding(20)
                .background(Theme.canvas)
            try attach(widget, scheme: scheme, name: "12-widget-small-\(mode)")
        }
    }

    private func attach(_ view: some View, scheme: ColorScheme, name: String) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, scheme))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "\(name) did not render")
        XCTAssertGreaterThan(image.size.width, 100)
        XCTAssertGreaterThan(image.size.height, 60)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
