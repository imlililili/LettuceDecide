import XCTest

/// Getting and updating "what can I cook now" — backed by `RecommendMealsFromPantryUseCase`
/// and `PantryMatcher`.
final class RecommendationFlowUITests: FridgeFitUITestCase {
    @MainActor
    func testStockingThePantryProducesRecommendations() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas")

        // Back to the Decide tab; a previously failed load retries now the pantry is stocked.
        app.tabBars.buttons["Decide"].tap()

        XCTAssertTrue(app.staticTexts["Chickpea and Spinach Curry"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "of ingredients in your pantry")
            ).firstMatch.exists
        )
    }

    /// A pantry edit re-ranks the *existing* recommendations against the new inventory with
    /// no refetch. `-uiTestNoRefetch` makes every fetch after the first fail, so if the curry
    /// card still climbs from 50% (chickpeas) to 67% (chickpeas + spinach), it was re-ranked
    /// locally rather than reloaded.
    @MainActor
    func testAddingAnIngredientReRanksRecommendationsWithoutRefetching() throws {
        let app = launchApp(["-uiTestNoRefetch"])

        stockPantryFromEmptyState(app, name: "chickpeas")
        app.tabBars.buttons["Decide"].tap()

        XCTAssertTrue(app.staticTexts["Chickpea and Spinach Curry"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["50% of ingredients in your pantry"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Pantry"].tap()
        addIngredient(app, name: "spinach")
        app.tabBars.buttons["Decide"].tap()

        // The card climbed on its own — a failed refetch would have shown an error, not this.
        XCTAssertTrue(app.staticTexts["67% of ingredients in your pantry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chickpea and Spinach Curry"].exists)
        XCTAssertFalse(app.buttons["Try Again"].exists)
    }
}
