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

        // The list loads on appear; an empty pantry offers "Add Ingredients", not a
        // pointless retry.
        XCTAssertTrue(app.buttons["Add Ingredients"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Try Again"].exists)
    }

    @MainActor
    func testAddingAPantryIngredientProducesRecommendations() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["Add Ingredients"].waitForExistence(timeout: 10))
        app.buttons["Add Ingredients"].tap()

        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: 5))
        app.buttons["Add Ingredient"].firstMatch.tap()

        let nameField = app.textFields["Ingredient"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("chickpeas")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["chickpeas"].waitForExistence(timeout: 5))

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
    /// no refetch. `-uiTestNoRefetch` makes every fetch after the first fail, so if the
    /// curry card still climbs from 50% (chickpeas) to 67% (chickpeas + spinach), it was
    /// re-ranked locally rather than reloaded.
    @MainActor
    func testAddingPantryIngredientReRanksRecommendationsWithoutRefetching() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestNoRefetch"]
        app.launch()

        XCTAssertTrue(app.buttons["Add Ingredients"].waitForExistence(timeout: 10))
        app.buttons["Add Ingredients"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: 5))
        addIngredient(app, name: "chickpeas")
        app.tabBars.buttons["Decide"].tap()

        XCTAssertTrue(app.staticTexts["Chickpea and Spinach Curry"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["50% of ingredients in your pantry"].waitForExistence(timeout: 5))

        // Add another ingredient the curry uses.
        app.tabBars.buttons["Pantry"].tap()
        addIngredient(app, name: "spinach")
        app.tabBars.buttons["Decide"].tap()

        // The card climbed on its own — and a failed refetch would have shown an error, not this.
        XCTAssertTrue(app.staticTexts["67% of ingredients in your pantry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chickpea and Spinach Curry"].exists)
        XCTAssertFalse(app.buttons["Try Again"].exists)
    }

    @MainActor
    private func addIngredient(_ app: XCUIApplication, name: String) {
        app.buttons["Add Ingredient"].firstMatch.tap()
        let nameField = app.textFields["Ingredient"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

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
        app.tabBars.buttons["Decide"].tap()
        app.tabBars.buttons["Settings"].tap()

        let reopenedToggle = app.switches["Dairy"]
        XCTAssertTrue(reopenedToggle.waitForExistence(timeout: 5))
        XCTAssertNotEqual(reopenedToggle.value as? String, initialValue)
    }

    @MainActor
    func testWeeklyPlannerGeneratesAPlanFromBusyness() throws {
        let app = launchApp()

        // Stock the pantry so the planner has something to work with.
        XCTAssertTrue(app.buttons["Add Ingredients"].waitForExistence(timeout: 10))
        app.buttons["Add Ingredients"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: 5))
        app.buttons["Add Ingredient"].firstMatch.tap()
        let nameField = app.textFields["Ingredient"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("chickpeas")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["chickpeas"].waitForExistence(timeout: 5))

        // Open the Calendar tab, generate, land on the result screen.
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Weekly Planner"].waitForExistence(timeout: 5))

        app.buttons["Generate This Week's Plan"].tap()

        XCTAssertTrue(app.navigationBars["This Week's Plan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Chickpea and Spinach Curry"].waitForExistence(timeout: 5))
        // With only the three mock recipes, some days honestly have no match.
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "No match this busy")
            ).firstMatch.exists
        )
    }

    /// End-to-end check that the app is talking to the real Spoonacular API (real key in
    /// the app bundle, no -uiTesting flag). Skipped unless run with
    /// `TEST_RUNNER_RUN_LIVE_API_TESTS=1`, so CI (which has no key) doesn't fail on it.
    @MainActor
    func testLiveSpoonacularPipelineEndToEnd() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_LIVE_API_TESTS"] == "1",
            "live API test — set TEST_RUNNER_RUN_LIVE_API_TESTS=1 to run"
        )

        let app = XCUIApplication()
        app.launchArguments = ["-liveTest"] // real Spoonacular, scratch (empty) pantry
        app.launch()

        // Empty pantry on a clean launch.
        XCTAssertTrue(app.buttons["Add Ingredients"].waitForExistence(timeout: 20))
        add(keptScreenshot(app))
        app.buttons["Add Ingredients"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: 5))
        for ingredient in ["chicken breast", "rice", "broccoli"] {
            app.buttons["Add Ingredient"].firstMatch.tap()
            let nameField = app.textFields["Ingredient"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.tap()
            nameField.typeText(ingredient)
            app.buttons["Save"].tap()
            XCTAssertTrue(app.staticTexts[ingredient].waitForExistence(timeout: 5))
        }

        app.tabBars.buttons["Decide"].tap()

        // The list should load real recipes — never the three fixed mock titles.
        let mockTitles = ["Lemon Garlic Roasted Salmon", "Chickpea and Spinach Curry", "Classic Margherita Pizza"]
        let anyRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "of ingredients in your pantry")
        ).firstMatch
        XCTAssertTrue(anyRow.waitForExistence(timeout: 20), "recommendations list did not load")
        add(keptScreenshot(app))
        for title in mockTitles {
            XCTAssertFalse(app.staticTexts[title].exists, "still showing mock recipe: \(title)")
        }

        // Open the first recipe's detail.
        app.cells.firstMatch.staticTexts.firstMatch.tap()
        XCTAssertTrue(app.buttons["Mark as Cooked"].waitForExistence(timeout: 10))

        // Real method steps, not the fallback.
        XCTAssertFalse(
            app.staticTexts["No instructions available for this recipe."].exists,
            "detail fell back to the no-instructions placeholder"
        )
        // Every ingredient row carries a concrete amount + unit.
        add(keptScreenshot(app))

        // Scroll the method + attribution into view and capture it.
        app.swipeUp()
        app.swipeUp()
        add(keptScreenshot(app))

        let attribution = NSPredicate(format: "label BEGINSWITH %@", "Recipe from")
        XCTAssertTrue(
            app.buttons.matching(attribution).firstMatch.exists
            || app.links.matching(attribution).firstMatch.exists
            || app.staticTexts.matching(attribution).firstMatch.exists,
            "no source attribution on the detail screen"
        )
    }

    @MainActor
    private func keptScreenshot(_ app: XCUIApplication) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        return attachment
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
