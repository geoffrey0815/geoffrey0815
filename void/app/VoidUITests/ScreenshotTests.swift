import XCTest

/// Walks every screen with seeded data in light and dark mode and keeps a screenshot of
/// each as a test attachment; CI exports them as the design evidence artifact.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testScreensLight() {
        walkScreens(dark: false)
    }

    func testScreensDark() {
        walkScreens(dark: true)
    }

    /// Without a usable microphone (CI simulator) the app must show an error, not crash.
    func testRecordButtonFailsGracefullyWithoutMicrophone() {
        let app = launch(dark: false)
        addUIInterruptionMonitor(withDescription: "Microphone permission") { alert in
            for label in ["Allow", "허용", "OK", "확인"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        app.buttons["녹음 시작"].tap()
        app.tap() // lets the interruption monitor handle the permission alert
        sleep(3)
        XCTAssertEqual(app.state, .runningForeground, "app must not crash when recording cannot start")
        snap("04-record-attempt")
    }

    func testDeleteFromContextMenu() {
        let app = launch(dark: false)
        let standup = app.descendants(matching: .any)["meeting-mtg_seed_standup"]
        XCTAssertTrue(standup.waitForExistence(timeout: 15))
        standup.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["삭제"].waitForExistence(timeout: 5))
        snap("07-context-menu")
        app.buttons["삭제"].tap()
        XCTAssertTrue(standup.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["meeting-mtg_seed_review"].exists)
    }

    func testEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSeed", "-uiTestEmpty"]
        app.launch()
        XCTAssertTrue(app.staticTexts["아직 회의가 없어요"].waitForExistence(timeout: 15))
        snap("08-empty")
    }

    private func walkScreens(dark: Bool) {
        let mode = dark ? "dark" : "light"
        let app = launch(dark: dark)

        let review = app.descendants(matching: .any)["meeting-mtg_seed_review"]
        XCTAssertTrue(review.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["녹음 시작"].exists)
        snap("01-home-\(mode)")

        review.tap()
        XCTAssertTrue(app.staticTexts["결정사항"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["할 일"].exists)
        snap("02-detail-\(mode)")

        app.navigationBars.buttons.firstMatch.tap()
        let failed = app.descendants(matching: .any)["meeting-mtg_seed_failed"]
        XCTAssertTrue(failed.waitForExistence(timeout: 5))
        failed.tap()
        XCTAssertTrue(app.buttons["다시 처리"].waitForExistence(timeout: 5))
        snap("03-failed-\(mode)")

        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["설정"].tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        snap("05-settings-\(mode)")
        app.swipeUp()
        snap("06-settings-bottom-\(mode)")
    }

    private func launch(dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSeed"] + (dark ? ["-uiTestDark"] : [])
        app.launch()
        return app
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
