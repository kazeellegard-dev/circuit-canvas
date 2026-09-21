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
    func testWireToolConnectsTwoSymbolPins() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["配線"].tap()
        app.buttons["symbol-Temperature-pin-1"].tap()
        app.buttons["symbol-CAN-pin-0"].tap()
        app.buttons["確認"].tap()

        let wireCount = app.descendants(matching: .any).matching(identifier: "wire-count").firstMatch
        XCTAssertTrue(wireCount.waitForExistence(timeout: 2))
        XCTAssertEqual(wireCount.value as? String, "4")
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func connectTemperatureToCAN(_ app: XCUIApplication) {
        app.buttons["配線"].tap()
        app.buttons["symbol-Temperature-pin-1"].tap()
        app.buttons["symbol-CAN-pin-0"].tap()
        XCTAssertTrue(element(app, "wire-3").waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["終点のピンをタップ（直交で自動配線）"].exists)
    }

    @MainActor
    private func assertWireCount(_ app: XCUIApplication, _ count: String) {
        app.buttons["確認"].tap()
        let wireCount = element(app, "wire-count")
        XCTAssertTrue(wireCount.waitForExistence(timeout: 2))
        XCTAssertEqual(wireCount.value as? String, count)
    }

    @MainActor
    func testDuplicateWireIsRejectedInBothDirections() {
        // Relaunch per direction so each attempt is checked independently.
        for reversed in [false, true] {
            let app = XCUIApplication()
            app.launch()
            connectTemperatureToCAN(app)
            app.buttons["配線"].tap()
            let pins = ["symbol-Temperature-pin-1", "symbol-CAN-pin-0"]
            app.buttons[pins[reversed ? 1 : 0]].tap()
            app.buttons[pins[reversed ? 0 : 1]].tap()
            assertWireCount(app, "4")
            app.terminate()
        }
    }

    @MainActor
    func testPressingWireToolAgainClearsStartPin() {
        let app = XCUIApplication()
        app.launch()
        let oldStart = app.buttons["symbol-Temperature-pin-1"]
        let newStart = app.buttons["symbol-CAN-pin-1"]
        app.buttons["配線"].tap()
        oldStart.tap()
        XCTAssertTrue(oldStart.isSelected)
        XCTAssertTrue(app.staticTexts["終点のピンをタップ（直交で自動配線）"].exists)
        app.buttons["配線"].tap()
        XCTAssertFalse(oldStart.isSelected)
        XCTAssertTrue(app.staticTexts["始点のピンをタップ"].exists)
        newStart.tap()
        XCTAssertTrue(newStart.isSelected)
        XCTAssertFalse(element(app, "wire-3").exists)
        app.buttons["symbol-Temperature-pin-0"].tap()
        XCTAssertEqual(coordinates(element(app, "wire-3")), [695, 250, 45, 390])
        assertWireCount(app, "4")
    }

    @MainActor
    func testResetStartPinCanBeReusedAsEndWithMatchingWireCoordinates() {
        let app = XCUIApplication()
        app.launch()
        let oldStart = app.buttons["symbol-Temperature-pin-1"]
        let newStart = app.buttons["symbol-CAN-pin-1"]
        app.buttons["配線"].tap()
        oldStart.tap()
        app.buttons["配線"].tap()
        newStart.tap()
        XCTAssertTrue(newStart.isSelected)
        XCTAssertFalse(oldStart.isSelected)
        XCTAssertFalse(element(app, "wire-3").exists)
        oldStart.tap()

        let wire = element(app, "wire-3")
        XCTAssertTrue(wire.waitForExistence(timeout: 2))
        // Compare numeric coordinates: accessibility may include trailing zeros.
        XCTAssertEqual(coordinates(wire), [695, 250, 195, 390])
        XCTAssertEqual(coordinates(wire), coordinates(newStart) + coordinates(oldStart))
        assertWireCount(app, "4")
    }

    @MainActor
    private func coordinates(_ element: XCUIElement) -> [Double] {
        (element.value as? String ?? "").split(separator: ",").compactMap { Double($0) }
    }

    @MainActor
    func testVisiblePinCentersMatchWireEndpointOffsets() {
        let app = XCUIApplication()
        app.launch()
        connectTemperatureToCAN(app)
        for name in ["Temperature", "CAN"] {
            let symbol = element(app, "symbol-\(name)")
            let left = app.buttons["symbol-\(name)-pin-0"].frame
            let right = app.buttons["symbol-\(name)-pin-1"].frame
            // At the initial 100% viewport the model's ±75pt must match the UI.
            XCTAssertEqual(left.midX, symbol.frame.midX - 75, accuracy: 1)
            XCTAssertEqual(right.midX, symbol.frame.midX + 75, accuracy: 1)
            XCTAssertEqual(left.midY, right.midY, accuracy: 1)
        }
        XCTAssertEqual(coordinates(element(app, "wire-3")), [195, 390, 545, 250])
    }

    @MainActor
    func testAddedWireEndpointsFollowBothDraggedSymbols() {
        let app = XCUIApplication()
        app.launch()
        connectTemperatureToCAN(app)
        let wire = element(app, "wire-3")
        let startPin = app.buttons["symbol-Temperature-pin-1"]
        let endPin = app.buttons["symbol-CAN-pin-0"]
        XCTAssertEqual(coordinates(wire), coordinates(startPin) + coordinates(endPin))

        for name in ["Temperature", "CAN"] {
            let symbol = element(app, "symbol-\(name)")
            let before = coordinates(wire)
            let pin = name == "Temperature" ? startPin : endPin
            let oldFrame = pin.frame
            let source = symbol.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            source.press(forDuration: 0.2, thenDragTo: source.withOffset(CGVector(dx: 48, dy: 72)))
            let after = coordinates(wire)
            XCTAssertEqual(after.count, 4)
            XCTAssertEqual(after, coordinates(startPin) + coordinates(endPin))
            let offset = name == "Temperature" ? 0 : 2
            XCTAssertGreaterThan(after[offset + 1] - before[offset + 1], 30)
            // Verify the rendered pin moves by the endpoint delta at 100% zoom.
            XCTAssertEqual(Double(pin.frame.midX - oldFrame.midX), after[offset] - before[offset], accuracy: 2)
            XCTAssertEqual(Double(pin.frame.midY - oldFrame.midY), after[offset + 1] - before[offset + 1], accuracy: 2)
            let fixedOffset = offset == 0 ? 2 : 0
            XCTAssertEqual(after[fixedOffset], before[fixedOffset])
            XCTAssertEqual(after[fixedOffset + 1], before[fixedOffset + 1])
        }
    }

    @MainActor
    func testDeletingSymbolRemovesNewlyAddedWire() {
        let app = XCUIApplication()
        app.launch()
        connectTemperatureToCAN(app)
        let temperature = element(app, "symbol-Temperature")
        temperature.tap()
        app.buttons["確認"].tap()
        app.buttons["シンボルを削除"].tap()
        XCTAssertFalse(temperature.exists)
        XCTAssertFalse(element(app, "wire-3").exists)
        let count = element(app, "wire-count")
        XCTAssertTrue(count.waitForExistence(timeout: 2))
        // The initial Temperature→MCU wire and the added Temperature→CAN wire disappear.
        XCTAssertEqual(count.value as? String, "2")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
