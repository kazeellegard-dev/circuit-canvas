//
//  CircuitCanvasUITests.swift
//  CircuitCanvasUITests
//
//  Created by Toru Yamaguchi on 2026/09/20.
//

import XCTest

final class CircuitCanvasUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExperimentNoteCanBeDragged() throws {
        let app = XCUIApplication()
        app.launch()

        let note = app.descendants(matching: .any).matching(identifier: "experiment-note-R12を変更").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        let before = note.value as? String
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.68))
        note.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.2, thenDragTo: destination)
        XCTAssertNotEqual(note.value as? String, before)
    }

    @MainActor
    func testDeletingNoteDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launch()

        let note = app.descendants(matching: .any).matching(identifier: "experiment-note-R12を変更").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        note.tap()
        app.buttons["確認"].tap()
        app.buttons["メモを削除"].tap()

        XCTAssertFalse(note.waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["図面"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDeletingSymbolRemovesAttachedWires() throws {
        let app = XCUIApplication()
        app.launch()

        let temperature = app.descendants(matching: .any).matching(identifier: "symbol-Temperature").firstMatch
        XCTAssertTrue(temperature.waitForExistence(timeout: 3))
        temperature.tap()
        app.buttons["確認"].tap()
        app.buttons["シンボルを削除"].tap()

        XCTAssertFalse(temperature.waitForExistence(timeout: 1))
        let wireCount = app.descendants(matching: .any).matching(identifier: "wire-count").firstMatch
        XCTAssertTrue(wireCount.waitForExistence(timeout: 2))
        XCTAssertEqual(wireCount.value as? String, "2")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
