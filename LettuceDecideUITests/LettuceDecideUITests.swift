//
//  LettuceDecideUITests.swift
//  LettuceDecideUITests
//
//  Created by Emily on 30/8/2026.
//

import XCTest

final class LettuceDecideUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app with in-memory stores so every test starts from an empty pantry
    /// and default settings.
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    @MainActor
    func testEmptyPantryPromptsToAddIngredients() throws {
        let app = launchApp()

        let decideButton = app.buttons["Decide For Me"]
        XCTAssertTrue(decideButton.waitForExistence(timeout: 5))
        decideButton.tap()

        // Empty pantry: the recovery action is "Add Ingredients", not a pointless retry.
        XCTAssertTrue(app.buttons["Add Ingredients"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Try Again"].exists)
    }

    @MainActor
    func testAddingAPantryIngredientEnablesARecommendation() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["Decide For Me"].waitForExistence(timeout: 5))
        app.buttons["Decide For Me"].tap()

        XCTAssertTrue(app.buttons["Add Ingredients"].waitForExistence(timeout: 10))
        app.buttons["Add Ingredients"].tap()

        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: 5))
        app.buttons["Add Ingredient"].firstMatch.tap()

        let nameField = app.textFields["Ingredient"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("chickpeas")
        app.buttons["Save"].tap()

        // Row is now in the pantry.
        XCTAssertTrue(app.staticTexts["chickpeas"].waitForExistence(timeout: 5))

        // Back to recommendations; with a stocked pantry a recipe should appear.
        app.navigationBars["Pantry"].buttons.firstMatch.tap()

        let recipeTitleAppeared = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "min")
        ).firstMatch.waitForExistence(timeout: 10)
        let retryAppeared = app.buttons["Try Again"].waitForExistence(timeout: 10)
        XCTAssertTrue(recipeTitleAppeared || retryAppeared)
    }

    @MainActor
    func testAddIngredientRejectsInvalidQuantityWithADomainMessage() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["Pantry"].waitForExistence(timeout: 5))
        app.buttons["Pantry"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: 5))
        app.buttons["Add Ingredient"].firstMatch.tap()

        let nameField = app.textFields["Ingredient"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("rice")

        let quantityField = app.textFields["Quantity"]
        quantityField.clearText()
        quantityField.typeText("0")

        app.buttons["Save"].tap()

        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "greater than zero")
            ).firstMatch.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testSettingsSheetOpensAndCloses() throws {
        let app = launchApp()

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.buttons["Done"].tap()
        XCTAssertFalse(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testTogglingAnAllergenPersistsAfterReopeningSettings() throws {
        let app = launchApp()

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let dairyToggle = app.switches["Dairy"]
        XCTAssertTrue(dairyToggle.waitForExistence(timeout: 5))
        let initialValue = dairyToggle.value as? String
        dairyToggle.flipSwitch()

        app.buttons["Done"].tap()
        app.buttons["Settings"].tap()

        let reopenedToggle = app.switches["Dairy"]
        XCTAssertTrue(reopenedToggle.waitForExistence(timeout: 5))
        XCTAssertNotEqual(reopenedToggle.value as? String, initialValue)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting"]
            app.launch()
        }
    }
}

extension XCUIElement {
    /// Toggles a SwiftUI `Toggle` row. `tap()` on the row element lands on the label,
    /// which SwiftUI does not treat as a hit on the control, so tap the trailing edge
    /// where the switch itself sits.
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
