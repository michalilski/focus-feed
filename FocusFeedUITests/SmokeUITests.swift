import XCTest

final class SmokeUITests: XCUITestCase {
    func testLaunchShowsPlatformPickerAndControls() {
        XCTAssertTrue(app.segmentedControls["platformPicker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["back"].exists)
        XCTAssertTrue(app.buttons["pageMenu"].exists)
    }

    func testSwitchingPlatformsKeepsControlsVisible() {
        let picker = app.segmentedControls["platformPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.buttons["X"].tap()
        XCTAssertTrue(picker.buttons["X"].isSelected)
        picker.buttons["Instagram"].tap()
        XCTAssertTrue(picker.buttons["Instagram"].isSelected)
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
