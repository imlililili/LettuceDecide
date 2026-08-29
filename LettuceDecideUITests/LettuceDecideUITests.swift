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

    @MainActor
    func testDecideButtonShowsARecommendation() throws {
        let app = XCUIApplication()
        app.launch()

        let decideButton = app.buttons["Decide For Me"]
        XCTAssertTrue(decideButton.waitForExistence(timeout: 5))
        decideButton.tap()

        // Either a recipe title or an error/retry state should appear — never an indefinite spinner.
        let recipeTitleAppeared = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "min")
        ).firstMatch.waitForExistence(timeout: 10)
        let retryAppeared = app.buttons["Try Again"].waitForExistence(timeout: 10)
        XCTAssertTrue(recipeTitleAppeared || retryAppeared)
    }

    @MainActor
    func testSettingsSheetOpensAndCloses() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.buttons["Done"].tap()
        XCTAssertFalse(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testTogglingAnAllergenPersistsAfterReopeningSettings() throws {
        let app = XCUIApplication()
        app.launch()

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
            XCUIApplication().launch()
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
}
