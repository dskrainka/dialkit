import XCTest

final class DialKitDemoUITests: XCTestCase {
    #if DEBUG
    func testTuneNativeCardWithRealSlider() {
        let app = XCUIApplication()
        app.launch()
        let toggle = app.buttons["dialkit.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        let radius = app.webViews.sliders["Radius"]
        XCTAssertTrue(radius.waitForExistence(timeout: 15))
        let before = radius.value as? String
        let start = radius.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
        let end = radius.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        let changed = NSPredicate(format: "value != %@", before ?? "")
        expectation(for: changed, evaluatedWith: radius)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.staticTexts["Radius 28 · Padding 24"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "SwiftUI card and live DialKit controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        toggle.tap()
        XCTAssertTrue(app.buttons["Try the spring"].exists)
    }
    #else
    func testReleaseUsesDefaultsWithoutEditor() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Radius 28 · Padding 24"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["dialkit.toggle"].exists)
        XCTAssertEqual(app.webViews.count, 0)
    }
    #endif
}
