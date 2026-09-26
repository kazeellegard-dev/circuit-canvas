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
    private func assertRoutesClear(_ app: XCUIApplication, count: Int, extraSymbols: [String] = []) {
        let bodies = (["24 V → 5 V","Main MCU","CAN","Temperature"] + extraSymbols).map { name -> CGRect in
            let xy = coordinates(app.buttons["symbol-\(name)-pin-0"])
            let angle = element(app,"symbol-\(name)-rotation")
            if angle.exists {
                let rotation = Int(angle.value as? String ?? "0") ?? 0
                switch rotation {
                case 90: return CGRect(x:xy[0]-25,y:xy[1],width:50,height:100)
                case 180: return CGRect(x:xy[0]-100,y:xy[1]-25,width:100,height:50)
                case 270: return CGRect(x:xy[0]-25,y:xy[1]-100,width:50,height:100)
                default: return CGRect(x:xy[0],y:xy[1]-25,width:100,height:50)
                }
            }
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
                    let terminal = (a == points.first || b == points.last) &&
                        [points.first!,points.last!].contains { $0.y == r.midY && ($0.x == r.minX || $0.x == r.maxX) || $0.x == r.midX && ($0.y == r.minY || $0.y == r.maxY) }
                    if !terminal {
                        let padded = r.insetBy(dx:-12,dy:-12)
                        let tooClose = a.y == b.y
                            ? a.y > padded.minY && a.y < padded.maxY && max(a.x,b.x) > padded.minX && min(a.x,b.x) < padded.maxX
                            : a.x > padded.minX && a.x < padded.maxX && max(a.y,b.y) > padded.minY && min(a.y,b.y) < padded.maxY
                        XCTAssertFalse(tooClose,"wire \(i) lacks body clearance")
                    }
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
                if let body = bodies.first(where: { $0.midX == pin.x && ($0.minY == pin.y || $0.maxY == pin.y) }) {
                    XCTAssertEqual(pin.x,next.x)
                    XCTAssertTrue(body.minY == pin.y ? next.y < pin.y : next.y > pin.y)
                    XCTAssertGreaterThanOrEqual(abs(next.y-pin.y),24)
                    continue
                }
                XCTAssertEqual(pin.y,next.y)
                let left = bodies.contains { $0.minX == pin.x && $0.midY == pin.y }
                XCTAssertTrue(left ? next.x < pin.x : next.x > pin.x)
                let gaps = bodies.filter { $0.minY < pin.y && $0.maxY > pin.y }.compactMap { body -> CGFloat? in
                    if left && body.maxX < pin.x { return pin.x-body.maxX }
                    if !left && body.minX > pin.x { return body.minX-pin.x }
                    return nil
                }
                XCTAssertGreaterThanOrEqual(abs(next.x-pin.x), min(24,(gaps.min() ?? 48)/2)-0.1)
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
            let expected = i == 0
                ? "259.0,390.0;271.0,250.0;521.0,250.0"
                : "259.0,390.0;271.0,250.0;469.0,250.0;469.0,390.0;521.0,250.0"
            XCTAssertEqual(element(app,"canvas-junctions").value as? String,expected)
        }
        let symbol = element(app,"symbol-Main MCU")
        let source = symbol.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:48,dy:48)))
        assertRoutesClear(app,count:6)
        XCTAssertNotEqual(element(app,"canvas-junctions").value as? String,
                          "259.0,390.0;271.0,250.0;469.0,250.0;469.0,390.0;521.0,250.0")
        let junctions = Set((element(app,"canvas-junctions").value as? String ?? "").split(separator:";"))
        XCTAssertFalse(junctions.isEmpty)
        for index in 0..<6 {
            let hops = Set((element(app,"wire-\(index)-hops").value as? String ?? "").split(separator:";"))
            XCTAssertTrue(junctions.isDisjoint(with:hops))
        }
    }

    @MainActor
    func testCloseSymbolsRetainMaximumAvailableLead() {
        let app = XCUIApplication(); app.launch()
        let source = element(app,"symbol-CAN").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:-70,dy:0)))
        app.buttons["配線"].tap()
        app.buttons["symbol-Main MCU-pin-1"].tap()
        app.buttons["symbol-CAN-pin-1"].tap()
        let path = routePoints(app,3)
        XCTAssertGreaterThanOrEqual(path.count,4)
        guard path.count >= 4 else { return }
        let left = coordinates(app.buttons["symbol-CAN-pin-0"])
        XCTAssertEqual(path[1].x-path[0].x,CGFloat((left[0]-445)/2),accuracy:1)
        XCTAssertEqual(path[0].y,path[1].y)
        XCTAssertEqual(coordinates(element(app,"wire-3")),[445,250,left[0]+150,left[1]])
    }

    @MainActor
    func testJunctionsTrackSharedPinsAndSegmentDrags() {
        let app = XCUIApplication(); app.launch()
        let dots = element(app,"canvas-junctions")
        XCTAssertEqual(dots.value as? String,"271.0,250.0")
        XCTAssertEqual(element(app,"wire-0-hops").value as? String,"")
        let endpoint = coordinates(element(app,"wire-0"))
        let viewport = element(app,"circuit-canvas").value as? String
        let source = element(app,"wire-0-segment-1").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:-20,dy:0)))
        XCTAssertEqual(dots.value as? String,"271.0,250.0")
        XCTAssertEqual(coordinates(element(app,"wire-0")),endpoint)
        XCTAssertEqual(element(app,"circuit-canvas").value as? String,viewport)
        // Move the other terminal trunk to the pin: there is no shared run left.
        let trunk = element(app,"wire-0-segment-1").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        trunk.press(forDuration:0.2,thenDragTo:trunk.withOffset(CGVector(dx:44,dy:0)))
        XCTAssertEqual(dots.value as? String,"")
        let restore = element(app,"wire-0-segment-1").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        restore.press(forDuration:0.2,thenDragTo:restore.withOffset(CGVector(dx:-44,dy:0)))
        XCTAssertEqual(dots.value as? String,"271.0,250.0")
        app.buttons["配線"].tap()
        app.buttons["symbol-24 V → 5 V-pin-0"].tap()
        app.buttons["symbol-Main MCU-pin-0"].tap()
        let values = (dots.value as? String ?? "").split(separator:";")
        XCTAssertFalse(values.isEmpty)
        XCTAssertEqual(Set(values).count,values.count)
        XCTAssertEqual(coordinates(element(app,"wire-3")),[45,160,295,250])
        assertWireCount(app,"4")
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
        XCTAssertEqual(coordinates(element(app,"wire-0-hops")),[265,205])
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
        let source = canvas.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:265,dy:420))
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
        XCTAssertEqual(routePoints(app,0)[1].x,265,accuracy:1)
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
            XCTAssertEqual(hops[0],265,accuracy:1)
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
    private func place(_ app: XCUIApplication, category: String, name: String, x: CGFloat, y: CGFloat) {
        app.buttons["library-category-\(category)"].tap()
        let item = app.buttons["library-\(name)"]
        if !item.isHittable { item.swipeLeft() }
        item.tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero)
            .withOffset(CGVector(dx:x,dy:y)).tap()
        XCTAssertTrue(element(app,"symbol-\(name)").exists)
    }

    /// Two launches in total (circuit symbols, then blocks) instead of one per symbol.
    /// Symbols go on a grid below the initial diagram so none overlaps another's pins:
    /// vertical power symbols on one row, everything else on horizontal rows of six.
    @MainActor
    func testCircuitCataloguePlacementKindsAndTerminals() {
        let groups: [(String,[String])] = [
            ("電源",["直流電源","電池","交流電源","VCC","GND"]),
            ("受動部品",["抵抗","可変抵抗","コンデンサ","電解コンデンサ","コイル"]),
            ("半導体",["ダイオード","LED","ツェナーダイオード","フォトダイオード"]),
            ("スイッチ・保護",["スイッチ","押しボタン","ヒューズ"]),
            ("負荷・その他",["ランプ","モーター","スピーカー","水晶振動子","電圧計","電流計"])
        ]
        let app = XCUIApplication(); app.launch()
        var placed: [(category: String, name: String, x: CGFloat, y: CGFloat)] = []
        var horizontalCount = 0
        for (category,names) in groups {
            for name in names {
                let x: CGFloat, y: CGFloat
                if category == "電源" {
                    x = 75 + 130 * CGFloat(names.firstIndex(of:name)!); y = 560
                } else {
                    x = 75 + 130 * CGFloat(horizontalCount % 6); y = 680 + 90 * CGFloat(horizontalCount / 6)
                    horizontalCount += 1
                }
                place(app,category:category,name:name,x:x,y:y)
                placed.append((category,name,x,y))
            }
        }
        for item in placed {
            let name = item.name
            let symbols = app.descendants(matching:.any).matching(identifier:"symbol-\(name)")
            XCTAssertTrue((symbols.firstMatch.value as? String ?? "").contains("kind=\(name)"), name)
            XCTAssertTrue((symbols.firstMatch.value as? String ?? "").contains("style=circuit"), name)
            XCTAssertTrue(app.buttons["symbol-\(name)-pin-0"].firstMatch.exists, name)
            let rotation = name == "VCC" ? 270 : item.category == "電源" ? 90 : 0
            XCTAssertEqual(element(app,"symbol-\(name)-rotation").value as? String,"\(rotation)", name)
            let x = Double(item.x), y = Double(item.y)
            XCTAssertEqual(coordinates(app.buttons["symbol-\(name)-pin-0"]),
                           rotation == 90 ? [x,y-50] : rotation == 270 ? [x,y+50] : [x-50,y], name)
            let twoPins = name != "GND" && name != "VCC"
            if twoPins {
                XCTAssertEqual(coordinates(app.buttons["symbol-\(name)-pin-1"]),
                               rotation == 90 ? [x,y+50] : [x+50,y], name)
            }
            XCTAssertEqual(app.buttons["symbol-\(name)-pin-1"].firstMatch.exists, twoPins, name)
        }
        app.terminate()

        let blocks = ["DC/DC","MCU","CAN","センサー","汎用ブロック"]
        let blockApp = XCUIApplication(); blockApp.launch()
        for (index,name) in blocks.enumerated() {
            place(blockApp,category:"ブロック",name:name,x:100 + 200 * CGFloat(index % 4),y:560 + 110 * CGFloat(index / 4))
        }
        for name in blocks {
            // CAN also exists in the initial diagram; any match is a block.
            let symbols = blockApp.descendants(matching:.any).matching(identifier:"symbol-\(name)")
            XCTAssertTrue((symbols.firstMatch.value as? String ?? "").contains("kind=\(name)"), name)
            XCTAssertTrue((symbols.firstMatch.value as? String ?? "").contains("style=block"), name)
            XCTAssertTrue(blockApp.buttons["symbol-\(name)-pin-0"].firstMatch.exists, name)
            XCTAssertTrue(blockApp.buttons["symbol-\(name)-pin-1"].firstMatch.exists, name)
        }
        blockApp.terminate()
    }

    @MainActor
    func testCircuitWiringSelfRejectionMovementAndGroundDeletion() {
        let app = XCUIApplication(); app.launch()
        for name in ["24 V → 5 V","Main MCU","CAN","Temperature"] {
            XCTAssertTrue((element(app,"symbol-\(name)").value as? String ?? "").contains("style=block"))
        }
        place(app,category:"受動部品",name:"抵抗",x:160,y:530)
        place(app,category:"半導体",name:"LED",x:440,y:620)
        place(app,category:"電源",name:"GND",x:690,y:530)
        XCTAssertTrue(element(app,"symbol-GND").label.contains("未接続"))
        for name in ["抵抗","GND"] {
            app.buttons["配線"].tap()
            app.buttons["symbol-\(name)-pin-0"].tap()
            app.buttons["symbol-\(name)-pin-\(name == "GND" ? 0 : 1)"].tap()
            XCTAssertFalse(element(app,"wire-3").exists)
            XCTAssertTrue(app.buttons["symbol-\(name)-pin-0"].isSelected)
        }
        func connect(_ a: String, _ b: String) {
            app.buttons["配線"].tap(); app.buttons[a].tap(); app.buttons[b].tap()
        }
        connect("symbol-抵抗-pin-1","symbol-LED-pin-0")
        XCTAssertEqual(coordinates(element(app,"wire-3")),coordinates(app.buttons["symbol-抵抗-pin-1"]) + coordinates(app.buttons["symbol-LED-pin-0"]))
        let source = element(app,"symbol-抵抗").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:30,dy:-30)))
        XCTAssertEqual(coordinates(element(app,"wire-3")),coordinates(app.buttons["symbol-抵抗-pin-1"]) + coordinates(app.buttons["symbol-LED-pin-0"]))
        assertRoutesClear(app,count:4,extraSymbols:["抵抗","LED","GND"])
        connect("symbol-抵抗-pin-1","symbol-GND-pin-0")
        connect("symbol-LED-pin-1","symbol-GND-pin-0")
        XCTAssertTrue(element(app,"symbol-GND").label.contains("接続あり"))
        XCTAssertFalse((element(app,"canvas-junctions").value as? String ?? "").isEmpty)
        element(app,"symbol-GND").tap(); app.buttons["確認"].tap()
        XCTAssertEqual(element(app,"symbol-connection-status").value as? String,"接続あり", app.debugDescription)
        let field = app.textFields["名称"]
        field.tap()
        field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:3) + "接地")
        XCTAssertTrue(element(app,"symbol-接地").exists)
        app.buttons["シンボルを削除"].tap()
        XCTAssertFalse(element(app,"symbol-接地").exists)
        XCTAssertEqual(element(app,"wire-count").value as? String,"4")
    }

    @MainActor
    func testCircuitRotationControlsPreserveCenterAndWiring() {
        let app = XCUIApplication(); app.launch()
        element(app,"symbol-Main MCU").tap()
        XCTAssertFalse(app.buttons["symbol-Main MCU-rotate"].exists)
        app.buttons["確認"].tap()
        XCTAssertFalse(app.buttons["inspector-rotate"].exists)
        app.navigationBars["インスペクタ"].swipeDown()
        place(app,category:"受動部品",name:"抵抗",x:380,y:530)
        app.buttons["配線"].tap()
        app.buttons["symbol-Main MCU-pin-1"].tap()
        app.buttons["symbol-抵抗-pin-0"].tap()
        element(app,"symbol-抵抗").tap()
        let viewport = element(app,"circuit-canvas").value as? String
        for rotation in [90,180,270,0] {
            let button = app.buttons["symbol-抵抗-rotate"]
            button.tap()
            XCTAssertEqual(element(app,"symbol-抵抗-rotation").value as? String,"\(rotation)")
            let first = coordinates(app.buttons["symbol-抵抗-pin-0"])
            let second = coordinates(app.buttons["symbol-抵抗-pin-1"])
            XCTAssertEqual((first[0]+second[0])/2,380,accuracy:1)
            XCTAssertEqual((first[1]+second[1])/2,530,accuracy:1)
            XCTAssertEqual(abs(first[0]-second[0])+abs(first[1]-second[1]),100,accuracy:1)
            XCTAssertEqual(coordinates(element(app,"wire-3")),[445,250]+first)
            assertRoutesClear(app,count:4,extraSymbols:["抵抗"])
        }
        XCTAssertEqual(element(app,"circuit-canvas").value as? String,viewport)
        app.buttons["確認"].tap()
        for rotation in [90,180,270,0] {
            app.buttons["inspector-rotate"].tap()
            XCTAssertEqual(element(app,"symbol-抵抗-rotation").value as? String,"\(rotation)")
            XCTAssertEqual(element(app,"symbol-connection-status").value as? String,"接続あり")
        }
        app.buttons["シンボルを削除"].tap()
        XCTAssertFalse(element(app,"symbol-抵抗").exists)
        XCTAssertEqual(element(app,"wire-count").value as? String,"3")
    }

    @MainActor
    func testVerticalPowerSegmentDragBranchAndRotation() {
        let app = XCUIApplication(); app.launch()
        place(app,category:"電源",name:"直流電源",x:300,y:530)
        place(app,category:"電源",name:"GND",x:650,y:530)
        app.buttons["配線"].tap()
        app.buttons["symbol-直流電源-pin-1"].tap()
        app.buttons["symbol-GND-pin-0"].tap()
        let before = routePoints(app,3)
        guard let segment = (1..<max(1,before.count-2)).first(where: {
            before[$0].y == before[$0+1].y && abs(before[$0].x-before[$0+1].x) > 40
        }) else { return XCTFail("上下端子を結ぶ水平の中間線分が必要") }
        let start = element(app,"wire-3-segment-\(segment)").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.2,thenDragTo:start.withOffset(CGVector(dx:0,dy:20)))
        let after = routePoints(app,3)
        XCTAssertEqual(after.first,before.first)
        XCTAssertEqual(after.last,before.last)
        XCTAssertEqual(after[segment].x,before[segment].x)
        XCTAssertGreaterThan(after[segment].y,before[segment].y+10)
        app.buttons["配線"].tap()
        app.buttons["symbol-直流電源-pin-1"].tap()
        app.buttons["symbol-CAN-pin-1"].tap()
        XCTAssertFalse((element(app,"canvas-junctions").value as? String ?? "").isEmpty)
        let junctions = (element(app,"canvas-junctions").value as? String ?? "").split(separator:";").map {
            $0.split(separator:",").compactMap { Double($0) }
        }
        XCTAssertTrue(junctions.contains { $0.count == 2 && $0[0] == 300 && $0[1] > 580 })
        element(app,"symbol-直流電源").tap()
        app.buttons["symbol-直流電源-rotate"].tap()
        XCTAssertEqual(element(app,"symbol-直流電源-rotation").value as? String,"180")
        XCTAssertEqual(coordinates(app.buttons["symbol-直流電源-pin-0"]),[350,530])
        assertRoutesClear(app,count:5,extraSymbols:["直流電源","GND"])
        let source = element(app,"symbol-直流電源").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:20,dy:-20)))
        XCTAssertEqual(coordinates(element(app,"wire-3")).prefix(2).map { $0 },coordinates(app.buttons["symbol-直流電源-pin-1"]))
        assertRoutesClear(app,count:5,extraSymbols:["直流電源","GND"])
    }
}
