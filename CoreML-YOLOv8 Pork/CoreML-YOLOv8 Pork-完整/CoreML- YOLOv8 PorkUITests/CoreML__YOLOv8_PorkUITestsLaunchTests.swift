//
//  CoreML__YOLOv8_PorkUITestsLaunchTests.swift
//  CoreML- YOLOv8 PorkUITests
//
//  Created by 杨帆 on 2024/5/11.
//

import XCTest

final class CoreML__YOLOv8_PorkUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
