import XCTest

final class SmokeUITests: XCUITestCase {
    func testLaunchShowsPlatformSwitcherAndControls() {
        XCTAssertTrue(app.buttons["platform-youtube"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["back"].exists)
        XCTAssertTrue(app.buttons["pageMenu"].exists)
    }

    func testSwitchingPlatformsKeepsControlsVisible() {
        let x = app.buttons["platform-x"]
        let instagram = app.buttons["platform-instagram"]
        XCTAssertTrue(x.waitForExistence(timeout: 10))
        x.tap()
        XCTAssertTrue(x.isSelected)
        instagram.tap()
        XCTAssertTrue(instagram.isSelected)
        XCTAssertFalse(x.isSelected)
        XCTAssertTrue(app.buttons["pageMenu"].exists)
    }

    func testControlsSitAtTheBottom() {
        let menu = app.buttons["pageMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(menu.frame.midY, app.windows.firstMatch.frame.height * 0.8)
    }

    func testTodayLabelSitsAtTheTop() {
        let label = app.staticTexts["todayLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        XCTAssertTrue(label.label.hasPrefix("Today"))
        XCTAssertLessThan(label.frame.midY, app.windows.firstMatch.frame.height * 0.15)
    }

    func testBarCanBeHiddenAndShownAgain() {
        let menu = app.buttons["pageMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        app.buttons["hideBar"].tap()
        let handle = app.buttons["showBar"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertFalse(menu.exists)
        handle.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
    }
}

class XCUITestCase: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
    }
}
