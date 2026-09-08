import XCTest

/// Cooking a recipe (`UpdateInventoryAfterCookingUseCase`) and sending its missing
/// ingredients to the shopping list (`AddMissingIngredientsToShoppingListUseCase`).
final class CookingAndShoppingFlowUITests: FridgeFitUITestCase {
    @MainActor
    func testMarkingARecipeAsCookedDeductsFromThePantry() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["Add Ingredients"].waitForExistence(timeout: 10))
        app.buttons["Add Ingredients"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: 5))
        app.buttons["Add Ingredient"].firstMatch.tap()

        let nameField = app.textFields["Ingredient"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("chickpeas")
        let quantityField = app.textFields["Quantity"]
        quantityField.clearText()
        quantityField.typeText("1000")
        app.buttons["Save"].tap()

        app.tabBars.buttons["Decide"].tap()

        let curry = app.staticTexts["Chickpea and Spinach Curry"]
        XCTAssertTrue(curry.waitForExistence(timeout: 10))
        curry.tap()

        let cookButton = app.buttons["Mark as Cooked"]
        XCTAssertTrue(cookButton.waitForExistence(timeout: 5))
        cookButton.tap()

        let ok = app.buttons["OK"]
        XCTAssertTrue(ok.waitForExistence(timeout: 5))
        ok.tap()

        // Curry needs 400g chickpeas; 1000 - 400 = 600 should remain.
        app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "600")
            ).firstMatch.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testAddingARecipesMissingIngredientsToTheShoppingList() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas")
        app.tabBars.buttons["Decide"].tap()

        let curry = app.staticTexts["Chickpea and Spinach Curry"]
        XCTAssertTrue(curry.waitForExistence(timeout: 10))
        curry.tap()

        let addButton = app.buttons["Add missing to shopping list"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Added to your shopping list")
            ).firstMatch.waitForExistence(timeout: 5)
        )
        app.buttons["OK"].tap()
    }
}
