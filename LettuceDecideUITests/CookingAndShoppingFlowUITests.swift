import XCTest

/// Cooking a recipe (`UpdateInventoryAfterCookingUseCase`) and sending its missing
/// ingredients to the shopping list (`AddMissingIngredientsToShoppingListUseCase`) — reached
/// through Calendar → Week Plan, now that Decide has been replaced by Home.
final class CookingAndShoppingFlowUITests: FridgeFitUITestCase {
    /// From the Calendar tab, generates a plan and waits for the result screen.
    @MainActor
    private func generatePlan(_ app: XCUIApplication) {
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Weekly Planner"].waitForExistence(timeout: 5))
        app.buttons["Generate This Week's Plan"].tap()
        XCTAssertTrue(app.navigationBars["This Week's Plan"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testMarkingAConfirmedMealAsCookedDeductsFromThePantry() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas", quantity: "1000")
        generatePlan(app)

        let curry = app.staticTexts["Chickpea and Spinach Curry"]
        XCTAssertTrue(curry.waitForExistence(timeout: 5))
        curry.tap()

        // Monday — the first day of the current week — has always already "arrived" by the
        // time this runs, so confirming it and marking it cooked is honestly available today.
        let planButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Plan This for")
        ).firstMatch
        XCTAssertTrue(planButton.waitForExistence(timeout: 5))
        planButton.tap()
        app.buttons["OK"].tap()

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(curry.waitForExistence(timeout: 5))
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
        generatePlan(app)

        let curry = app.staticTexts["Chickpea and Spinach Curry"]
        XCTAssertTrue(curry.waitForExistence(timeout: 5))
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
