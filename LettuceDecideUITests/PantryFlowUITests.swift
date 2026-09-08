import XCTest

/// Managing the pantry inventory — backed by `ManagePantryIngredientUseCase`.
final class PantryFlowUITests: FridgeFitUITestCase {
    @MainActor
    func testEmptyPantryPromptsToAddIngredients() throws {
        let app = launchApp()

        // The Decide list loads on appear; an empty pantry offers "Add Ingredients", not a
        // pointless retry.
        XCTAssertTrue(app.buttons["Add Ingredients"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Try Again"].exists)
    }

    @MainActor
    func testAddIngredientRejectsInvalidQuantityWithADomainMessage() throws {
        let app = launchApp()

        XCTAssertTrue(app.tabBars.buttons["Pantry"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Pantry"].tap()
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
}
