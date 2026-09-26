import XCTest

/// Launch smoke tests: catch crashes and broken wiring before a sideload round-trip.
final class RecallUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    @MainActor
    func testLaunchShowsTodayAndTabs() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["tab.archive"].exists)
        app.buttons["tab.archive"].tap()
        XCTAssertTrue(app.staticTexts["Archive"].waitForExistence(timeout: 5))
        app.buttons["tab.insights"].tap()
        XCTAssertTrue(app.staticTexts["The week, briefly"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTapCaptureThenStartAFrequent() {
        let app = launch()
        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 15))
        capture.tap()
        let coffee = app.buttons["freq.Coffee"]
        XCTAssertTrue(coffee.waitForExistence(timeout: 5))
        coffee.tap()
        let bar = app.descendants(matching: .any)["livebar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        XCTAssertTrue(bar.label.contains("Coffee"), "live bar says: \(bar.label)")
    }

    @MainActor
    func testHoldCaptureAndSlideStartsAFrequent() {
        let app = launch()
        let capture = app.descendants(matching: .any)["capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 15))
        let center = capture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // the first arc item sits at 152° on a 100 pt radius
        let first = center.withOffset(CGVector(dx: -88, dy: -47))
        center.press(forDuration: 0.6, thenDragTo: first)
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(toast.label.hasPrefix("Started"), "toast says: \(toast.label)")
    }

    @MainActor
    func testSwipeLeftRevealsRowActions() {
        let app = launch()
        let row = app.descendants(matching: .any)["entry.Deep work — Design"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.swipeLeft()
        XCTAssertTrue(app.buttons["EDIT"].waitForExistence(timeout: 5))
    }
}
