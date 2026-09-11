import XCTest

/// Planning the week — `RecordBusynessUseCase`, `GenerateWeeklyMealPlanUseCase` /
/// `WeeklyPlanBuilder`, and adding the week's shortfall to the shopping list.
final class WeeklyPlanFlowUITests: FridgeFitUITestCase {
    /// From the Calendar tab, generates a plan and waits for the result screen.
    @MainActor
    private func generatePlan(_ app: XCUIApplication) {
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Weekly Planner"].waitForExistence(timeout: 5))
        app.buttons["Generate This Week's Plan"].tap()
        XCTAssertTrue(app.navigationBars["This Week's Plan"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testGeneratingAWeeklyPlanFromBusyness() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas")
        generatePlan(app)

        XCTAssertTrue(app.staticTexts["Chickpea and Spinach Curry"].waitForExistence(timeout: 5))

        // With only the three mock recipes, four of the seven days honestly have no match.
        let noMatch = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "No match this busy")
        ).firstMatch
        for _ in 0..<4 where !noMatch.exists {
            app.swipeUp()
        }
        XCTAssertTrue(noMatch.exists)
    }

    /// A day in the Week Plan is a preview, not something already cooked — tapping into it
    /// must offer a "plan this" confirmation, never the "Mark as Cooked" pantry deduction as
    /// its primary action, and confirming must not touch the pantry at all.
    @MainActor
    func testConfirmingAPlannedDayDoesNotDeductFromThePantry() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas", quantity: "1000")
        generatePlan(app)

        let curry = app.staticTexts["Chickpea and Spinach Curry"]
        XCTAssertTrue(curry.waitForExistence(timeout: 5))
        curry.tap()

        let planButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Plan This for")
        ).firstMatch
        XCTAssertTrue(planButton.waitForExistence(timeout: 5))
        planButton.tap()

        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Nothing has been taken from your pantry")
            ).firstMatch.waitForExistence(timeout: 5)
        )
        app.buttons["OK"].tap()

        // Confirming a plan is not cooking it — the pantry is untouched.
        app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1000")).firstMatch.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testAddingTheWeeksShortfallToTheShoppingList() throws {
        let app = launchApp()

        stockPantryFromEmptyState(app, name: "chickpeas")
        generatePlan(app)

        // The button lives below the seven day rows — scroll it into view.
        let addAll = app.buttons["Add all to my shopping list"]
        for _ in 0..<4 where !addAll.exists {
            app.swipeUp()
        }
        XCTAssertTrue(addAll.waitForExistence(timeout: 5))
        addAll.tap()

        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "shopping list now has")
            ).firstMatch.waitForExistence(timeout: 5)
        )
        app.buttons["OK"].tap()
    }
}
