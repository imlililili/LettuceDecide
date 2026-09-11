import XCTest

/// Base class for the flow-oriented UI tests. Each subclass covers one cook-facing journey.
class FridgeFitUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches with in-memory stores so every test starts from an empty pantry and default
    /// settings. `extraArguments` adds test hooks (e.g. `-uiTestNoRefetch`).
    @MainActor
    func launchApp(_ extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extraArguments
        app.launch()
        return app
    }

    /// From the Pantry tab (or its empty state), opens the Add Ingredient sheet, fills the
    /// name (and optionally a quantity), saves, and waits for the row to appear.
    @MainActor
    func addIngredient(_ app: XCUIApplication, name: String, quantity: String? = nil) {
        app.buttons["Add Ingredient"].firstMatch.tap()
        let nameField = app.textFields["Ingredient"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        if let quantity {
            let quantityField = app.textFields["Quantity"]
            quantityField.clearText()
            quantityField.typeText(quantity)
        }
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    /// Stocks the pantry with `name` (and optionally a quantity) starting from the Pantry
    /// tab's own empty-pantry prompt.
    @MainActor
    func stockPantryFromEmptyState(_ app: XCUIApplication, name: String, quantity: String? = nil) {
        app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Ingredient"].waitForExistence(timeout: 10))
        addIngredient(app, name: name, quantity: quantity)
    }
}

extension XCUIElement {
    /// Toggles a SwiftUI `Toggle` row. `tap()` on the row lands on the label, which SwiftUI
    /// does not treat as a hit on the control, so tap the trailing edge where the switch sits.
    func flipSwitch() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    /// Focuses the field and deletes whatever it currently contains.
    func clearText() {
        tap()
        let current = (value as? String) ?? ""
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
    }
}
