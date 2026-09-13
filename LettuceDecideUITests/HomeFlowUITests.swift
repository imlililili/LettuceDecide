import XCTest

/// The Home dashboard: confirmed Week Plan meals and the persisted shopping list built from
/// confirming them — backed by `ConfirmedMealStoring` and `ConfirmPlannedMealUseCase`.
final class HomeFlowUITests: FridgeFitUITestCase {
    @MainActor
    func testHomeShowsAnEmptyStateUntilADayIsConfirmed() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas")
        app.tabBars.buttons["Home"].tap()

        XCTAssertTrue(app.staticTexts["No confirmed meals yet"].waitForExistence(timeout: 5))

        app.buttons["Plan My Week"].tap()
        XCTAssertTrue(app.navigationBars["Weekly Planner"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testConfirmingADayShowsItOnHomeWithItsNettedShortfallOnTheShoppingList() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas", quantity: "1000")

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Weekly Planner"].waitForExistence(timeout: 5))
        app.buttons["Generate This Week's Plan"].tap()
        XCTAssertTrue(app.navigationBars["This Week's Plan"].waitForExistence(timeout: 20))

        let curry = app.staticTexts["Chickpea and Spinach Curry"]
        XCTAssertTrue(curry.waitForExistence(timeout: 5))
        curry.tap()

        let planButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Plan This for")
        ).firstMatch
        XCTAssertTrue(planButton.waitForExistence(timeout: 5))
        planButton.tap()
        app.buttons["OK"].tap()

        app.tabBars.buttons["Home"].tap()

        XCTAssertTrue(curry.waitForExistence(timeout: 5))
        // Curry needs curry powder, which the pantry never had — it belongs on the shopping
        // list. Chickpeas (1000g on hand, 400g needed) must NOT show up as a shortfall.
        XCTAssertTrue(app.staticTexts["curry powder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["chickpeas"].exists)
    }

    /// Marking a shopping-list line as bought must remove it from the list and add it to the
    /// Pantry tab, backed by `PurchaseShoppingListItemUseCase`.
    @MainActor
    func testMarkingAShoppingListItemAsBoughtMovesItToThePantry() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas", quantity: "1000")

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Weekly Planner"].waitForExistence(timeout: 5))
        app.buttons["Generate This Week's Plan"].tap()
        XCTAssertTrue(app.navigationBars["This Week's Plan"].waitForExistence(timeout: 20))

        let curry = app.staticTexts["Chickpea and Spinach Curry"]
        XCTAssertTrue(curry.waitForExistence(timeout: 5))
        curry.tap()
        let planButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Plan This for")
        ).firstMatch
        XCTAssertTrue(planButton.waitForExistence(timeout: 5))
        planButton.tap()
        app.buttons["OK"].tap()

        app.tabBars.buttons["Home"].tap()
        let curryPowderRow = app.staticTexts["curry powder"]
        XCTAssertTrue(curryPowderRow.waitForExistence(timeout: 5))

        curryPowderRow.swipeRight()
        let boughtButton = app.buttons["Bought"]
        XCTAssertTrue(boughtButton.waitForExistence(timeout: 5))
        boughtButton.tap()

        XCTAssertFalse(app.staticTexts["curry powder"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(app.staticTexts["curry powder"].waitForExistence(timeout: 5))
    }

    /// Marking a confirmed meal as cooked must remove its card from Home — otherwise a meal
    /// the cook already ate keeps sitting in "this week's meals" forever.
    @MainActor
    func testMarkingAConfirmedMealAsCookedRemovesItsCardFromHome() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas", quantity: "1000")

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Weekly Planner"].waitForExistence(timeout: 5))
        app.buttons["Generate This Week's Plan"].tap()
        XCTAssertTrue(app.navigationBars["This Week's Plan"].waitForExistence(timeout: 20))

        let curry = app.staticTexts["Chickpea and Spinach Curry"]
        XCTAssertTrue(curry.waitForExistence(timeout: 5))
        curry.tap()
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

        // "Mark as Cooked" on a success notice pops back to Home automatically.
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertFalse(curry.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No confirmed meals yet"].waitForExistence(timeout: 5))
    }
}
