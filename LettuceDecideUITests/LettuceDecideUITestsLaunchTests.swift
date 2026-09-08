//
//  LettuceDecideUITestsLaunchTests.swift
//  LettuceDecideUITests
//
//  Created by Emily on 30/8/2026.
//

import XCTest

final class LettuceDecideUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Kept separate from the launch-screenshot test so it isn't multiplied by
/// `runsForEachTargetApplicationUIConfiguration`.
final class LaunchPerformanceUITests: XCTestCase {
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting"]
            app.launch()
        }
    }
}
