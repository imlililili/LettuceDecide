import XCTest

/// Dietary settings — persisted through `UpdateUserPreferencesUseCase`.
final class SettingsFlowUITests: FridgeFitUITestCase {
    @MainActor
    func testSettingsTabShowsDietaryPreferences() throws {
        let app = launchApp()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Dairy"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTogglingAnAllergenPersistsAcrossTabSwitches() throws {
        let app = launchApp()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let dairyToggle = app.switches["Dairy"]
        XCTAssertTrue(dairyToggle.waitForExistence(timeout: 5))
        let initialValue = dairyToggle.value as? String
        dairyToggle.flipSwitch()

        // Leave and come back to the Settings tab.
        app.tabBars.buttons["Home"].tap()
        app.tabBars.buttons["Settings"].tap()

        let reopenedToggle = app.switches["Dairy"]
        XCTAssertTrue(reopenedToggle.waitForExistence(timeout: 5))
        XCTAssertNotEqual(reopenedToggle.value as? String, initialValue)
    }
}
