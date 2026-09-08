import XCTest

/// End-to-end check that the app is really talking to Spoonacular (real key in the app
/// bundle, no `-uiTesting`). Skipped unless `RUN_LIVE_API_TESTS=1`, so CI — which has no key
/// — doesn't fail on it.
final class LiveApiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLiveSpoonacularPipelineEndToEnd() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_LIVE_API_TESTS"] == "1",
            "live API test — set RUN_LIVE_API_TESTS=1 to run"
        )

        let app = XCUIApplication()
        app.launchArguments = ["-liveTest"] // real Spoonacular, scratch (empty) pantry
        app.launch()

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

        app.cells.firstMatch.staticTexts.firstMatch.tap()
        XCTAssertTrue(app.buttons["Mark as Cooked"].waitForExistence(timeout: 10))

        XCTAssertFalse(
            app.staticTexts["No instructions available for this recipe."].exists,
            "detail fell back to the no-instructions placeholder"
        )
        add(keptScreenshot(app))

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
}
