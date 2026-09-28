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
        func position(_ value: String?) -> [Double] {
            (value ?? "").components(separatedBy: CharacterSet(charactersIn: "xy=, ")).compactMap { Double($0) }
        }
        let start = note.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 60, dy: 90)))
        XCTAssertNotEqual(note.value as? String, before)
        // The note follows the finger 1:1.
        let moved = position(note.value as? String), origin = position(before)
        guard moved.count == 2, origin.count == 2 else { return XCTFail("cannot read the note position: \(String(describing: note.value)) / \(String(describing: before))") }
        XCTAssertEqual(moved[0] - origin[0], 60, accuracy: 3)
        XCTAssertEqual(moved[1] - origin[1], 90, accuracy: 3)
    }

    @MainActor
    func testNoteResizeHandlesSnappingAndMinimumSize() throws {
        let app = XCUIApplication(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        func size() -> [Double] {
            (element(app,"experiment-note-R12を変更-size").value as? String ?? "").split(separator:",").compactMap { Double($0) }
        }
        func position() -> [Double] {
            (note.value as? String ?? "").components(separatedBy: CharacterSet(charactersIn: "xy=, ")).compactMap { Double($0) }
        }
        XCTAssertEqual(size(),[170,100])
        XCTAssertFalse(element(app,"experiment-note-R12を変更-resize-br").exists)
        note.tap()
        XCTAssertTrue(element(app,"experiment-note-R12を変更-resize-br").waitForExistence(timeout:2))
        // The note starts only 80pt from the top edge of the canvas; move it clear of every edge first; a
        // corner handle placed off-canvas by a later resize would be untouchable, which is a test-setup problem,
        // not a production one (a note dragged near an edge in the app is bounded by the same canvas edges).
        let relocate = note.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        relocate.press(forDuration:0.2,thenDragTo:relocate.withOffset(CGVector(dx:0,dy:450)))
        func drag(_ corner: String, _ dx: CGFloat, _ dy: CGFloat) {
            let handle = element(app,"experiment-note-R12を変更-resize-\(corner)")
            let start = handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            start.press(forDuration:0.2,thenDragTo:start.withOffset(CGVector(dx:dx,dy:dy)))
        }
        // br: grows by 20pt steps; a drag too short for the next step changes nothing. The top-left corner
        // (center - half the size) must stay put, so the center moves by exactly half of what the size grew.
        let initialTopLeft = [position()[0]-size()[0]/2, position()[1]-size()[1]/2]
        drag("br",5,5)
        XCTAssertEqual(size(),[170,100])
        drag("br",40,40)
        XCTAssertEqual(size(),[210,140])
        XCTAssertEqual(position()[0]-size()[0]/2,initialTopLeft[0],accuracy:1,"br must keep the top-left corner fixed")
        XCTAssertEqual(position()[1]-size()[1]/2,initialTopLeft[1],accuracy:1,"br must keep the top-left corner fixed")

        // tr: the bottom-left corner stays; tl: the bottom-right corner stays; bl: the top-right corner stays.
        func corner(_ cx: Int, _ cy: Int) -> [Double] { [position()[0]+CGFloat(cx)*size()[0]/2, position()[1]+CGFloat(cy)*size()[1]/2] }
        let bottomLeft = corner(-1,1)
        drag("tr",30,-20)
        XCTAssertEqual(size(),[250,160])
        XCTAssertEqual(corner(-1,1)[0],bottomLeft[0],accuracy:1,"tr must keep the bottom-left corner fixed")
        XCTAssertEqual(corner(-1,1)[1],bottomLeft[1],accuracy:1,"tr must keep the bottom-left corner fixed")
        let bottomRight = corner(1,1)
        drag("tl",-20,-20)
        XCTAssertEqual(size(),[270,180])
        XCTAssertEqual(corner(1,1)[0],bottomRight[0],accuracy:1,"tl must keep the bottom-right corner fixed")
        XCTAssertEqual(corner(1,1)[1],bottomRight[1],accuracy:1,"tl must keep the bottom-right corner fixed")
        let topRight = corner(1,-1)
        drag("bl",-20,20)
        XCTAssertEqual(size(),[290,200])
        XCTAssertEqual(corner(1,-1)[0],topRight[0],accuracy:1,"bl must keep the top-right corner fixed")
        XCTAssertEqual(corner(1,-1)[1],topRight[1],accuracy:1,"bl must keep the top-right corner fixed")

        // The maximum (390 x 320) holds, however far past it the drag goes; the minimum likewise.
        // (A translation much larger than this, e.g. 900pt, can put the touch's destination outside the
        // simulator's screen, where XCUITest clamps it - so "far enough to clear the remaining gap, but still
        // an on-screen point" is used here, not an arbitrarily huge one.)
        drag("br",200,200)
        XCTAssertEqual(size(),[390,320])
        drag("br",200,200)
        XCTAssertEqual(size(),[390,320],"must not exceed the maximum")
        drag("tl",400,400)
        XCTAssertEqual(size(),[150,80],"must not go below the minimum")

        // The body text, at the minimum size, is fully inside the note (not cut off at the bottom) - existence
        // alone would not catch a clipped, unreadable line.
        let body = note.staticTexts["10 kΩへ変更して波形を再測定"]
        XCTAssertTrue(body.exists)
        XCTAssertGreaterThan(body.frame.height,0,"the body text must actually be laid out, not collapsed to zero height")
        XCTAssertLessThanOrEqual(body.frame.maxY,note.frame.maxY,"the body text must not be clipped at the minimum size")
        XCTAssertGreaterThanOrEqual(body.frame.minY,note.frame.minY)
        // Longer content, still at the minimum size: title wraps to two lines and the body is still inside.
        let field = app.textFields["タイトル"]
        note.tap(); app.buttons["確認"].tap()
        field.tap(); field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:20) + "とても長いタイトルを二行に折り返して確認する")
        let bodyField = app.textViews["note-body-editor"]
        bodyField.tap()
        bodyField.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:40) + "本文も長くして、最小サイズでどこまで読めるかを確認するための、長い説明文にする。")
        app.navigationBars["インスペクタ"].swipeDown()
        let longTitle = element(app,"experiment-note-とても長いタイトルを二行に折り返して確認する")
        XCTAssertTrue(longTitle.waitForExistence(timeout:2))
        let longBody = longTitle.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","確認するための")).firstMatch
        XCTAssertTrue(longBody.exists)
        XCTAssertGreaterThan(longBody.frame.height,0,"the long body text must actually be laid out, not collapsed to zero height")
        XCTAssertLessThanOrEqual(longBody.frame.maxY,longTitle.frame.maxY,"the long body text must not be clipped at the minimum size")
        XCTAssertGreaterThanOrEqual(longBody.frame.minY,longTitle.frame.minY)
    }

    @MainActor
    func testNoteRelateButtonWorksWithoutOpeningTheInspector() throws {
        let app = XCUIApplication(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        XCTAssertFalse(element(app,"experiment-note-R12を変更-relate").exists)

        func size() -> [Double] { (element(app,"experiment-note-R12を変更-size").value as? String ?? "").split(separator:",").compactMap{Double($0)} }
        func position() -> [Double] { (note.value as? String ?? "").components(separatedBy: CharacterSet(charactersIn:"xy=, ")).compactMap{Double($0)} }
        func relateStart() -> [Double] { (element(app,"experiment-note-R12を変更-relate-start").value as? String ?? "").split(separator:",").compactMap{Double($0)} }
        // Same calculation the production code shares between drawing and this hidden accessibility value
        // (NoteCorner.point(in:)): the top-trailing corner of the note's current bounds.
        func expectedTopTrailing() -> [Double] { let p = position(), s = size(); return [p[0]+s[0]/2, p[1]-s[1]/2] }

        note.tap()
        let relate = element(app,"experiment-note-R12を変更-relate")
        XCTAssertTrue(relate.waitForExistence(timeout:2))
        relate.tap()
        // Step 1 (4A): pick which corner the line starts from - replaces the resize handles while picking.
        XCTAssertTrue(app.staticTexts["関連付ける角をタップ"].exists)
        XCTAssertFalse(element(app,"experiment-note-R12を変更-resize-tl").exists)
        let topTrailing = element(app,"experiment-note-R12を変更-relate-corner-topTrailing")
        XCTAssertTrue(topTrailing.waitForExistence(timeout:2))
        topTrailing.tap()
        // Step 2: tap the target - even one that lands on another card (here, the "Main MCU" symbol at
        // canvas (370,250)), which has its own tap gesture that would otherwise consume the touch first
        // (Codex major, 4A round 1: the target must be "any point on the canvas", not just empty space).
        XCTAssertTrue(app.staticTexts["関連付けたい位置をタップ"].exists)
        let target = element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:370,dy:250))
        target.tap()
        XCTAssertFalse(app.staticTexts["関連付けたい位置をタップ"].exists)
        XCTAssertEqual(element(app,"experiment-note-R12を変更-anchor").value as? String,"370,250,topTrailing")
        XCTAssertEqual(relateStart()[0],expectedTopTrailing()[0],accuracy:1)
        XCTAssertEqual(relateStart()[1],expectedTopTrailing()[1],accuracy:1)
        // Placing the target did not actually select "Main MCU" or move focus away from the note.
        XCTAssertFalse(element(app,"symbol-Main MCU-resize-tl").exists)

        // Moving the note afterwards must not move the target (far) end of the line - only the note-side end
        // (relate-start), which is derived from the note's own bounds, follows.
        let start = note.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:30,dy:20)))
        XCTAssertEqual(position()[0]-30,430,accuracy:3,"the note must actually have moved")
        XCTAssertEqual(element(app,"experiment-note-R12を変更-anchor").value as? String,"370,250,topTrailing","the target end must stay fixed when the note moves")
        XCTAssertEqual(relateStart()[0],expectedTopTrailing()[0],accuracy:1,"the near end must follow the move")
        XCTAssertEqual(relateStart()[1],expectedTopTrailing()[1],accuracy:1)

        // Resizing the note must also move the near end (still to the same corner) without touching the anchor.
        XCTAssertTrue(element(app,"experiment-note-R12を変更-resize-br").waitForExistence(timeout:2))
        let sizeBeforeResize = size(), startBeforeResize = relateStart()
        let handle = element(app,"experiment-note-R12を変更-resize-br")
        let handleStart = handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        handleStart.press(forDuration:0.05,thenDragTo:handleStart.withOffset(CGVector(dx:40,dy:40)))
        // The resize must actually have happened (br grows the note; the top-trailing X moves right with it) -
        // not just that the invariant checks below would also pass on an unchanged size (Codex minor, round 2).
        XCTAssertGreaterThan(size()[0],sizeBeforeResize[0],"br must have grown the note")
        XCTAssertGreaterThan(relateStart()[0],startBeforeResize[0],"the near end's X must move right with the growing top-trailing corner")
        XCTAssertEqual(element(app,"experiment-note-R12を変更-anchor").value as? String,"370,250,topTrailing","the target end must stay fixed when the note resizes")
        XCTAssertEqual(relateStart()[0],expectedTopTrailing()[0],accuracy:1,"the near end must follow the resize")
        XCTAssertEqual(relateStart()[1],expectedTopTrailing()[1],accuracy:1)

        // The long-press context menu route (S5) still works, independently of the canvas button, and goes
        // through the same corner-pick step.
        note.press(forDuration:0.6)
        app.buttons["関連付け"].tap()
        let bottomLeading = element(app,"experiment-note-R12を変更-relate-corner-bottomLeading")
        XCTAssertTrue(bottomLeading.waitForExistence(timeout:2))
        bottomLeading.tap()
        XCTAssertTrue(app.staticTexts["関連付けたい位置をタップ"].exists)
        let secondTarget = element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:500,dy:600))
        secondTarget.tap()
        XCTAssertEqual(element(app,"experiment-note-R12を変更-anchor").value as? String,"500,600,bottomLeading")

        // The button's low-zoom sizing (>= 32pt on screen, per Codex review) is covered by a unit test on the
        // underlying formula (ResizableGeometry.screenConstant): a live pinch here could not be trusted to reliably
        // change the reported scale in this harness - it sometimes registered as a plain pan instead - so a
        // hard assertion on it would either be flaky or silently prove nothing.
    }

    @MainActor
    func testTappingTheBackgroundWhilePickingARelateCornerCancelsInsteadOfLeavingTheHintStuck() throws {
        let app = XCUIApplication(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        note.tap()
        element(app,"experiment-note-R12を変更-relate").tap()
        XCTAssertTrue(app.staticTexts["関連付ける角をタップ"].waitForExistence(timeout:2))
        // A background tap while still choosing a corner (Codex minor, 4A round 1) must cancel relate mode
        // outright, not just deselect while leaving the "pick a corner" hint stuck on screen.
        let background = element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:50,dy:900))
        background.tap()
        XCTAssertFalse(app.staticTexts["関連付ける角をタップ"].exists)
        XCTAssertFalse(app.staticTexts["関連付けたい位置をタップ"].exists)
        XCTAssertFalse(element(app,"experiment-note-R12を変更-relate-corner-topLeading").exists)
    }

    @MainActor
    func testZoomMenuOffersFixedPercentagesAndAppliesThemExactly() throws {
        let app = XCUIApplication(); app.launch()
        let canvas = element(app,"circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout:3))
        func scalePercent() -> Int? {
            guard let value = canvas.value as? String, let after = value.range(of:"scale=") else { return nil }
            return Int(value[after.upperBound...].prefix { $0.isNumber })
        }
        // The Int-rounded percentage above cannot tell an exact 1.0 from a near-miss, so also read the raw
        // value setZoom(_:) assigns (Codex minor, 4E round 2).
        func exactScale() -> Double? { Double(element(app,"zoom-scale-exact").value as? String ?? "") }
        XCTAssertEqual(scalePercent(),100)
        app.buttons["zoom-menu"].tap()
        for percent in [25,50,100,150,200] {
            XCTAssertTrue(app.buttons["zoom-\(percent)"].waitForExistence(timeout:2),"the menu must offer \(percent)%")
        }
        app.buttons["zoom-150"].tap()
        XCTAssertEqual(scalePercent(),150)
        XCTAssertEqual(exactScale() ?? -1,1.5,accuracy:0.0001)
        // Coming from a non-100% state, selecting 100% must land exactly on it (not some pinch-drifted value).
        app.buttons["zoom-menu"].tap()
        app.buttons["zoom-100"].tap()
        XCTAssertEqual(scalePercent(),100)
        XCTAssertEqual(exactScale() ?? -1,1,accuracy:0.0001)
        app.buttons["zoom-menu"].tap()
        app.buttons["zoom-25"].tap()
        XCTAssertEqual(scalePercent(),25)
        app.buttons["zoom-menu"].tap()
        app.buttons["zoom-200"].tap()
        XCTAssertEqual(scalePercent(),200)
    }

    @MainActor
    func testZoomMenuKeepsTheViewportCenterEvenWhenAlreadyPannedNearTheEdge() throws {
        let app = XCUIApplication(); app.launch()
        let canvas = element(app,"circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout:3))
        func viewport() -> [Double] { (element(app,"viewport-size").value as? String ?? "").split(separator:",").compactMap{Double($0)} }
        // Full-precision offset/scale (not the Int-truncated ones in circuit-canvas's own -value), since a
        // low zoom-out turns even 1pt of truncation into several pt of canvas-coordinate error.
        func offsetAndScale() -> (x: Double, y: Double, scale: Double) {
            let parts = (element(app,"canvas-offset-exact").value as? String ?? "").split(separator:",").compactMap{Double($0)}
            let scale = Double(element(app,"zoom-scale-exact").value as? String ?? "") ?? .nan
            return (parts.first ?? .nan, parts.count > 1 ? parts[1] : .nan, scale)
        }
        func canvasCenter() -> CGPoint {
            let v = viewport(), o = offsetAndScale()
            return CGPoint(x: (v[0]/2 - o.x)/o.scale, y: (v[1]/2 - o.y)/o.scale)
        }
        // Pan (in several safe-sized steps, each a fresh gesture from the same screen point, so their
        // translations accumulate) far enough that this necessarily reaches boundedCanvasOffset's 200pt edge
        // margin - exactly the situation the fixed setZoom(_:) must not disturb (Codex major, 4E round 1).
        let source = canvas.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:291,dy:473))
        for _ in 0..<3 { source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:400,dy:300))) }
        // Confirm the pan actually happened, and landed exactly on the edge margin - not just "somewhere
        // panned" - so this test is known to exercise the bug, not merely fail to disprove it (Codex minor,
        // 4E round 2).
        let v = viewport(), afterPan = offsetAndScale()
        XCTAssertEqual(afterPan.x,v[0]-200,accuracy:2,"the pan must have reached boundedCanvasOffset's edge")
        XCTAssertEqual(afterPan.y,v[1]-200,accuracy:2)
        let before = canvasCenter()
        app.buttons["zoom-menu"].tap()
        app.buttons["zoom-200"].tap()
        XCTAssertEqual(offsetAndScale().scale,2,accuracy:0.0001,"the selection itself must have taken effect")
        XCTAssertEqual(canvasCenter().x,before.x,accuracy:1,"zooming must not move the point that was centered")
        XCTAssertEqual(canvasCenter().y,before.y,accuracy:1)
        // And back down, from a now-panned, zoomed-in state.
        let midway = canvasCenter()
        app.buttons["zoom-menu"].tap()
        app.buttons["zoom-50"].tap()
        XCTAssertEqual(offsetAndScale().scale,0.5,accuracy:0.0001)
        XCTAssertEqual(canvasCenter().x,midway.x,accuracy:1)
        XCTAssertEqual(canvasCenter().y,midway.y,accuracy:1)
    }

    @MainActor
    func testZoomMenuLandsExactlyOnAPresetAfterAPinchToANonPresetScale() throws {
        let app = XCUIApplication(); app.launch()
        let canvas = element(app,"circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout:3))
        func exactScale() -> Double { Double(element(app,"zoom-scale-exact").value as? String ?? "") ?? .nan }
        canvas.pinch(withScale:0.73,velocity:-1)
        // XCUITest's synthetic pinch is unreliable in this harness (see the note on
        // testOperationHintStaysFixedDuringZoomAndPan): confirmed again here, precisely, via the exact scale -
        // it has been observed to leave canvasScale completely untouched rather than raising a
        // MagnificationGesture at all. There is no other in-app way to reach a non-preset scale to test from
        // (the menu itself only ever sets exact presets), so when that happens, skip rather than fail on an
        // environment limitation the production code has no part in.
        let presets: [Double] = [0.25,0.5,1,1.5,2]
        guard presets.allSatisfy({ abs(exactScale() - $0) > 0.001 }) else {
            throw XCTSkip("XCUITest's pinch did not land on a non-preset scale in this environment (known harness limitation) - nothing to test the menu selection against.")
        }
        app.buttons["zoom-menu"].tap()
        app.buttons["zoom-100"].tap()
        XCTAssertEqual(exactScale(),1,accuracy:0.0001)
    }

    /// The same acceptance criterion as above (selecting a preset from a non-preset scale must land exactly
    /// on it), but reaching that starting scale through a test-only launch hook instead of a live pinch -
    /// which this harness cannot reliably use to get there (see the skip above, and the note on
    /// testOperationHintStaysFixedDuringZoomAndPan) - so this one always actually runs (Codex major, 4E round 3).
    @MainActor
    func testZoomMenuLandsExactlyOnAPresetFromAnInjectedNonPresetStartingScale() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_INITIAL_ZOOM"] = "0.73"
        app.launch()
        let canvas = element(app,"circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout:3))
        func exactScale() -> Double { Double(element(app,"zoom-scale-exact").value as? String ?? "") ?? .nan }
        XCTAssertEqual(exactScale(),0.73,accuracy:0.0001,"the launch hook itself must have taken effect")
        app.buttons["zoom-menu"].tap()
        app.buttons["zoom-100"].tap()
        XCTAssertEqual(exactScale(),1,accuracy:0.0001)
        XCTAssertTrue(element(app,"circuit-canvas").value.map { ($0 as? String ?? "").contains("scale=100") } ?? false)
    }

    @MainActor
    func testSettingsCanRenameCanvasAndEditAMultilineDescription() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.navigationBars["Circuit Canvas"].waitForExistence(timeout:3))

        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout:2))
        let nameField = element(app,"settings-canvas-name")
        XCTAssertTrue(nameField.waitForExistence(timeout:2))
        nameField.tap()
        nameField.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:20) + "実験用基板")
        let descriptionField = element(app,"settings-canvas-description")
        XCTAssertEqual(descriptionField.value as? String,"","the description must start out empty")
        descriptionField.tap()
        descriptionField.typeText("1行目\n2行目")
        app.navigationBars["設定"].swipeDown()
        // The rename took effect (the app's own title), independently of the sheet being open.
        XCTAssertTrue(app.navigationBars["実験用基板"].waitForExistence(timeout:2))
        XCTAssertFalse(app.navigationBars["Circuit Canvas"].exists)

        // Reopened, the multi-line description is still there.
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout:2))
        XCTAssertEqual(descriptionField.value as? String,"1行目\n2行目")
    }

    @MainActor
    func testSettingsResetCancelledLeavesTheCanvasUntouched() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout:2))
        app.buttons["settings-reset-canvas"].tap()
        XCTAssertTrue(app.staticTexts["本当にリセットしますか？元に戻せません。"].waitForExistence(timeout:2))
        app.buttons["キャンセル"].tap()
        XCTAssertFalse(app.staticTexts["本当にリセットしますか？元に戻せません。"].exists)
        app.navigationBars["設定"].swipeDown()
        for name in ["24 V → 5 V","Main MCU","CAN","Temperature"] {
            XCTAssertTrue(element(app,"symbol-\(name)").exists,"cancelling must not have touched \(name)")
        }
        XCTAssertTrue(element(app,"experiment-note-R12を変更").exists)
        assertWireCount(app,"3")
    }

    @MainActor
    func testSettingsResetConfirmedClearsSymbolsWiresAndNotes() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout:2))
        app.buttons["settings-reset-canvas"].tap()
        XCTAssertTrue(app.staticTexts["本当にリセットしますか？元に戻せません。"].waitForExistence(timeout:2))
        app.buttons["リセット"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout:2))
        app.navigationBars["設定"].swipeDown()
        for name in ["24 V → 5 V","Main MCU","CAN","Temperature"] {
            XCTAssertFalse(element(app,"symbol-\(name)").exists,"\(name) must be gone after a confirmed reset")
        }
        XCTAssertFalse(element(app,"experiment-note-R12を変更").exists)
        assertWireCount(app,"0")
        app.navigationBars["インスペクタ"].swipeDown()   // assertWireCount opens it but does not close it

        // A reset also re-centres the viewport on the (now blank) canvas - easier to start drawing in any
        // direction than starting at the canvas's top-left corner (feedback, 2026-09-29).
        let viewport = (element(app,"viewport-size").value as? String ?? "").split(separator:",").compactMap{Double($0)}
        let scale = Double(element(app,"zoom-scale-exact").value as? String ?? "") ?? .nan
        let offset = (element(app,"canvas-offset-exact").value as? String ?? "").split(separator:",").compactMap{Double($0)}
        XCTAssertEqual(offset[0],viewport[0]/2 - 1200*scale,accuracy:1,"offsetX must centre canvas x=1200 (half of 2400) in the viewport")
        XCTAssertEqual(offset[1],viewport[1]/2 - 900*scale,accuracy:1,"offsetY must centre canvas y=900 (half of 1800) in the viewport")
    }

    @MainActor
    func testUndoRedoOnASymbolMoveAndAfterANewOperationRedoIsCleared() throws {
        let app = XCUIApplication(); app.launch()
        let symbol = element(app,"symbol-Main MCU")
        XCTAssertTrue(symbol.waitForExistence(timeout:3))

        XCTAssertFalse(app.buttons["undo-button"].isEnabled,"nothing to undo yet")
        XCTAssertFalse(app.buttons["redo-button"].isEnabled,"nothing to redo yet")

        let before = symbol.frame
        let start = symbol.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.1,thenDragTo:start.withOffset(CGVector(dx:60,dy:40)))
        let moved = symbol.frame
        XCTAssertNotEqual(moved.origin.x,before.origin.x,"the symbol must actually have moved")

        // Undo: back to the original position.
        XCTAssertTrue(app.buttons["undo-button"].isEnabled)
        app.buttons["undo-button"].tap()
        XCTAssertEqual(symbol.frame.origin.x,before.origin.x,accuracy:1)
        XCTAssertEqual(symbol.frame.origin.y,before.origin.y,accuracy:1)

        // Redo: forward again to the moved position.
        XCTAssertTrue(app.buttons["redo-button"].isEnabled)
        app.buttons["redo-button"].tap()
        XCTAssertEqual(symbol.frame.origin.x,moved.origin.x,accuracy:1)
        XCTAssertEqual(symbol.frame.origin.y,moved.origin.y,accuracy:1)

        // Undo again, then perform a different operation: redo must now be unavailable.
        app.buttons["undo-button"].tap()
        XCTAssertEqual(symbol.frame.origin.x,before.origin.x,accuracy:1)
        XCTAssertTrue(app.buttons["redo-button"].isEnabled,"still redoable right after an undo")
        start.press(forDuration:0.1,thenDragTo:start.withOffset(CGVector(dx:-30,dy:20)))
        XCTAssertFalse(app.buttons["redo-button"].isEnabled,"a new operation must clear the redo stack")
    }

    @MainActor
    func testUndoStackIsCappedAtTwentySteps() throws {
        let app = XCUIApplication(); app.launch()
        let symbol = element(app,"symbol-Main MCU")
        XCTAssertTrue(symbol.waitForExistence(timeout:3))
        let start = symbol.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        // 21 separate drags - each its own gesture, so each pushes its own undo step - oscillating a small
        // amount so the symbol (and so `start`, re-resolved against its current frame each time) never
        // drifts far from where it started.
        var afterFirstMove: CGRect = .zero
        for i in 0..<21 {
            let dy: CGFloat = (i % 2 == 0) ? 6 : -6
            start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:0,dy:dy)))
            if i == 0 { afterFirstMove = symbol.frame }
        }
        for step in 0..<20 {
            XCTAssertTrue(app.buttons["undo-button"].isEnabled,"step \(step)")
            app.buttons["undo-button"].tap()
        }
        XCTAssertFalse(app.buttons["undo-button"].isEnabled,"only 20 steps of history are kept - the 21st move's prior state was evicted")
        // The earliest restorable state is right after the first move (its "before" snapshot was the one
        // evicted), not the true original position (Codex minor, 4D round 1).
        XCTAssertEqual(symbol.frame.origin.x,afterFirstMove.origin.x,accuracy:1)
        XCTAssertEqual(symbol.frame.origin.y,afterFirstMove.origin.y,accuracy:1)
    }

    @MainActor
    func testUndoRedoOnAddingASymbolANoteAndAWire() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))

        // A symbol placed from the library (Codex major, 4D round 1: additions were not undoable at all).
        place(app,category:"ブロック",name:"汎用ブロック",x:600,y:550)
        XCTAssertTrue(element(app,"symbol-汎用ブロック").exists)
        app.buttons["undo-button"].tap()
        XCTAssertFalse(element(app,"symbol-汎用ブロック").exists,"undo must remove the just-placed symbol")
        app.buttons["redo-button"].tap()
        XCTAssertTrue(element(app,"symbol-汎用ブロック").exists,"redo must bring it back")

        // A note placed by tapping the canvas.
        app.buttons["＋メモ"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:150)).tap()
        XCTAssertTrue(element(app,"experiment-note-新しいメモ").exists)
        app.buttons["undo-button"].tap()
        XCTAssertFalse(element(app,"experiment-note-新しいメモ").exists)
        app.buttons["redo-button"].tap()
        XCTAssertTrue(element(app,"experiment-note-新しいメモ").exists)

        // A wire drawn between the new block's free pin and another symbol's free pin. assertWireCount opens
        // the inspector but does not close it, so it is followed by a dismiss whenever more interaction with
        // the canvas or toolbar comes after it.
        func checkWireCount(_ n: String) { assertWireCount(app,n); app.navigationBars["インスペクタ"].swipeDown() }
        checkWireCount("3")
        app.buttons["配線"].tap()
        app.buttons["symbol-汎用ブロック-pin-0"].tap()
        app.buttons["symbol-24 V → 5 V-pin-0"].tap()
        checkWireCount("4")
        app.buttons["undo-button"].tap()
        checkWireCount("3")
        app.buttons["redo-button"].tap()
        assertWireCount(app,"4")
    }

    @MainActor
    func testUndoRedoOnDeletingAConnectedSymbolRestoresWireEndpointsAndRoutes() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-Main MCU").waitForExistence(timeout:3))
        // Every initial wire touches Main MCU; capture all three routes to check they come back exactly.
        let before = (0..<3).map { routePoints(app,$0) }
        func routeSet(_ routes: [[CGPoint]]) -> Set<[String]> { Set(routes.map { $0.map { "\(Int($0.x)),\(Int($0.y))" } }) }

        element(app,"symbol-Main MCU").tap()
        app.buttons["確認"].tap()
        XCTAssertTrue(app.buttons["シンボルを削除"].waitForExistence(timeout:2))
        app.buttons["シンボルを削除"].tap()
        app.navigationBars["インスペクタ"].swipeDown()
        XCTAssertFalse(element(app,"symbol-Main MCU").exists)
        XCTAssertFalse(element(app,"wire-0").exists,"every wire touching Main MCU must be gone with it")

        app.buttons["undo-button"].tap()
        XCTAssertTrue(element(app,"symbol-Main MCU").waitForExistence(timeout:2))
        let after = (0..<3).map { routePoints(app,$0) }
        XCTAssertEqual(routeSet(after),routeSet(before),"all three wires must be restored with their exact prior routes")

        // Redo (Codex minor, 4D round 2): deletes it again.
        app.buttons["redo-button"].tap()
        XCTAssertFalse(element(app,"symbol-Main MCU").waitForExistence(timeout:2))
        XCTAssertFalse(element(app,"wire-0").exists,"redo must delete it again")
    }

    @MainActor
    func testUndoRedoOnWireSegmentDeletionStaysAvailableDuringEditMode() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"wire-0").waitForExistence(timeout:3))
        // All segments of every current wire, as an unordered set of endpoint pairs (see the equivalent
        // check in the 4C wire-deletion test) - used here to confirm the delete really happened, and that
        // undo/redo reproduce the exact before/after states, not just "some wire changed".
        func allSegments() -> Set<[CGPoint]> {
            var result = Set<[CGPoint]>(); var i = 0
            while element(app,"wire-\(i)").exists {
                let points = routePoints(app,i)
                for s in 0..<max(0,points.count-1) { result.insert([points[s],points[s+1]]) }
                i += 1
            }
            return result
        }
        let before = allSegments()
        app.buttons["edit-mode-toggle"].tap()
        XCTAssertTrue(element(app,"edit-mode-badge").waitForExistence(timeout:2))
        element(app,"edit-delete-wire-0-segment-0").tap()
        let afterDelete = allSegments()
        XCTAssertNotEqual(afterDelete,before,"the deletion must actually have changed something")

        // Undo is deliberately not greyed out by edit mode - this is exactly the safety net it is for.
        XCTAssertTrue(app.buttons["undo-button"].isEnabled)
        app.buttons["undo-button"].tap()
        XCTAssertTrue(element(app,"edit-mode-badge").exists,"undo must not itself leave edit mode")
        XCTAssertEqual(allSegments(),before,"undo must restore every wire's exact prior segments")

        app.buttons["redo-button"].tap()
        XCTAssertEqual(allSegments(),afterDelete,"redo must reproduce the exact post-delete state")
    }

    @MainActor
    func testInspectorRenameAndAnIndependentActionAreSeparateUndoSteps() throws {
        let app = XCUIApplication(); app.launch()
        place(app,category:"ブロック",name:"汎用ブロック",x:600,y:550)
        func size(_ title: String) -> [Double] { (element(app,"symbol-\(title)-size").value as? String ?? "").split(separator:",").compactMap{Double($0)} }

        // Grow it first, so the later size reset actually changes something to undo/redo (Codex minor,
        // 4D round 2).
        element(app,"symbol-汎用ブロック").tap()
        let handle = element(app,"symbol-汎用ブロック-resize-br")
        XCTAssertTrue(handle.waitForExistence(timeout:2))
        let hstart = handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        hstart.press(forDuration:0.1,thenDragTo:hstart.withOffset(CGVector(dx:60,dy:60)))
        let grownSize = size("汎用ブロック")
        XCTAssertNotEqual(grownSize,[90,30],"the drag must actually have grown it")

        app.buttons["確認"].tap()
        let nameField = app.textFields["名称"]
        XCTAssertTrue(nameField.waitForExistence(timeout:2))
        nameField.tap()
        nameField.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:20) + "A")
        // An independent confirm action (here, resetting the size) in between two renames.
        XCTAssertTrue(app.buttons["inspector-reset-size"].waitForExistence(timeout:2))
        app.buttons["inspector-reset-size"].tap()
        nameField.tap()
        nameField.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:5) + "B")
        app.navigationBars["インスペクタ"].swipeDown()
        XCTAssertTrue(element(app,"symbol-B").waitForExistence(timeout:2))
        XCTAssertEqual(size("B"),[90,30],"reset-size must have taken effect")

        // Undo #1: only the second rename (B→A) - the size reset must not be undone yet.
        app.buttons["undo-button"].tap()
        XCTAssertTrue(element(app,"symbol-A").waitForExistence(timeout:2),"one undo must revert only the second rename")
        XCTAssertFalse(element(app,"symbol-B").exists)
        XCTAssertEqual(size("A"),[90,30])

        // Undo #2: only the size reset - the name stays "A", the size grows back.
        app.buttons["undo-button"].tap()
        XCTAssertTrue(element(app,"symbol-A").exists,"the name must still be A")
        XCTAssertEqual(size("A"),grownSize,"the size reset must be undone on its own")

        // Undo #3: the first rename - back to the name it was placed with.
        app.buttons["undo-button"].tap()
        XCTAssertTrue(element(app,"symbol-汎用ブロック").waitForExistence(timeout:2))
        XCTAssertEqual(size("汎用ブロック"),grownSize)

        // Redo forward through all three steps, ending back where editing left off.
        app.buttons["redo-button"].tap()
        XCTAssertTrue(element(app,"symbol-A").waitForExistence(timeout:2))
        XCTAssertEqual(size("A"),grownSize)
        app.buttons["redo-button"].tap()
        XCTAssertEqual(size("A"),[90,30])
        app.buttons["redo-button"].tap()
        XCTAssertTrue(element(app,"symbol-B").waitForExistence(timeout:2))
        XCTAssertEqual(size("B"),[90,30])
    }

    @MainActor
    func testEditModeGraysOutOtherToolsAndDeletesSymbolsNotesAndWireSegments() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        XCTAssertFalse(element(app,"edit-mode-badge").exists)
        XCTAssertFalse(element(app,"symbol-24 V → 5 V-edit-delete").exists)

        app.buttons["edit-mode-toggle"].tap()
        XCTAssertTrue(element(app,"edit-mode-badge").waitForExistence(timeout:2))
        for label in ["選択","配線","＋シンボル","＋メモ","確認","設定"] {
            XCTAssertFalse(app.buttons[label].isEnabled,"\(label) must be greyed out in edit mode")
        }
        XCTAssertTrue(app.buttons["zoom-menu"].exists && !app.buttons["zoom-menu"].isEnabled)
        XCTAssertTrue(app.buttons["edit-mode-toggle"].isEnabled,"the edit button itself stays tappable")

        // Wires: tap-to-delete, no confirmation, and it takes effect. "確認" (the inspector, where the wire
        // count lives) is greyed out in edit mode, so the effect is checked directly on the canvas instead:
        // either wire-0 is gone outright, or its points changed - deleting a segment may drop the whole wire
        // or leave a shortened/disconnected fragment, per the task.
        let before0 = routePoints(app,0)
        XCTAssertTrue(element(app,"edit-delete-wire-0-segment-0").waitForExistence(timeout:2))
        element(app,"edit-delete-wire-0-segment-0").tap()
        XCTAssertFalse(app.staticTexts["削除しますか？"].exists,"wires need no confirmation")
        if element(app,"wire-0").exists {
            XCTAssertNotEqual(routePoints(app,0),before0,"deleting the tapped segment must have changed wire-0")
        }

        // Symbols: the ✗ badge asks first; cancelling changes nothing, confirming deletes just that one.
        let deleteMCU = element(app,"symbol-Main MCU-edit-delete")
        XCTAssertTrue(deleteMCU.waitForExistence(timeout:2))
        deleteMCU.tap()
        XCTAssertTrue(app.staticTexts["削除しますか？"].waitForExistence(timeout:2))
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(element(app,"symbol-Main MCU").exists,"cancelling must not delete")
        deleteMCU.tap()
        XCTAssertTrue(app.staticTexts["削除しますか？"].waitForExistence(timeout:2))
        app.buttons["削除"].tap()
        XCTAssertFalse(element(app,"symbol-Main MCU").exists)

        // Notes: same confirmation. Deleting continues to work without leaving edit mode.
        let deleteNote = element(app,"experiment-note-R12を変更-edit-delete")
        XCTAssertTrue(deleteNote.waitForExistence(timeout:2))
        deleteNote.tap()
        XCTAssertTrue(app.staticTexts["削除しますか？"].waitForExistence(timeout:2))
        app.buttons["削除"].tap()
        XCTAssertFalse(element(app,"experiment-note-R12を変更").exists)
        XCTAssertTrue(element(app,"edit-mode-badge").exists,"still in edit mode after several deletes")

        // Leaving edit mode hides the ✗ badges and re-enables the other tools.
        app.buttons["edit-mode-toggle"].tap()
        XCTAssertFalse(element(app,"edit-mode-badge").exists)
        XCTAssertFalse(element(app,"symbol-24 V → 5 V-edit-delete").exists)
        for label in ["選択","配線","＋シンボル","＋メモ","確認","設定"] {
            XCTAssertTrue(app.buttons[label].isEnabled,"\(label) must work again outside edit mode")
        }
    }

    @MainActor
    func testEditModeBlocksPlacingASymbolFromTheLibrary() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        app.buttons["edit-mode-toggle"].tap()
        XCTAssertTrue(element(app,"edit-mode-badge").waitForExistence(timeout:2))
        // The library button itself must be disabled - not just the toolbar's own "＋シンボル" - so a
        // library tap followed by a canvas tap cannot place anything either (Codex major, 4C round 1).
        XCTAssertFalse(app.buttons["library-汎用ブロック"].isEnabled)
        app.buttons["library-汎用ブロック"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:600,dy:550)).tap()
        XCTAssertFalse(element(app,"symbol-汎用ブロック").exists,"nothing must have been placed while in edit mode")
    }

    @MainActor
    func testEditModeWireDeletionRemovesOnlyTheTappedSegmentAndKeepsTheRest() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        app.buttons["edit-mode-toggle"].tap()
        XCTAssertTrue(element(app,"edit-mode-badge").waitForExistence(timeout:2))

        // Every segment of every current wire, as an unordered set of endpoint pairs - independent of which
        // wire index they end up under (deleting a middle segment appends the two remaining sides as new
        // wires at the end of the array, per deleteWireSegment).
        func allSegments() -> Set<[CGPoint]> {
            var result = Set<[CGPoint]>(); var i = 0
            while element(app,"wire-\(i)").exists {
                let points = routePoints(app,i)
                for s in 0..<max(0,points.count-1) { result.insert([points[s],points[s+1]]) }
                i += 1
            }
            return result
        }
        func deleteOneSegmentAndVerify() {
            let before = allSegments()
            // Pick whichever current wire has the most segments, and an interior one of its segments if it
            // has one - so this exercises a middle-segment split when the layout offers one, not just the
            // trivial single-segment case (Codex major, 4C round 1: "先頭・末尾・中間・唯一の区間" coverage).
            var wireIndex = 0, segmentCount = 0
            var i = 0
            while element(app,"wire-\(i)").exists {
                let c = routePoints(app,i).count - 1
                if c > segmentCount { segmentCount = c; wireIndex = i }
                i += 1
            }
            XCTAssertGreaterThan(segmentCount,0,"there must be a wire left to delete a segment from")
            let targetSegment = segmentCount > 2 ? 1 : 0
            let points = routePoints(app,wireIndex)
            let removed = [points[targetSegment],points[targetSegment+1]]
            XCTAssertTrue(before.contains(removed))

            element(app,"edit-delete-wire-\(wireIndex)-segment-\(targetSegment)").tap()
            XCTAssertFalse(app.staticTexts["削除しますか？"].exists,"wires need no confirmation")

            let after = allSegments()
            XCTAssertFalse(after.contains(removed),"the tapped segment must be gone")
            XCTAssertEqual(before.subtracting([removed]),after,"every other segment (on this wire and every other) must be unchanged")
        }
        // Once, then again on whatever is left (continued deletion without leaving edit mode).
        deleteOneSegmentAndVerify()
        deleteOneSegmentAndVerify()
    }

    @MainActor
    func testAddSymbolButtonSwitchesLibraryTabToTheSelectedCategory() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        // selectedLibrary defaults to a block; switch the visible tab away from it first.
        app.buttons["library-category-受動部品"].tap()
        XCTAssertTrue(app.buttons["library-category-受動部品"].isSelected)
        XCTAssertFalse(app.buttons["library-category-ブロック"].isSelected)

        app.buttons["＋シンボル"].tap()
        XCTAssertTrue(app.buttons["library-category-ブロック"].isSelected,"switching into symbol-placement mode must jump to the selected symbol's own category")
        XCTAssertFalse(app.buttons["library-category-受動部品"].isSelected)
    }

    @MainActor
    func testNewNoteDefaultsToMemoTypeAndIcon() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        app.buttons["＋メモ"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:150)).tap()
        XCTAssertTrue(element(app,"experiment-note-新しいメモ").waitForExistence(timeout:2))
        // "note.text" is the メモ type's own default icon, and unique among the six types' default icons -
        // a reliable proxy that the note was created with 種別=メモ, not the old 改造 default.
        XCTAssertEqual(element(app,"experiment-note-新しいメモ-icon").value as? String,"note.text")
    }

    @MainActor
    func testNoteEditButtonOpensTheInspectorDirectly() throws {
        let app = XCUIApplication(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        note.tap()
        let edit = element(app,"experiment-note-R12を変更-edit")
        XCTAssertTrue(edit.waitForExistence(timeout:2))
        edit.tap()
        XCTAssertTrue(app.navigationBars["インスペクタ"].waitForExistence(timeout:2))
        XCTAssertTrue(app.staticTexts["付箋"].exists)
    }

    @MainActor
    func testNoteBodyAcceptsMultilineText() throws {
        let app = XCUIApplication(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        note.tap()
        app.buttons["確認"].tap()
        let body = app.textViews["note-body-editor"]
        XCTAssertTrue(body.waitForExistence(timeout:2))
        body.tap()
        // Return must insert a newline (not end editing) - a TextField(axis: .vertical) could not do this.
        // Not asserting exact placement relative to the pre-existing text: where a plain tap lands the cursor
        // in a multi-line field is layout/device-sensitive, and is not what this is testing.
        body.typeText("1行目\n2行目")
        let value = body.value as? String ?? ""
        XCTAssertTrue(value.contains("1行目\n2行目"),"the newline must be preserved as typed, not end editing: \(value)")
        XCTAssertTrue(value.contains("10 kΩへ変更して波形を再測定"),"the original content must still be there: \(value)")

        // The typed newline must actually be saved to the model, not just shown live in the field.
        app.navigationBars["インスペクタ"].swipeDown()
        note.tap()
        app.buttons["確認"].tap()
        let reopened = (app.textViews["note-body-editor"].value as? String ?? "")
        XCTAssertTrue(reopened.contains("1行目\n2行目"),"the newline must have been saved: \(reopened)")
    }

    @MainActor
    func testNoteInspectorIsRenamedHasAMemoTypeAndAnIconPicker() throws {
        let app = XCUIApplication(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        // The initial note's icon matches its type (改造), same convention as a block's default icon.
        XCTAssertEqual(element(app,"experiment-note-R12を変更-icon").value as? String,"wrench.and.screwdriver.fill")
        note.tap()
        app.buttons["確認"].tap()
        XCTAssertTrue(app.staticTexts["付箋"].waitForExistence(timeout:2))
        XCTAssertFalse(app.staticTexts["実験メモ"].exists)
        app.buttons["note-type-picker"].tap()
        XCTAssertTrue(app.buttons["メモ"].waitForExistence(timeout:2))
        app.buttons["メモ"].tap()
        XCTAssertTrue(app.buttons["inspector-note-icon-picker"].waitForExistence(timeout:2))
        app.buttons["inspector-note-icon-picker"].tap()
        XCTAssertTrue(app.staticTexts["アイコンを選択"].waitForExistence(timeout:2))
        // Still shows the icon for the type the note started with (改造), not the newly selected メモ - the
        // icon only changes when the user actually picks one.
        XCTAssertTrue(app.buttons["icon-picker-wrench.and.screwdriver.fill"].isSelected)
        app.buttons["icon-picker-note.text"].tap()
        XCTAssertTrue(app.buttons["inspector-note-icon-picker"].waitForExistence(timeout:2))
        app.navigationBars["インスペクタ"].swipeDown()
        XCTAssertEqual(element(app,"experiment-note-R12を変更-icon").value as? String,"note.text")
    }

    @MainActor
    func testInspectorHasNoRotateOrRelateButtons() throws {
        let app = XCUIApplication(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        note.tap()
        app.buttons["確認"].tap()
        XCTAssertFalse(app.buttons["関連付けを開始"].exists)
        app.navigationBars["インスペクタ"].swipeDown()
        element(app,"symbol-Temperature").tap()
        app.buttons["確認"].tap()
        XCTAssertFalse(app.buttons["inspector-rotate"].exists)
        XCTAssertFalse(app.buttons["回転"].exists)
    }

    @MainActor
    func testDeletingNoteDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launch()

        let note = app.descendants(matching: .any).matching(identifier: "experiment-note-R12を変更").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        note.tap()
        app.buttons["確認"].tap()
        app.buttons["付箋を削除"].tap()

        XCTAssertFalse(note.waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["図面"].waitForExistence(timeout: 2))
    }

    // MARK: - Text item (5C)

    @MainActor
    func testTextTabPlacesAPlainTextItemThatCanBeDraggedAndEditedInTheInspector() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))

        app.buttons["library-category-テキスト"].tap()
        XCTAssertTrue(app.buttons["library-テキスト"].waitForExistence(timeout:2))
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:500)).tap()
        let text = element(app,"text-テキスト")
        XCTAssertTrue(text.waitForExistence(timeout:2),"a new text item defaults to the placeholder content テキスト")

        // Selecting it, then dragging it, moves it (like a note/symbol) - no pins, so nothing about wiring
        // applies to it.
        let before = text.value as? String
        func position(_ value: String?) -> [Double] {
            (value ?? "").components(separatedBy: CharacterSet(charactersIn: "xy=, ")).compactMap { Double($0) }
        }
        let start = text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 50, dy: -40)))
        let moved = position(text.value as? String), origin = position(before)
        guard moved.count == 2, origin.count == 2 else { return XCTFail("cannot read the text position: \(String(describing: text.value)) / \(String(describing: before))") }
        XCTAssertEqual(moved[0] - origin[0], 50, accuracy: 3)
        XCTAssertEqual(moved[1] - origin[1], -40, accuracy: 3)

        // Editing its content via the inspector, like a note's body.
        text.tap()
        app.buttons["確認"].tap()
        XCTAssertTrue(app.staticTexts["テキスト"].waitForExistence(timeout:2))
        let editor = app.textViews["text-body-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout:2))
        editor.tap()
        editor.typeText(" 編集済み")
        app.navigationBars["インスペクタ"].swipeDown()
        XCTAssertTrue(element(app,"text-テキスト 編集済み").waitForExistence(timeout:2))
    }

    @MainActor
    func testEditModeDeletesATextItemWithConfirmation() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        app.buttons["library-category-テキスト"].tap()
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:500)).tap()
        XCTAssertTrue(element(app,"text-テキスト").waitForExistence(timeout:2))

        app.buttons["edit-mode-toggle"].tap()
        let deleteText = element(app,"text-テキスト-edit-delete")
        XCTAssertTrue(deleteText.waitForExistence(timeout:2))
        deleteText.tap()
        XCTAssertTrue(app.staticTexts["削除しますか？"].waitForExistence(timeout:2))
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(element(app,"text-テキスト").exists,"cancelling must not delete")
        deleteText.tap()
        XCTAssertTrue(app.staticTexts["削除しますか？"].waitForExistence(timeout:2))
        app.buttons["削除"].tap()
        XCTAssertFalse(element(app,"text-テキスト").exists)
    }

    @MainActor
    func testUndoRedoOnAddingAndDeletingATextItem() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        app.buttons["library-category-テキスト"].tap()
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:500)).tap()
        XCTAssertTrue(element(app,"text-テキスト").exists)
        app.buttons["undo-button"].tap()
        XCTAssertFalse(element(app,"text-テキスト").exists,"undo must remove the just-placed text item")
        app.buttons["redo-button"].tap()
        XCTAssertTrue(element(app,"text-テキスト").exists,"redo must bring it back")

        element(app,"text-テキスト").tap()
        app.buttons["確認"].tap()
        app.buttons["テキストを削除"].tap()
        app.navigationBars["インスペクタ"].swipeDown()
        XCTAssertFalse(element(app,"text-テキスト").exists)
        app.buttons["undo-button"].tap()
        XCTAssertTrue(element(app,"text-テキスト").exists,"undo must restore the deleted text item")
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
    func testWireToolConnectsPinsAndRejectsDuplicatesBothWays() {
        let app = XCUIApplication(); app.launch()
        connectTemperatureToCAN(app)
        XCTAssertFalse(element(app, "wire-4").exists)
        let pins = ["symbol-Temperature-pin-1", "symbol-CAN-pin-0"]
        for reversed in [false, true] {
            app.buttons["配線"].tap()
            app.buttons[pins[reversed ? 1 : 0]].tap()
            app.buttons[pins[reversed ? 0 : 1]].tap()
            XCTAssertFalse(element(app, "wire-4").exists, "duplicate accepted (reversed: \(reversed))")
        }
        assertWireCount(app, "4")
    }

    @MainActor
    func testStartPinSelectionResetsAndIsReusedWithoutStrayWires() {
        let app = XCUIApplication(); app.launch()
        let temperatureRight = app.buttons["symbol-Temperature-pin-1"]
        let temperatureLeft = app.buttons["symbol-Temperature-pin-0"]
        let canRight = app.buttons["symbol-CAN-pin-1"]
        let endHint = app.staticTexts["終点のピンをタップ（直交で自動配線）"]
        // The opposite pin of the same symbol is ignored: the start stays selected, no wire.
        app.buttons["配線"].tap()
        temperatureRight.tap(); temperatureLeft.tap()
        XCTAssertTrue(temperatureRight.isSelected)
        XCTAssertFalse(element(app, "wire-3").exists)
        XCTAssertTrue(endHint.exists)
        // Pressing the wire tool again clears the start pin; a new start can be chosen.
        app.buttons["配線"].tap()
        XCTAssertFalse(temperatureRight.isSelected)
        XCTAssertTrue(app.staticTexts["始点のピンをタップ"].exists)
        canRight.tap()
        XCTAssertTrue(canRight.isSelected)
        XCTAssertFalse(element(app, "wire-3").exists)
        temperatureLeft.tap()
        XCTAssertEqual(coordinates(element(app, "wire-3")), [665, 250, 75, 390])
        // A start pin that was reset can be reused as the end pin, with matching coordinates.
        app.buttons["配線"].tap()
        temperatureRight.tap()
        app.buttons["配線"].tap()
        canRight.tap()
        XCTAssertTrue(canRight.isSelected)
        XCTAssertFalse(temperatureRight.isSelected)
        XCTAssertFalse(element(app, "wire-4").exists)
        temperatureRight.tap()
        let wire = element(app, "wire-4")
        XCTAssertTrue(wire.waitForExistence(timeout: 2))
        // Compare numeric coordinates: accessibility may include trailing zeros.
        XCTAssertEqual(coordinates(wire), [665, 250, 165, 390])
        XCTAssertEqual(coordinates(wire), coordinates(canRight) + coordinates(temperatureRight))
        assertWireCount(app, "5")
    }

    @MainActor
    private func coordinates(_ element: XCUIElement) -> [Double] {
        (element.value as? String ?? "").split(separator: ",").compactMap { Double($0) }
    }

    @MainActor
    func testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols() {
        let app = XCUIApplication()
        app.launch()
        connectTemperatureToCAN(app)
        for name in ["Temperature", "CAN"] {
            let symbol = element(app, "symbol-\(name)")
            let left = app.buttons["symbol-\(name)-pin-0"].frame
            let right = app.buttons["symbol-\(name)-pin-1"].frame
            // At the initial 100% viewport the model's ±45pt must match the UI.
            XCTAssertEqual(left.midX, symbol.frame.midX - 45, accuracy: 1)
            XCTAssertEqual(right.midX, symbol.frame.midX + 45, accuracy: 1)
            XCTAssertEqual(left.midY, right.midY, accuracy: 1)
        }
        XCTAssertEqual(coordinates(element(app, "wire-3")), [165, 390, 575, 250])
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
            // The symbol follows the finger 1:1 (it used to lag at about half speed).
            XCTAssertEqual(after[offset] - before[offset], 48, accuracy: 3, name)
            XCTAssertEqual(after[offset + 1] - before[offset + 1], 72, accuracy: 3, name)
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
    func testOperationHintStaysFixedDuringZoomAndPan() {
        let app = XCUIApplication(); app.launch()
        let canvas = element(app, "circuit-canvas")
        for button in ["配線", "＋メモ", "＋シンボル"] {
            app.buttons[button].tap()
            let hint = element(app, "operation-hint")
            XCTAssertTrue(hint.exists)
            let original = hint.frame
            // A pinch here is best-effort only: XCUITest's synthetic pinch has been unreliable in this
            // harness (see the note on testZoomMenuLandsExactlyOnAPresetAfterAPinchToANonPresetScale) - the
            // real guarantee for this comes from setZoom(_:)'s own tests.
            canvas.pinch(withScale: 0.5, velocity: -1)
            // Captured after the pinch, not before: the two-finger pan recognizer and the pinch gesture are
            // allowed to recognize simultaneously, so a successful pinch can itself move canvasOffset (its
            // center may not land exactly on the anchor) - comparing against a pre-pinch baseline would blame
            // that legitimate movement on the one-finger drag below (Codex minor, 5B round 3). Just the
            // offset, not the whole -value string: the pinch also legitimately changes the scale portion,
            // which must not fail this "did not pan" check either (Codex major, 5B round 2).
            let beforeOffset = element(app,"canvas-offset-exact").value as? String
            let source = canvas.coordinate(withNormalizedOffset: CGVector(dx:0.8,dy:0.8))
            // These tools no longer pan on a one-finger drag at all (5B, 2026-09-29 feedback) - confirming
            // that (not just that the hint didn't move) is what makes this a meaningful regression guard now.
            source.press(forDuration:0.1,thenDragTo:source.withOffset(CGVector(dx:-60,dy:-50)))
            XCTAssertEqual(element(app,"canvas-offset-exact").value as? String,beforeOffset,"\(button) must not pan on a one-finger drag")
            XCTAssertEqual(hint.frame.minX,original.minX,accuracy:1)
            XCTAssertEqual(hint.frame.minY,original.minY,accuracy:1)
            XCTAssertEqual(hint.frame.width,original.width,accuracy:1)
            XCTAssertEqual(hint.frame.height,original.height,accuracy:1)
        }

        // A genuine, reliably-testable pan: the dedicated pan tool, one finger (two-finger pan itself has no
        // public XCUITest API to synthesize - see TwoFingerPanOverlay's own tests).
        XCTAssertTrue(app.buttons["pan-mode-toggle"].waitForExistence(timeout:2))
        app.buttons["pan-mode-toggle"].tap()
        let hint = element(app,"operation-hint")
        XCTAssertTrue(hint.waitForExistence(timeout:2))
        let original = hint.frame
        let beforeOffset = canvas.value as? String
        let source = canvas.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:150))
        source.press(forDuration:0.1,thenDragTo:source.withOffset(CGVector(dx:-60,dy:-50)))
        XCTAssertNotEqual(canvas.value as? String,beforeOffset,"the pan tool must actually have panned")
        XCTAssertEqual(hint.frame.minX,original.minX,accuracy:1,"the hint must stay fixed during a real pan")
        XCTAssertEqual(hint.frame.minY,original.minY,accuracy:1)
    }

    @MainActor
    private func routePoints(_ app: XCUIApplication, _ index: Int) -> [CGPoint] {
        let value = element(app,"wire-\(index)-points").value as? String ?? ""
        return value.split(separator:";").compactMap {
            let xy = $0.split(separator:",").compactMap { Double($0) }
            return xy.count == 2 ? CGPoint(x:xy[0],y:xy[1]) : nil
        }
    }

    /// Bodies of the four initial blocks (90 × 30) plus any circuit symbols, each with the outward
    /// lead wires must keep: 24pt at block pins, 15pt at circuit-symbol pins.
    @MainActor
    private func assertRoutesClear(_ app: XCUIApplication, count: Int, extraSymbols: [String] = []) {
        let entries = (["24 V → 5 V","Main MCU","CAN","Temperature"] + extraSymbols).map { name -> (rect: CGRect, lead: CGFloat) in
            let xy = coordinates(app.buttons["symbol-\(name)-pin-0"])
            let angle = element(app,"symbol-\(name)-rotation")
            if angle.exists {
                let rotation = Int(angle.value as? String ?? "0") ?? 0
                switch rotation {
                case 90: return (CGRect(x:xy[0]-15,y:xy[1],width:30,height:60),15)
                case 180: return (CGRect(x:xy[0]-60,y:xy[1]-15,width:60,height:30),15)
                case 270: return (CGRect(x:xy[0]-15,y:xy[1]-60,width:30,height:60),15)
                default: return (CGRect(x:xy[0],y:xy[1]-15,width:60,height:30),15)
                }
            }
            // Blocks: the pins sit in the first row slot (15pt below the top edge); the size element gives width,height.
            let size = coordinates(element(app,"symbol-\(name)-size"))
            let box = size.count == 2 ? CGSize(width:size[0],height:size[1]) : CGSize(width:90,height:30)
            return (CGRect(x:xy[0],y:xy[1]-15,width:box.width,height:box.height),24)
        }
        let bodies = entries.map(\.rect)
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
                        [points.first!,points.last!].contains { ($0.y > r.minY && $0.y < r.maxY && ($0.x == r.minX || $0.x == r.maxX)) || ($0.x > r.minX && $0.x < r.maxX && ($0.y == r.minY || $0.y == r.maxY)) }
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
                if let entry = entries.first(where: { $0.rect.midX == pin.x && ($0.rect.minY == pin.y || $0.rect.maxY == pin.y) }) {
                    XCTAssertEqual(pin.x,next.x)
                    XCTAssertTrue(entry.rect.minY == pin.y ? next.y < pin.y : next.y > pin.y)
                    XCTAssertGreaterThanOrEqual(abs(next.y-pin.y),entry.lead)
                    continue
                }
                XCTAssertEqual(pin.y,next.y)
                let owner = entries.first { pin.y > $0.rect.minY && pin.y < $0.rect.maxY && ($0.rect.minX == pin.x || $0.rect.maxX == pin.x) }
                let left = owner.map { $0.rect.minX == pin.x } ?? false
                XCTAssertTrue(left ? next.x < pin.x : next.x > pin.x)
                let gaps = bodies.filter { $0.minY < pin.y && $0.maxY > pin.y }.compactMap { body -> CGFloat? in
                    if left && body.maxX < pin.x { return pin.x-body.maxX }
                    if !left && body.minX > pin.x { return body.minX-pin.x }
                    return nil
                }
                XCTAssertGreaterThanOrEqual(abs(next.x-pin.x), min(owner?.lead ?? 24,(gaps.min() ?? 48)/2)-0.1)
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
                ? "189.0,390.0;301.0,250.0;551.0,250.0"
                : "189.0,390.0;289.0,390.0;301.0,250.0;439.0,250.0;551.0,250.0"
            XCTAssertEqual(element(app,"canvas-junctions").value as? String,expected)
        }
        let symbol = element(app,"symbol-Main MCU")
        let source = symbol.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:48,dy:48)))
        assertRoutesClear(app,count:6)
        XCTAssertNotEqual(element(app,"canvas-junctions").value as? String,
                          "189.0,390.0;289.0,390.0;301.0,250.0;439.0,250.0;551.0,250.0")
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
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:-130,dy:0)))
        app.buttons["配線"].tap()
        app.buttons["symbol-Main MCU-pin-1"].tap()
        app.buttons["symbol-CAN-pin-1"].tap()
        let path = routePoints(app,3)
        XCTAssertGreaterThanOrEqual(path.count,4)
        guard path.count >= 4 else { return }
        let left = coordinates(app.buttons["symbol-CAN-pin-0"])
        XCTAssertEqual(path[1].x-path[0].x,CGFloat((left[0]-415)/2),accuracy:1)
        XCTAssertEqual(path[0].y,path[1].y)
        XCTAssertEqual(coordinates(element(app,"wire-3")),[415,250,left[0]+90,left[1]])
    }

    @MainActor
    func testJunctionsTrackSharedPinsAndSegmentDrags() {
        let app = XCUIApplication(); app.launch()
        let dots = element(app,"canvas-junctions")
        XCTAssertEqual(dots.value as? String,"301.0,250.0")
        XCTAssertEqual(element(app,"wire-0-hops").value as? String,"")
        let endpoint = coordinates(element(app,"wire-0"))
        let viewport = element(app,"circuit-canvas").value as? String
        let source = element(app,"wire-0-segment-1").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:-20,dy:0)))
        XCTAssertEqual(dots.value as? String,"301.0,250.0")
        XCTAssertEqual(coordinates(element(app,"wire-0")),endpoint)
        XCTAssertEqual(element(app,"circuit-canvas").value as? String,viewport)
        // Push the trunk towards the pin: it stops 12pt short of the block (x = 313) and wire 0's last leg now runs
        // alongside wire 2's, so the branch dot sits where wire 0 leaves that shared run.
        let trunk = element(app,"wire-0-segment-1").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        trunk.press(forDuration:0.2,thenDragTo:trunk.withOffset(CGVector(dx:44,dy:0)))
        XCTAssertEqual(dots.value as? String,"313.0,250.0")
        XCTAssertEqual(routePoints(app,0).count,4,"the trunk stays a draggable segment")
        let restore = element(app,"wire-0-segment-1").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        restore.press(forDuration:0.2,thenDragTo:restore.withOffset(CGVector(dx:-44,dy:0)))
        XCTAssertEqual(dots.value as? String,"301.0,250.0")
        app.buttons["配線"].tap()
        app.buttons["symbol-24 V → 5 V-pin-0"].tap()
        app.buttons["symbol-Main MCU-pin-0"].tap()
        let values = (dots.value as? String ?? "").split(separator:";")
        XCTAssertFalse(values.isEmpty)
        XCTAssertEqual(Set(values).count,values.count)
        XCTAssertEqual(coordinates(element(app,"wire-3")),[75,160,325,250])
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
        // The trunk keeps 12pt clear of the block (x = 325), so it can always be dragged back out.
        XCTAssertEqual(after.count,4)
        XCTAssertEqual(after[1].x,313,accuracy:0.1)
        XCTAssertEqual(after[2].x,313,accuracy:0.1)
        XCTAssertEqual(coordinates(element(app,"wire-0")),[165,160,325,250])
    }

    // Start through viewport coordinates, independently of the tiny accessibility
    // target. Both sides of the short line must work when the background gets input.
    /// One launch for the short-line / crossing scenarios that used to be six tests.
    /// After the initial nudge of wire 0 (which makes wire 2's short horizontal line cross it),
    /// every variant moves wire 2's short line up by 150pt and puts it back, so the next variant
    /// starts from the same state:
    ///  - touches on the visible line through viewport coordinates (both sides, and diagonal),
    ///  - touches on the accessibility target (straight and diagonal),
    ///  - finally the crossing arc appears and disappears without changing endpoints.
    @MainActor
    func testShortHorizontalLineDragsAndCrossings() {
        let app = XCUIApplication(); app.launch()
        func drag(_ id: String, _ dx: CGFloat, _ dy: CGFloat) {
            let target = element(app,id)
            XCTAssertTrue(target.isHittable, id)
            let source = target.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:dx,dy:dy)))
        }
        drag("wire-0-segment-1",-10,0)
        XCTAssertEqual(routePoints(app,0)[1].x,291,accuracy:1)
        let canvas = element(app,"circuit-canvas")
        let viewport = canvas.value as? String
        let before = routePoints(app,2)
        let endpoints = coordinates(element(app,"wire-2"))
        let symbols = ["24 V → 5 V","Main MCU","CAN","Temperature"].map { element(app,"symbol-\($0)").value as? String }
        let origin = canvas.coordinate(withNormalizedOffset:.zero)

        func assertMoved(_ after: [CGPoint], xAccuracy: CGFloat) {
            XCTAssertEqual(after.count,before.count)
            for i in before.indices {
                XCTAssertEqual(after[i].x,before[i].x,accuracy:xAccuracy)
                XCTAssertEqual(after[i].y,before[i].y - ([2,3].contains(i) ? 150 : 0),accuracy:1)
            }
            XCTAssertEqual(coordinates(element(app,"wire-0-hops")),[291,205])
        }
        func assertRestored(_ restored: [CGPoint]) {
            XCTAssertEqual(restored.count,before.count)
            for i in before.indices {
                XCTAssertEqual(restored[i].x,before[i].x,accuracy:0.1)
                XCTAssertEqual(restored[i].y,before[i].y,accuracy:1)
            }
            XCTAssertEqual(element(app,"wire-0-hops").value as? String,"")
            XCTAssertEqual(canvas.value as? String,viewport)
            XCTAssertEqual(coordinates(element(app,"wire-2")),endpoints)
        }

        // Viewport touches: -1 / +1 of the line's midpoint (must not pan), and a diagonal one.
        for (touchOffset, diagonal) in [(CGFloat(-1),CGFloat(0)),(1,0),(0,18)] {
            let source = origin.withOffset(CGVector(dx:(before[2].x+before[3].x)/2+touchOffset,dy:before[2].y))
            source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:diagonal,dy:-150)))
            assertMoved(routePoints(app,2),xAccuracy:1)
            XCTAssertEqual(canvas.value as? String,viewport)
            let after = routePoints(app,2)
            let back = origin.withOffset(CGVector(dx:(after[2].x+after[3].x)/2,dy:after[2].y))
            back.press(forDuration:0.2,thenDragTo:back.withOffset(CGVector(dx:-diagonal,dy:150)))
            XCTAssertEqual(routePoints(app,2),before)
            assertRestored(routePoints(app,2))
        }

        // Accessibility target: straight (must not select the adjacent vertical line) and diagonal.
        for diagonal in [CGFloat(0),18] {
            drag("wire-2-segment-2",diagonal,-150)
            assertMoved(routePoints(app,2),xAccuracy:0.1)
            XCTAssertEqual(coordinates(element(app,"wire-2")),endpoints)
            XCTAssertEqual(canvas.value as? String,viewport)
            drag("wire-2-segment-2",-diagonal,150)
            assertRestored(routePoints(app,2))
        }
        XCTAssertEqual(["24 V → 5 V","Main MCU","CAN","Temperature"].map { element(app,"symbol-\($0)").value as? String },symbols)

        // The crossing arc appears with the move and disappears when the other wire moves away.
        let wire0Endpoints = coordinates(element(app,"wire-0"))
        drag("wire-2-segment-2",0,-150)
        XCTAssertEqual(routePoints(app,2)[2].y,205,accuracy:1)
        let hops = element(app,"wire-0-hops")
        XCTAssertFalse((hops.value as? String ?? "").isEmpty)
        XCTAssertEqual(coordinates(element(app,"wire-0")),wire0Endpoints)
        XCTAssertFalse(element(app,"wire-3").exists)
        drag("wire-0-segment-1",-30,0)
        XCTAssertEqual(hops.value as? String,"")
        XCTAssertEqual(coordinates(element(app,"wire-0")),wire0Endpoints)
        assertWireCount(app,"3")
    }

    @MainActor
    func testBlankCanvasDragCrossingLineRemainsPan() {
        let app = XCUIApplication(); app.launch()
        let before = routePoints(app,2)
        let canvas = element(app,"circuit-canvas")
        let source = canvas.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:291,dy:473))
        // One-finger drag on blank canvas only pans while the dedicated pan tool is active (5B, 2026-09-29
        // feedback) - the underlying concern this test guards, that a drag starting on blank space but
        // visually crossing a wire's path must not grab that wire, is unchanged and still checked below.
        app.buttons["pan-mode-toggle"].tap()
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:0,dy:-97)))
        XCTAssertEqual(routePoints(app,2),before)
        XCTAssertEqual(canvas.value as? String,"scale=100, offsetX=0, offsetY=-97")
    }

    @MainActor
    func testTwoFingerPanRecognizerAttachesToTheWindow() throws {
        // XCUITest has no public API to synthesize a genuine two-finger pan (only tap and pinch have
        // dedicated methods), so this is the one part of the fix for the Codex major (5B round 1: the
        // recognizer's minimumNumberOfTouches=2 could never be satisfied, because it was attached to a
        // sibling overlay that never received the first of two fingers) a UI test can actually confirm:
        // that the recognizer attached to a window at all, not left silently failing the same way again.
        // The behaviour itself (does a real two-finger drag pan the canvas) needs manual/simulator-tool
        // verification instead - see this task's doc for how that was recorded.
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(element(app,"two-finger-pan-attached").waitForExistence(timeout:3))
        XCTAssertEqual(element(app,"two-finger-pan-attached").value as? String,"true")
    }

    @MainActor
    func testPanModeToggleEnablesThenDisablesOneFingerCanvasPanning() throws {
        let app = XCUIApplication(); app.launch()
        let canvas = element(app,"circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout:3))
        app.buttons["pan-mode-toggle"].tap()
        let source = canvas.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:150))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:-60,dy:40)))
        XCTAssertEqual(canvas.value as? String,"scale=100, offsetX=-60, offsetY=40")

        // Switching to another tool leaves pan mode; one-finger drags stop panning again.
        app.buttons["選択"].tap()
        let before = canvas.value as? String
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:-40,dy:20)))
        XCTAssertEqual(canvas.value as? String,before,"leaving pan mode must stop one-finger panning")
    }

    @MainActor
    func testOneFingerDragOnBlankCanvasDoesNothingOutsidePanMode() {
        let app = XCUIApplication(); app.launch()
        let canvas = element(app,"circuit-canvas")
        let before = canvas.value as? String
        let source = canvas.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:150))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:-80,dy:60)))
        XCTAssertEqual(canvas.value as? String,before,"a one-finger drag must not pan unless the pan tool is active")
    }

    @MainActor
    private func place(_ app: XCUIApplication, category: String, name: String, x: CGFloat, y: CGFloat) {
        app.buttons["library-category-\(category)"].tap()
        let item = app.buttons["library-\(name)"]
        if !item.isHittable { item.swipeLeft() }
        item.tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero)
            .withOffset(CGVector(dx:x,dy:y)).tap()
        XCTAssertTrue(element(app,"symbol-\(name)").exists, "placing \(name) at \(x),\(y)")
    }

    /// Pin offsets of the multi-terminal symbols at rotation 0 (centre origin, y down), by kind name.
    private let multiTerminalPins: [String: [(CGFloat,CGFloat)]] = [
        "NPNトランジスタ": [(-30,0),(15,-30),(15,30)], "PNPトランジスタ": [(-30,0),(15,-30),(15,30)],
        "NチャネルMOSFET": [(-30,0),(15,-30),(15,30)], "PチャネルMOSFET": [(-30,0),(15,-30),(15,30)],
        "オペアンプ": [(-30,-15),(-30,15),(30,0)],
        "ANDゲート": [(-30,-15),(-30,15),(30,0)], "ORゲート": [(-30,-15),(-30,15),(30,0)],
        "NANDゲート": [(-30,-15),(-30,15),(30,0)], "NORゲート": [(-30,-15),(-30,15),(30,0)],
        "XORゲート": [(-30,-15),(-30,15),(30,0)], "NOTゲート": [(-30,0),(30,0)],
        "リレー": [(-15,-30),(-15,30),(15,-30),(15,30)],
        "コネクタ": [(-30,-45),(-30,-15),(-30,15),(-30,45)]
    ]

    /// Two launches in total (circuit symbols, then blocks) instead of one per symbol.
    /// Symbols go on a grid below the initial diagram so none overlaps another's pins:
    /// vertical power symbols on one row, everything else on horizontal rows of nine.
    @MainActor
    func testCircuitCataloguePlacementKindsAndTerminals() {
        let groups: [(String,[String])] = [
            ("電源",["直流電源","電池","交流電源","VCC","GND"]),
            ("受動部品",["抵抗","可変抵抗","コンデンサ","電解コンデンサ","コイル"]),
            ("半導体",["ダイオード","LED","ツェナーダイオード","フォトダイオード",
                    "NPNトランジスタ","PNPトランジスタ","NチャネルMOSFET","PチャネルMOSFET","オペアンプ"]),
            ("ロジック",["ANDゲート","ORゲート","NANDゲート","NORゲート","XORゲート","NOTゲート"]),
            ("スイッチ・保護",["スイッチ","押しボタン","ヒューズ"]),
            ("負荷・その他",["ランプ","モーター","スピーカー","水晶振動子","電圧計","電流計"]),
            ("リレー・コネクタ",["リレー","コネクタ"])
        ]
        let app = XCUIApplication(); app.launch()
        var placed: [(category: String, name: String, x: CGFloat, y: CGFloat)] = []
        var horizontalCount = 0
        for (category,names) in groups {
            for name in names {
                let x: CGFloat, y: CGFloat
                if category == "電源" {
                    x = 75 + 110 * CGFloat(names.firstIndex(of:name)!); y = 560
                } else {
                    x = 60 + 85 * CGFloat(horizontalCount % 9); y = 660 + 80 * CGFloat(horizontalCount / 9)
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
            let rotation = name == "VCC" ? 270 : item.category == "電源" ? 90 : 0
            XCTAssertEqual(element(app,"symbol-\(name)-rotation").value as? String,"\(rotation)", name)
            let x = Double(item.x), y = Double(item.y)
            let offsets: [(Double,Double)]
            if let table = multiTerminalPins[name] {
                offsets = table.map { (Double($0.0),Double($0.1)) }
            } else if name == "GND" || name == "VCC" {
                offsets = [rotation == 90 ? (0,-30) : (0,30)]
            } else {
                offsets = rotation == 90 ? [(0,-30),(0,30)] : [(-30,0),(30,0)]
            }
            for (index,offset) in offsets.enumerated() {
                XCTAssertEqual(coordinates(app.buttons["symbol-\(name)-pin-\(index)"].firstMatch),
                               [x+offset.0,y+offset.1], "\(name) pin \(index)")
            }
            XCTAssertFalse(app.buttons["symbol-\(name)-pin-\(offsets.count)"].firstMatch.exists, name)
        }
        app.terminate()

        // Blocks (3B): only one kind in the library now ("汎用ブロック"); name and icon are chosen afterwards.
        let blockApp = XCUIApplication(); blockApp.launch()
        blockApp.buttons["library-category-ブロック"].tap()
        XCTAssertTrue(blockApp.buttons["library-汎用ブロック"].exists)
        XCTAssertFalse(blockApp.buttons["library-DC/DC"].exists)
        XCTAssertFalse(blockApp.buttons["library-MCU"].exists)
        XCTAssertFalse(blockApp.buttons["library-CAN"].exists)
        XCTAssertFalse(blockApp.buttons["library-センサー"].exists)
        place(blockApp,category:"ブロック",name:"汎用ブロック",x:400,y:560)
        let placedSymbol = blockApp.descendants(matching:.any).matching(identifier:"symbol-汎用ブロック").firstMatch
        XCTAssertTrue((placedSymbol.value as? String ?? "").contains("kind=汎用ブロック"))
        XCTAssertTrue((placedSymbol.value as? String ?? "").contains("style=block"))
        XCTAssertEqual(element(blockApp,"symbol-汎用ブロック-icon").value as? String,"square.dashed")
        XCTAssertTrue(blockApp.buttons["symbol-汎用ブロック-pin-0"].firstMatch.exists)
        XCTAssertTrue(blockApp.buttons["symbol-汎用ブロック-pin-1"].firstMatch.exists)
        XCTAssertEqual(coordinates(blockApp.buttons["symbol-汎用ブロック-pin-0"]),[355,560])
        XCTAssertEqual(coordinates(blockApp.buttons["symbol-汎用ブロック-pin-1"]),[445,560])
        blockApp.terminate()
    }

    /// 3B: renaming a block and changing its icon from the inspector (the library only offers the generic block
    /// now; everything else is chosen afterwards). Also checks the four initial blocks kept their original icon.
    /// 3C: "+" appears only on empty (side, row) slots for the selected block, adds a pin there, and that pin
    /// wires, follows a move/resize, and rotation of a pin's side survives a resize whose height changes.
    @MainActor
    func testBlockPinAdditionAppearsOnEmptySlotsAndTheNewPinWorks() throws {
        let app = XCUIApplication(); app.launch()
        place(app,category:"ブロック",name:"汎用ブロック",x:400,y:550)
        // Not selected: no "+" anywhere.
        XCTAssertFalse(element(app,"symbol-汎用ブロック-add-pin-left-0").exists)
        element(app,"symbol-汎用ブロック").tap()
        // Height 30 (1 row): the top row already has both pins, so no "+" is offered at all.
        XCTAssertFalse(element(app,"symbol-汎用ブロック-add-pin-left-0").waitForExistence(timeout:1))
        XCTAssertFalse(element(app,"symbol-汎用ブロック-add-pin-right-0").exists)

        func drag(_ corner: String, _ dx: CGFloat, _ dy: CGFloat) {
            if !element(app,"symbol-汎用ブロック-resize-\(corner)").waitForExistence(timeout:1) { element(app,"symbol-汎用ブロック").tap() }
            let handle = element(app,"symbol-汎用ブロック-resize-\(corner)")
            let start = handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            start.press(forDuration:0.2,thenDragTo:start.withOffset(CGVector(dx:dx,dy:dy)))
        }

        // Grow to 3 rows (height 90): rows 1 and 2 are empty, so 4 "+" targets appear (left/right x 2 rows).
        drag("br",0,60)
        XCTAssertEqual((element(app,"symbol-汎用ブロック-size").value as? String ?? ""),"90,90")
        for side in ["left","right"] { for row in [1,2] {
            XCTAssertTrue(element(app,"symbol-汎用ブロック-add-pin-\(side)-\(row)").waitForExistence(timeout:2), "\(side) row \(row)")
        } }
        // The top row still has no "+" (already has pin-0 / pin-1).
        XCTAssertFalse(element(app,"symbol-汎用ブロック-add-pin-left-0").exists)

        // Add the left-row-1 pin: it becomes pin-2, at the left edge, one row (30pt) below the top pins.
        element(app,"symbol-汎用ブロック-add-pin-left-1").tap()
        XCTAssertTrue(app.buttons["symbol-汎用ブロック-pin-2"].waitForExistence(timeout:2))
        let top = coordinates(app.buttons["symbol-汎用ブロック-pin-0"])
        XCTAssertEqual(coordinates(app.buttons["symbol-汎用ブロック-pin-2"]),[top[0],top[1]+30])
        XCTAssertFalse(element(app,"symbol-汎用ブロック-add-pin-left-1").exists,"that slot must not offer + again")

        // N4: growing further keeps every existing pin's coordinates, and the new row gets its own "+".
        drag("br",0,30)
        XCTAssertEqual((element(app,"symbol-汎用ブロック-size").value as? String ?? ""),"90,120")
        XCTAssertEqual(coordinates(app.buttons["symbol-汎用ブロック-pin-0"]),top)
        XCTAssertEqual(coordinates(app.buttons["symbol-汎用ブロック-pin-2"]),[top[0],top[1]+30])
        XCTAssertTrue(element(app,"symbol-汎用ブロック-add-pin-left-3").waitForExistence(timeout:2))
        XCTAssertTrue(element(app,"symbol-汎用ブロック-add-pin-right-3").exists)

        // N5: filling every remaining slot (row 2 both sides, row 3 both sides - row 1 left is already pin-2)
        // leaves no "+" anywhere on the block.
        for id in ["symbol-汎用ブロック-add-pin-right-1","symbol-汎用ブロック-add-pin-left-2","symbol-汎用ブロック-add-pin-right-2",
                   "symbol-汎用ブロック-add-pin-left-3","symbol-汎用ブロック-add-pin-right-3"] {
            let button = element(app,id)
            XCTAssertTrue(button.waitForExistence(timeout:2), id)
            button.tap()
        }
        for side in ["left","right"] { for row in 0...3 {
            XCTAssertFalse(element(app,"symbol-汎用ブロック-add-pin-\(side)-\(row)").exists, "\(side) row \(row) should be filled")
        } }
        XCTAssertTrue(app.buttons["symbol-汎用ブロック-pin-7"].exists,"8 pins total (2 per row x 4 rows)")

        // The new pin (pin-2) wires like any other.
        app.buttons["配線"].tap()
        app.buttons["symbol-汎用ブロック-pin-2"].tap()
        app.buttons["symbol-Temperature-pin-1"].tap()
        XCTAssertTrue(element(app,"wire-3").waitForExistence(timeout:2))
        assertRoutesClear(app,count:4,extraSymbols:["汎用ブロック"])

        // Moving the block carries the new pin (and its wire) along.
        app.buttons["選択"].tap()
        let move = element(app,"symbol-汎用ブロック").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        move.press(forDuration:0.2,thenDragTo:move.withOffset(CGVector(dx:40,dy:-30)))
        XCTAssertEqual(Array(coordinates(element(app,"wire-3")).prefix(2)),coordinates(app.buttons["symbol-汎用ブロック-pin-2"]))
        assertRoutesClear(app,count:4,extraSymbols:["汎用ブロック"])

        // Shrinking is capped at the deepest added pin's row (pin-7, row 3): height cannot go below 120, even
        // dragging far past it - the size, every pin's edge position, and the wire's route must all reflect that.
        // (Selecting the wire tool earlier cleared the selection, so the resize handles need reselecting first.)
        element(app,"symbol-汎用ブロック").tap()
        drag("br",0,-900)
        XCTAssertEqual((element(app,"symbol-汎用ブロック-size").value as? String ?? ""),"90,120","must not shrink below the deepest added pin's row")
        // Left/right pins sit exactly on the body's edges; row 0's are the reference point for every other row.
        let leftX = coordinates(app.buttons["symbol-汎用ブロック-pin-0"])[0]
        let rightX = coordinates(app.buttons["symbol-汎用ブロック-pin-1"])[0]
        let topY = coordinates(app.buttons["symbol-汎用ブロック-pin-0"])[1]
        XCTAssertEqual(rightX-leftX,90,"width unaffected by a height-only drag")
        for row in 0...3 {
            XCTAssertEqual(coordinates(app.buttons["symbol-汎用ブロック-pin-\(row*2)"]),[leftX,topY+CGFloat(row)*30],"row \(row) left")
            XCTAssertEqual(coordinates(app.buttons["symbol-汎用ブロック-pin-\(row*2+1)"]),[rightX,topY+CGFloat(row)*30],"row \(row) right")
        }
        XCTAssertEqual(Array(coordinates(element(app,"wire-3")).prefix(2)),coordinates(app.buttons["symbol-汎用ブロック-pin-2"]))
        assertRoutesClear(app,count:4,extraSymbols:["汎用ブロック"])

        // "元の大きさに戻す" (reset) is the other path to a smaller size: it must respect the same minimum, not just
        // the drag path already checked above.
        app.buttons["確認"].tap()
        app.buttons["元の大きさに戻す"].tap()
        app.navigationBars["インスペクタ"].swipeDown()
        XCTAssertEqual((element(app,"symbol-汎用ブロック-size").value as? String ?? ""),"90,120","reset must not shrink below the deepest added pin's row either")
        let resetLeftX = coordinates(app.buttons["symbol-汎用ブロック-pin-0"])[0]
        let resetTopY = coordinates(app.buttons["symbol-汎用ブロック-pin-0"])[1]
        for row in 0...3 {
            XCTAssertEqual(coordinates(app.buttons["symbol-汎用ブロック-pin-\(row*2)"]),[resetLeftX,resetTopY+CGFloat(row)*30],"reset row \(row) left")
        }
        XCTAssertEqual(Array(coordinates(element(app,"wire-3")).prefix(2)),coordinates(app.buttons["symbol-汎用ブロック-pin-2"]),"the wire must still follow pin-2 after the reset")
        assertRoutesClear(app,count:4,extraSymbols:["汎用ブロック"])

        // N6: deleting a block with an added, wired pin removes that wire too, like any other symbol deletion.
        app.buttons["確認"].tap()
        app.buttons["シンボルを削除"].tap()
        XCTAssertFalse(element(app,"symbol-汎用ブロック").exists)
        XCTAssertEqual(element(app,"wire-count").value as? String,"3")
    }

    @MainActor
    func testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector() throws {
        let app = XCUIApplication(); app.launch()
        // The initial diagram's blocks are all "汎用ブロック" underneath, but keep their original look.
        for (name, icon) in [("24 V → 5 V","bolt.fill"),("Main MCU","cpu"),("CAN","arrow.left.and.right"),("Temperature","sensor.tag.radiowaves.forward")] {
            XCTAssertEqual(element(app,"symbol-\(name)-icon").value as? String,icon,name)
        }
        place(app,category:"ブロック",name:"汎用ブロック",x:400,y:550)
        element(app,"symbol-汎用ブロック").tap()
        app.buttons["確認"].tap()
        let field = app.textFields["名称"]
        field.tap()
        field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:10) + "電源ユニット")
        XCTAssertTrue(app.buttons["inspector-icon-picker"].waitForExistence(timeout:2))
        app.buttons["inspector-icon-picker"].tap()
        XCTAssertTrue(app.staticTexts["アイコンを選択"].waitForExistence(timeout:2))
        XCTAssertTrue(app.buttons["icon-picker-square.dashed"].isSelected)
        app.buttons["icon-picker-bolt.batteryblock"].tap()
        // Selecting pops back to the symbol section automatically.
        XCTAssertTrue(app.buttons["inspector-icon-picker"].waitForExistence(timeout:2))
        app.navigationBars["インスペクタ"].swipeDown()
        XCTAssertTrue(element(app,"symbol-電源ユニット").waitForExistence(timeout:2))
        XCTAssertEqual(element(app,"symbol-電源ユニット-icon").value as? String,"bolt.batteryblock")
        // Reopen and confirm the picker highlights the current icon.
        element(app,"symbol-電源ユニット").tap()
        app.buttons["確認"].tap()
        app.buttons["inspector-icon-picker"].tap()
        XCTAssertTrue(app.buttons["icon-picker-bolt.batteryblock"].isSelected)
        XCTAssertFalse(app.buttons["icon-picker-square.dashed"].isSelected)
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
            XCTAssertEqual(abs(first[0]-second[0])+abs(first[1]-second[1]),60,accuracy:1)
            XCTAssertEqual(coordinates(element(app,"wire-3")),[415,250]+first)
            assertRoutesClear(app,count:4,extraSymbols:["抵抗"])
        }
        XCTAssertEqual(element(app,"circuit-canvas").value as? String,viewport)
        // The rotate action lives only on the canvas now, not in the inspector; the inspector just shows state.
        app.buttons["確認"].tap()
        XCTAssertFalse(app.buttons["inspector-rotate"].exists)
        XCTAssertEqual(element(app,"symbol-connection-status").value as? String,"接続あり")
        app.navigationBars["インスペクタ"].swipeDown()
        for rotation in [90,180,270,0] {
            app.buttons["symbol-抵抗-rotate"].tap()
            XCTAssertEqual(element(app,"symbol-抵抗-rotation").value as? String,"\(rotation)")
        }
        app.buttons["確認"].tap()
        XCTAssertEqual(element(app,"symbol-connection-status").value as? String,"接続あり")
        app.navigationBars["インスペクタ"].swipeDown()
        element(app,"symbol-抵抗").tap()
        if !app.buttons["symbol-抵抗-rotate"].waitForExistence(timeout:1) { element(app,"symbol-抵抗").tap() }
        app.buttons["確認"].tap()
        app.buttons["シンボルを削除"].tap()
        XCTAssertFalse(element(app,"symbol-抵抗").exists)
        XCTAssertEqual(element(app,"wire-count").value as? String,"3")
    }

    /// Multi-terminal wiring in one launch (Codex review): a 4-pin connector wired to a 3-pin transistor.
    /// Covers adjacent 30pt pins, self-connection rejection for any pin pair, separate wires from every
    /// pin, all ends following through a full turn of rotation, orthogonal routes clear of both bodies,
    /// and a one-pitch drag (30pt) that must not send a wire to another pin.
    @MainActor
    func testMultiTerminalWiringAdjacentPinsRotationAndMove() {
        let app = XCUIApplication(); app.launch()
        let connector = CGPoint(x:200,y:700), transistor = CGPoint(x:520,y:700)
        place(app,category:"リレー・コネクタ",name:"コネクタ",x:connector.x,y:connector.y)
        place(app,category:"半導体",name:"NPNトランジスタ",x:transistor.x,y:transistor.y)
        func pin(_ name: String, _ index: Int) -> XCUIElement { app.buttons["symbol-\(name)-pin-\(index)"] }

        // Adjacent pins 30pt apart: only the tapped one is selected.
        app.buttons["配線"].tap()
        pin("コネクタ",1).tap()
        XCTAssertTrue(pin("コネクタ",1).isSelected)
        XCTAssertFalse(pin("コネクタ",0).isSelected || pin("コネクタ",2).isSelected || pin("コネクタ",3).isSelected)
        // Any two pins of one symbol are rejected (all 12 ordered pairs): the start stays selected, no wire appears.
        for start in 0..<4 {
            app.buttons["配線"].tap()
            pin("コネクタ",start).tap()
            XCTAssertTrue(pin("コネクタ",start).isSelected, "P\(start+1) selected")
            for other in 0..<4 where other != start {
                pin("コネクタ",other).tap()
                XCTAssertTrue(pin("コネクタ",start).isSelected, "start P\(start+1) must stay selected after P\(other+1)")
                XCTAssertFalse(pin("コネクタ",other).isSelected)
                XCTAssertFalse(element(app,"wire-3").exists)
            }
        }
        // A separate wire from each of P1...P3 to the transistor's B, C, E (P4 stays free).
        for index in 0..<3 {
            app.buttons["配線"].tap()
            pin("コネクタ",index).tap()
            pin("NPNトランジスタ",index).tap()
            XCTAssertTrue(element(app,"wire-\(3+index)").waitForExistence(timeout:2), "wire \(index)")
        }
        XCTAssertFalse(element(app,"wire-6").exists)

        func rotate(_ point: (Double,Double), _ rotation: Int) -> (Double,Double) {
            switch rotation { case 90: (-point.1,point.0); case 180: (-point.0,-point.1); case 270: (point.1,-point.0); default: point }
        }
        let offsets: [(Double,Double)] = [(-30,-45),(-30,-15),(-30,15),(-30,45)]
        func assertConnectorState(_ rotation: Int, center: CGPoint, _ label: String) {
            XCTAssertEqual(element(app,"symbol-コネクタ-rotation").value as? String,"\(rotation)",label)
            for (index,offset) in offsets.enumerated() {
                let turned = rotate(offset,rotation)
                XCTAssertEqual(coordinates(pin("コネクタ",index)),[Double(center.x)+turned.0,Double(center.y)+turned.1],"\(label) P\(index+1)")
            }
            let frame = rotation % 180 == 0 ? CGSize(width:60,height:120) : CGSize(width:120,height:60)
            let bodies = [CGRect(x:center.x-frame.width/2,y:center.y-frame.height/2,width:frame.width,height:frame.height),
                          CGRect(x:transistor.x-30,y:transistor.y-30,width:60,height:60)]
            for index in 0..<3 {
                // Each wire still joins its own two pins, orthogonally, outside both bodies.
                XCTAssertEqual(coordinates(element(app,"wire-\(3+index)")),
                               coordinates(pin("コネクタ",index)) + coordinates(pin("NPNトランジスタ",index)),"\(label) wire \(index)")
                let points = routePoints(app,3+index)
                XCTAssertGreaterThanOrEqual(points.count,2,"\(label) wire \(index)")
                for (a,b) in zip(points,points.dropFirst()) {
                    XCTAssertTrue(a.x == b.x || a.y == b.y)
                    for body in bodies {
                        let inside = a.y == b.y
                            ? a.y > body.minY && a.y < body.maxY && max(a.x,b.x) > body.minX && min(a.x,b.x) < body.maxX
                            : a.x > body.minX && a.x < body.maxX && max(a.y,b.y) > body.minY && min(a.y,b.y) < body.maxY
                        XCTAssertFalse(inside,"\(label) wire \(index) crosses \(body)")
                    }
                }
            }
        }
        assertConnectorState(0,center:connector,"initial")

        // A full turn: every end follows its pin.
        element(app,"symbol-コネクタ").tap()
        for rotation in [90,180,270,0] {
            app.buttons["symbol-コネクタ-rotate"].tap()
            assertConnectorState(rotation,center:connector,"rotation \(rotation)")
        }

        // Drag by about one pin pitch: P1's wire must stay on P1, not slide on to P2...P4.
        let symbol = element(app,"symbol-コネクタ").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        let before = (0..<4).map { coordinates(pin("コネクタ",$0)) }
        symbol.press(forDuration:0.2,thenDragTo:symbol.withOffset(CGVector(dx:0,dy:30)))
        let after = (0..<4).map { coordinates(pin("コネクタ",$0)) }
        let shift = after[0][1]-before[0][1]
        XCTAssertGreaterThan(shift,20)
        for index in 0..<4 {
            XCTAssertEqual(after[index],[before[index][0],before[index][1]+shift],"P\(index+1) moved with the symbol")
        }
        for index in 0..<3 {
            XCTAssertEqual(coordinates(element(app,"wire-\(3+index)")),after[index] + coordinates(pin("NPNトランジスタ",index)),"wire \(index) after drag")
        }
    }

    /// Block resizing (2A) in one launch: handles, corner-anchored drags with 30pt snapping and limits,
    /// pins in the first row slot, attached wires following, circuit symbols without handles, and the reset.
    @MainActor
    func testBlockResizeHandlesSnappingLimitsWiresAndReset() {
        let app = XCUIApplication(); app.launch()
        func size(_ name: String) -> [Double] { coordinates(element(app,"symbol-\(name)-size")) }
        func drag(_ corner: String, _ dx: CGFloat, _ dy: CGFloat) {
            let handle = element(app,"symbol-Main MCU-resize-\(corner)")
            XCTAssertTrue(handle.waitForExistence(timeout:2), corner)
            let start = handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            start.press(forDuration:0.2,thenDragTo:start.withOffset(CGVector(dx:dx,dy:dy)))
        }
        // Default size, no handles until the block is selected; a circuit symbol never shows handles.
        XCTAssertEqual(size("Main MCU"),[90,30])
        XCTAssertFalse(element(app,"symbol-Main MCU-resize-br").exists)
        element(app,"symbol-Main MCU").tap()
        if !element(app,"symbol-Main MCU-resize-tl").waitForExistence(timeout:1) { element(app,"symbol-Main MCU").tap() }   // a tap right after another can be dropped
        for corner in ["tl","tr","bl","br"] { XCTAssertTrue(element(app,"symbol-Main MCU-resize-\(corner)").waitForExistence(timeout:2), corner) }

        // Handles are finger-sized and their squares stay clear of the pins' squares.
        for corner in ["tl","tr","bl","br"] {
            let frame = element(app,"symbol-Main MCU-resize-\(corner)").frame
            XCTAssertGreaterThanOrEqual(frame.width,31.5,corner); XCTAssertGreaterThanOrEqual(frame.height,31.5,corner)
            for pin in 0...1 {
                XCTAssertFalse(frame.intersects(app.buttons["symbol-Main MCU-pin-\(pin)"].frame),"\(corner) handle overlaps pin \(pin)")
            }
        }
        // br: the top-left corner (325,235) stays; 150 x 90; both pins in the first row slot (y = 235 + 15).
        drag("br",60,60)
        XCTAssertEqual(size("Main MCU"),[150,90])
        XCTAssertEqual(coordinates(app.buttons["symbol-Main MCU-pin-0"]),[325,250])
        XCTAssertEqual(coordinates(app.buttons["symbol-Main MCU-pin-1"]),[475,250])
        // Attached wires follow (wire 0 ends on pin-0, wire 1 starts on pin-1) and still avoid every block.
        XCTAssertEqual(coordinates(element(app,"wire-0")).suffix(2),[325,250])
        XCTAssertEqual(coordinates(element(app,"wire-1")).prefix(2),[475,250])
        assertRoutesClear(app,count:3)

        // tl: the bottom-right corner (475,325) stays; 180 x 120 -> top-left (295,205).
        drag("tl",-30,-30)
        XCTAssertEqual(size("Main MCU"),[180,120])
        XCTAssertEqual(coordinates(app.buttons["symbol-Main MCU-pin-0"]),[295,220])
        XCTAssertEqual(coordinates(app.buttons["symbol-Main MCU-pin-1"]),[475,220])
        assertRoutesClear(app,count:3)

        // A drag too short to reach the next step changes nothing; a long one stops at the limits.
        drag("br",10,10)
        XCTAssertEqual(size("Main MCU"),[180,120])
        drag("br",900,900)
        XCTAssertEqual(size("Main MCU"),[300,180])
        drag("tl",900,900)
        XCTAssertEqual(size("Main MCU"),[90,30])
        for name in ["24 V → 5 V","CAN","Temperature"] { XCTAssertEqual(size(name),[90,30], name) }

        // Reset returns to 90 x 30 keeping the top-left corner.
        drag("br",90,60)
        XCTAssertEqual(size("Main MCU"),[180,90])
        let topLeft = coordinates(app.buttons["symbol-Main MCU-pin-0"])
        app.buttons["確認"].tap()
        app.buttons["inspector-reset-size"].tap()
        XCTAssertEqual(size("Main MCU"),[90,30])
        XCTAssertEqual(coordinates(app.buttons["symbol-Main MCU-pin-0"]),[topLeft[0],topLeft[1]+(-15)+15])
        XCTAssertEqual(coordinates(element(app,"wire-0")).suffix(2),coordinates(app.buttons["symbol-Main MCU-pin-0"]))
        app.navigationBars["インスペクタ"].swipeDown()

        // A circuit symbol shows no handles and has no size; selecting it hides the block's handles.
        place(app,category:"受動部品",name:"抵抗",x:200,y:700)
        element(app,"symbol-抵抗").tap()
        if !app.buttons["symbol-抵抗-rotate"].waitForExistence(timeout:1) { element(app,"symbol-抵抗").tap() }
        XCTAssertTrue(app.buttons["symbol-抵抗-rotate"].exists)
        XCTAssertFalse(element(app,"symbol-抵抗-resize-br").exists)
        XCTAssertFalse(element(app,"symbol-抵抗-size").exists)
        XCTAssertFalse(element(app,"symbol-Main MCU-resize-br").exists)

        // A hand-placed wire segment survives a drag that changes nothing and a resize that keeps its pin.
        // (Placed while the block is not selected: its corner handles would sit right over the trunk.)
        let automaticRoute = routePoints(app,0)
        let trunk = element(app,"wire-0-segment-1").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        trunk.press(forDuration:0.2,thenDragTo:trunk.withOffset(CGVector(dx:-20,dy:0)))
        let manualRoute = routePoints(app,0)
        XCTAssertEqual(manualRoute.count,4)
        XCTAssertNotEqual(manualRoute,automaticRoute,"the trunk must really have been moved by hand")
        XCTAssertEqual(manualRoute[1].x,automaticRoute[1].x-20,accuracy:1)
        element(app,"symbol-Main MCU").tap()
        if !element(app,"symbol-Main MCU-resize-br").waitForExistence(timeout:1) { element(app,"symbol-Main MCU").tap() }
        drag("br",10,10)
        XCTAssertEqual(size("Main MCU"),[90,30])
        XCTAssertEqual(routePoints(app,0),manualRoute,"a drag that changes nothing must leave the route alone")
        drag("br",60,60)
        XCTAssertEqual(size("Main MCU"),[150,90])
        XCTAssertEqual(routePoints(app,0),manualRoute,"the left pin did not move, so the hand-placed route stays")
        // A resize that moves the wire's own pin: the end follows it and the hand-placed trunk is kept.
        drag("tl",-30,0)
        XCTAssertEqual(size("Main MCU"),[180,90])
        let moved = routePoints(app,0)
        XCTAssertEqual(moved.last,CGPoint(x:coordinates(app.buttons["symbol-Main MCU-pin-0"])[0],y:coordinates(app.buttons["symbol-Main MCU-pin-0"])[1]))
        XCTAssertEqual(moved[1].x,manualRoute[1].x,"the hand-placed trunk stays where it was put")
    }

    /// Wire 2 starts with a 12pt step (x = 289 then 301). One drag of either side within 13pt of the other
    /// straightens it into a single segment; the route then still follows its moved end.
    @MainActor
    func testDraggingOneSideOfAStepStraightensTheWire() {
        let app = XCUIApplication(); app.launch()
        let before = routePoints(app,2)
        guard before.count == 6 else { return XCTFail("wire 2 should start with a step: \(before)") }
        XCTAssertEqual(before[1].x,289); XCTAssertEqual(before[3].x,301)
        XCTAssertTrue(element(app,"wire-2-segment-3").waitForExistence(timeout:2))
        let side = element(app,"wire-2-segment-3").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        side.press(forDuration:0.2,thenDragTo:side.withOffset(CGVector(dx:-10,dy:0)))
        let straight = routePoints(app,2)
        guard straight.count == 4 else { return XCTFail("the step must become one segment: \(straight)") }
        XCTAssertEqual(straight.first,before.first); XCTAssertEqual(straight.last,before.last)
        XCTAssertEqual(straight[1].x,289); XCTAssertEqual(straight[2].x,289)
        XCTAssertEqual(straight[1].y,390); XCTAssertEqual(straight[2].y,250)
        // No separate upper / lower pieces are left to grab.
        XCTAssertFalse(element(app,"wire-2-segment-3").exists)
        XCTAssertTrue(element(app,"wire-2-segment-1").exists)
        // Moving the block at the start of the wire keeps the hand-straightened route attached and orthogonal.
        let temperature = element(app,"symbol-Temperature").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        temperature.press(forDuration:0.2,thenDragTo:temperature.withOffset(CGVector(dx:0,dy:40)))
        let moved = routePoints(app,2)
        XCTAssertEqual(coordinates(element(app,"wire-2")).prefix(2),coordinates(app.buttons["symbol-Temperature-pin-1"]).prefix(2))
        guard let first = moved.first else { return XCTFail("wire 2 has no route") }
        XCTAssertEqual([first.x,first.y],coordinates(app.buttons["symbol-Temperature-pin-1"]))
        for (a,b) in zip(moved,moved.dropFirst()) { XCTAssertTrue(a.x == b.x || a.y == b.y) }
        assertRoutesClear(app,count:3)
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
        XCTAssertTrue(junctions.contains { $0.count == 2 && $0[0] == 300 && $0[1] > 560 })
        element(app,"symbol-直流電源").tap()
        app.buttons["symbol-直流電源-rotate"].tap()
        XCTAssertEqual(element(app,"symbol-直流電源-rotation").value as? String,"180")
        XCTAssertEqual(coordinates(app.buttons["symbol-直流電源-pin-0"]),[330,530])
        assertRoutesClear(app,count:5,extraSymbols:["直流電源","GND"])
        let source = element(app,"symbol-直流電源").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        source.press(forDuration:0.2,thenDragTo:source.withOffset(CGVector(dx:20,dy:-20)))
        XCTAssertEqual(coordinates(element(app,"wire-3")).prefix(2).map { $0 },coordinates(app.buttons["symbol-直流電源-pin-1"]))
        assertRoutesClear(app,count:5,extraSymbols:["直流電源","GND"])
    }
}
