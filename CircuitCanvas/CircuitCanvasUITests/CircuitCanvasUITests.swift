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
    func testSameSymbolOppositePinKeepsStartAndCount() {
        let app = XCUIApplication(); app.launch()
        app.buttons["配線"].tap()
        let start = app.buttons["symbol-Temperature-pin-1"]
        start.tap(); app.buttons["symbol-Temperature-pin-0"].tap()
        XCTAssertTrue(start.isSelected)
        XCTAssertFalse(element(app, "wire-3").exists)
        XCTAssertTrue(app.staticTexts["終点のピンをタップ（直交で自動配線）"].exists)
        assertWireCount(app, "3")
    }

    @MainActor
    func testOperationHintStaysFixedDuringZoomAndPan() {
        let app = XCUIApplication(); app.launch()
        for button in ["配線", "＋メモ", "＋シンボル"] {
            app.buttons[button].tap()
            let hint = element(app, "operation-hint")
            XCTAssertTrue(hint.exists)
            let original = hint.frame
            let canvas = element(app, "circuit-canvas")
            canvas.pinch(withScale: 0.5, velocity: -1)
            let source = canvas.coordinate(withNormalizedOffset: CGVector(dx:0.8,dy:0.8))
            source.press(forDuration:0.1,thenDragTo:source.withOffset(CGVector(dx:-60,dy:-50)))
            XCTAssertEqual(hint.frame.minX,original.minX,accuracy:1)
            XCTAssertEqual(hint.frame.minY,original.minY,accuracy:1)
            XCTAssertEqual(hint.frame.width,original.width,accuracy:1)
            XCTAssertEqual(hint.frame.height,original.height,accuracy:1)
        }
    }

    @MainActor
    private func routePoints(_ app: XCUIApplication, _ index: Int) -> [CGPoint] {
        let value = element(app,"wire-\(index)-points").value as? String ?? ""
        return value.split(separator:";").compactMap {
            let xy = $0.split(separator:",").compactMap { Double($0) }
            return xy.count == 2 ? CGPoint(x:xy[0],y:xy[1]) : nil
        }
    }

    @MainActor
    private func assertRoutesClear(_ app: XCUIApplication, count: Int) {
        let bodies = ["24 V → 5 V","Main MCU","CAN","Temperature"].map { name -> CGRect in
            let xy = coordinates(app.buttons["symbol-\(name)-pin-0"])
            return CGRect(x:xy[0],y:xy[1]-32,width:150,height:64)
        }
        var routes: [[CGPoint]] = []
        for i in 0..<count {
            let points = routePoints(app,i)
            XCTAssertGreaterThanOrEqual(points.count,2)
            guard points.count >= 2 else { continue }
            let ends = coordinates(element(app,"wire-\(i)"))
            XCTAssertEqual([points[0].x,points[0].y,points.last!.x,points.last!.y],ends.map { CGFloat($0) })
            for (a,b) in zip(points,points.dropFirst()) {
                XCTAssertTrue(a.x == b.x || a.y == b.y)
                for r in bodies {
                    let inside = a.y == b.y
                        ? a.y > r.minY && a.y < r.maxY && max(a.x,b.x) > r.minX && min(a.x,b.x) < r.maxX
                        : a.x > r.minX && a.x < r.maxX && max(a.y,b.y) > r.minY && min(a.y,b.y) < r.maxY
                    XCTAssertFalse(inside,"wire \(i) intersects \(r)")
                }
                for other in routes {
                    for (c,d) in zip(other,other.dropFirst()) {
                        let horizontal = a.y == b.y && c.y == d.y && a.y == c.y && min(max(a.x,b.x),max(c.x,d.x)) > max(min(a.x,b.x),min(c.x,d.x))
                        let vertical = a.x == b.x && c.x == d.x && a.x == c.x && min(max(a.y,b.y),max(c.y,d.y)) > max(min(a.y,b.y),min(c.y,d.y))
                        if horizontal || vertical {
                            XCTAssertTrue([points[0],points.last!].contains { pin in
                                (pin == other.first || pin == other.last) && (pin == a || pin == b) && (pin == c || pin == d)
                            })
                        }
                    }
                }
            }
            for (pin,next) in [(points[0],points[1]),(points.last!,points[points.count-2])] {
                XCTAssertEqual(pin.y,next.y)
                let left = bodies.contains { $0.minX == pin.x && $0.midY == pin.y }
                XCTAssertTrue(left ? next.x < pin.x : next.x > pin.x)
            }
            routes.append(points)
        }
    }

    @MainActor
    func testRequestedRoutesAndSymbolMovementAvoidBodiesAndOverlaps() {
        let app = XCUIApplication(); app.launch()
        assertRoutesClear(app,count:3)
        let pairs = [("Temperature",1,"CAN",0),("Temperature",1,"Main MCU",1),("24 V → 5 V",0,"Main MCU",0)]
        for (i,pair) in pairs.enumerated() {
            app.buttons["配線"].tap()
            app.buttons["symbol-\(pair.0)-pin-\(pair.1)"].tap()
            app.buttons["symbol-\(pair.2)-pin-\(pair.3)"].tap()
            assertRoutesClear(app,count:4+i)
        }
        let symbol = element(app,"symbol-Main MCU")
        let source = symbol.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:48,dy:48)))
        assertRoutesClear(app,count:6)
    }

    @MainActor
    func testSegmentDragKeepsEndpointsViewportCountAndManualPosition() {
        let app = XCUIApplication(); app.launch()
        let before = routePoints(app,0)
        let viewport = element(app,"circuit-canvas").value as? String
        let endpoint = coordinates(element(app,"wire-0"))
        let target = element(app,"wire-0-segment-1")
        XCTAssertTrue(target.exists)
        let source = target.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:-20,dy:12)))
        let after = routePoints(app,0)
        XCTAssertLessThan(after[1].x,before[1].x-10)
        XCTAssertEqual(after[1].y,before[1].y)
        XCTAssertEqual(after[2].y,before[2].y)
        XCTAssertEqual(after[1].x,after[2].x)
        XCTAssertEqual(coordinates(element(app,"wire-0")),endpoint)
        XCTAssertEqual(element(app,"circuit-canvas").value as? String,viewport)
        XCTAssertFalse(element(app,"wire-3").exists)
        let symbol = element(app,"symbol-24 V → 5 V")
        let symbolSource = symbol.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        symbolSource.press(forDuration:0.2,thenDragTo:symbolSource.withOffset(CGVector(dx:-20,dy:-20)))
        let attached = routePoints(app,0)
        XCTAssertTrue(zip(attached,attached.dropFirst()).contains { $0.x == after[1].x && $1.x == after[1].x })
        app.buttons["選択"].tap()
        // Clear symbol selection on a blank area before opening the diagram inspector.
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:CGVector(dx:0.85,dy:0.85)).tap()
        assertWireCount(app,"3")
    }

    @MainActor
    func testSegmentDragStopsAtBodyBoundary() {
        let app = XCUIApplication(); app.launch()
        let target = element(app,"wire-0-segment-1")
        let source = target.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:200,dy:0)))
        let after = routePoints(app,0)
        XCTAssertEqual(after[1].x,295,accuracy:0.1)
        XCTAssertEqual(after[2].x,295,accuracy:0.1)
        XCTAssertEqual(coordinates(element(app,"wire-0")),[195,160,295,250])
    }

    // Start through viewport coordinates, independently of the tiny accessibility
    // target. Both sides of the short line must work when the background gets input.
    @MainActor
    func testShortLineFromViewportDoesNotPan() {
        assertShortLineFromViewport(touchOffset: -1, diagonal: 0, returnToOrigin: false)
    }

    @MainActor
    func testShortLineFromViewportUpdatesCrossing() {
        assertShortLineFromViewport(touchOffset: 1, diagonal: 0, returnToOrigin: true)
    }

    @MainActor
    func testShortLineFromViewportDiagonalReturnKeepsCanvasFixed() {
        assertShortLineFromViewport(touchOffset: 0, diagonal: 18, returnToOrigin: true)
    }

    @MainActor
    private func assertShortLineFromViewport(touchOffset: CGFloat, diagonal: CGFloat, returnToOrigin: Bool) {
        let app = XCUIApplication(); app.launch()
        let vertical = element(app,"wire-0-segment-1").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        vertical.press(forDuration:0.2,thenDragTo:vertical.withOffset(CGVector(dx:-6,dy:0)))
        let canvas = element(app,"circuit-canvas")
        let viewport = canvas.value as? String
        let before = routePoints(app,2)
        let endpoints = coordinates(element(app,"wire-2"))
        let origin = canvas.coordinate(withNormalizedOffset:.zero)
        let source = origin.withOffset(CGVector(dx:(before[2].x+before[3].x)/2+touchOffset,dy:before[2].y))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:diagonal,dy:-97)))
        let after = routePoints(app,2)
        XCTAssertEqual(after.count,before.count)
        for i in before.indices {
            XCTAssertEqual(after[i].x,before[i].x,accuracy:1)
            XCTAssertEqual(after[i].y,before[i].y - ([2,3].contains(i) ? 97 : 0),accuracy:1)
        }
        XCTAssertEqual(coordinates(element(app,"wire-0-hops")),[269,205])
        if returnToOrigin {
            let back = origin.withOffset(CGVector(dx:(after[2].x+after[3].x)/2,dy:after[2].y))
            back.press(forDuration:0.2,thenDragTo:back.withOffset(CGVector(dx:-diagonal,dy:97)))
            XCTAssertEqual(routePoints(app,2),before)
            XCTAssertEqual(element(app,"wire-0-hops").value as? String,"")
        }
        XCTAssertEqual(canvas.value as? String,viewport)
        XCTAssertEqual(coordinates(element(app,"wire-2")),endpoints)
        assertWireCount(app,"3")
    }

    @MainActor
    func testBlankCanvasDragCrossingLineRemainsPan() {
        let app = XCUIApplication(); app.launch()
        let before = routePoints(app,2)
        let canvas = element(app,"circuit-canvas")
        let source = canvas.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:269,dy:420))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:0,dy:-97)))
        XCTAssertEqual(routePoints(app,2),before)
        XCTAssertEqual(canvas.value as? String,"scale=100, offsetX=0, offsetY=-97")
    }

    @MainActor
    func testShortHorizontalSegmentDragDoesNotSelectAdjacentVerticalSegment() {
        let app = XCUIApplication(); app.launch()
        let before = routePoints(app,2)
        let viewport = element(app,"circuit-canvas").value as? String
        let endpoints = coordinates(element(app,"wire-2"))
        let source = element(app,"wire-2-segment-2")
            .coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:0,dy:-97)))
        let after = routePoints(app,2)
        XCTAssertEqual(after.count,before.count)
        for index in before.indices {
            XCTAssertEqual(after[index].x,before[index].x,accuracy:0.1)
            XCTAssertEqual(after[index].y,before[index].y - ([2,3].contains(index) ? 97 : 0),accuracy:1)
        }
        XCTAssertEqual(coordinates(element(app,"wire-2")),endpoints)
        XCTAssertEqual(element(app,"circuit-canvas").value as? String,viewport)
        assertWireCount(app,"3")
    }

    @MainActor
    func testCrossingMetadataAppearsAndDisappearsWithoutChangingEndpoints() {
        let app = XCUIApplication(); app.launch()
        let endpoint = coordinates(element(app,"wire-0"))
        func drag(_ id: String, _ dx: CGFloat, _ dy: CGFloat) {
            let source = element(app,id).coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:dx,dy:dy)))
        }
        drag("wire-0-segment-1",-6,0)
        XCTAssertEqual(routePoints(app,0)[1].x,269,accuracy:1)
        drag("wire-2-segment-2",0,-97)
        XCTAssertEqual(routePoints(app,2)[2].y,205,accuracy:1)
        let hops = element(app,"wire-0-hops")
        XCTAssertFalse((hops.value as? String ?? "").isEmpty)
        XCTAssertEqual(coordinates(element(app,"wire-0")),endpoint)
        XCTAssertFalse(element(app,"wire-3").exists)
        drag("wire-0-segment-1",-30,0)
        XCTAssertEqual(hops.value as? String,"")
        XCTAssertEqual(coordinates(element(app,"wire-0")),endpoint)
        assertWireCount(app,"3")
    }

    @MainActor
    func testShortHorizontalDiagonalDragAndReturnRecomputesCrossings() {
        let app = XCUIApplication(); app.launch()
        func drag(_ id: String, _ dx: CGFloat, _ dy: CGFloat) {
            let target = element(app,id)
            XCTAssertTrue(target.isHittable)
            let source = target.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:dx,dy:dy)))
        }
        drag("wire-0-segment-1",-6,0)
        let before = routePoints(app,2)
        let viewport = element(app,"circuit-canvas").value as? String
        let symbols = ["24 V → 5 V","Main MCU","CAN","Temperature"].map {
            element(app,"symbol-\($0)").value as? String
        }
        drag("wire-2-segment-2",18,-97)
        let after = routePoints(app,2)
        XCTAssertEqual(after.count,before.count)
        for index in before.indices {
            XCTAssertEqual(after[index].x,before[index].x,accuracy:0.1)
            XCTAssertEqual(after[index].y,before[index].y - ([2,3].contains(index) ? 97 : 0),accuracy:1)
        }
        let hops = coordinates(element(app,"wire-0-hops"))
        XCTAssertEqual(hops.count,2)
        if hops.count == 2 {
            XCTAssertEqual(hops[0],269,accuracy:1)
            XCTAssertEqual(hops[1],205,accuracy:1)
        }
        drag("wire-2-segment-2",-18,97)
        let restored = routePoints(app,2)
        for index in before.indices {
            XCTAssertEqual(restored[index].x,before[index].x,accuracy:0.1)
            XCTAssertEqual(restored[index].y,before[index].y,accuracy:1)
        }
        XCTAssertEqual(element(app,"wire-0-hops").value as? String,"")
        XCTAssertEqual(element(app,"circuit-canvas").value as? String,viewport)
        XCTAssertEqual(["24 V → 5 V","Main MCU","CAN","Temperature"].map {
            element(app,"symbol-\($0)").value as? String
        },symbols)
        XCTAssertEqual(coordinates(element(app,"wire-2")),[195,390,295,250])
        assertWireCount(app,"3")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
