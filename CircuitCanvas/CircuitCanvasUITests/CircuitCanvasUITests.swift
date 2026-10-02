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

    /// Every test launches through this, with grid snapping (5F) forced off unless the test opts back in:
    /// the tests written before 5F place and drag by exact, deliberately off-grid amounts and assert those
    /// exact coordinates, and `gridSnapEnabled` is otherwise a persisted, default-on preference.
    /// A real launch starts blank and centered (2026-09-29), so the sample circuit these tests were written
    /// against is drawn first (UITEST_SEED_SAMPLE), at the old top-left view; the first-launch tour (3D)
    /// stays out of the way unless a test is about it (see makeOnboardingApp).
    private func makeApp(gridSnap: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_GRID_SNAP"] = gridSnap ? "1" : "0"
        app.launchEnvironment["UITEST_SEED_SAMPLE"] = "1"
        app.launchEnvironment["UITEST_ONBOARDING"] = "off"
        return app
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExperimentNoteCanBeDragged() throws {
        let app = makeApp()
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
        let app = makeApp(); app.launch()
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
        note.tap(); app.buttons["確認"].tap()
        liveEdit(app,trigger:"inspector-note-title",multiline:false,clear:20,type:"とても長いタイトルを二行に折り返して確認する")
        liveEdit(app,trigger:"note-body-editor",multiline:true,clear:40,type:"本文も長くして、最小サイズでどこまで読めるかを確認するための、長い説明文にする。")
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        // A one-finger drag only pans while the dedicated pan tool is active (5B, 2026-09-29 feedback - added
        // after this test was first written); this full-regression run is what caught it never having been
        // updated for that, so it silently panned nothing at all and failed every one of its own assertions.
        app.buttons["pan-mode-toggle"].tap()
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
        let app = makeApp(); app.launch()
        let canvas = element(app,"circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout:3))
        func exactScale() -> Double { Double(element(app,"zoom-scale-exact").value as? String ?? "") ?? .nan }
        canvas.pinch(withScale:0.73,velocity:-1)
        // The pinch is a UIKit recognizer since the 2026-10-03 sensitivity fix, which XCUITest's synthesized
        // pinch does drive (SwiftUI's MagnificationGesture, before it, often did not - this used to skip).
        // So landing on a non-preset scale is now required, not skipped.
        let presets: [Double] = [0.25,0.5,1,1.5,2]
        XCTAssertTrue(presets.allSatisfy({ abs(exactScale() - $0) > 0.001 }), "the pinch must leave a non-preset scale, got \(exactScale())")
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
        let app = makeApp()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        liveEdit(app,trigger:"inspector-symbol-title",multiline:false,clear:20,type:"A")
        // An independent confirm action (here, resetting the size) in between two renames.
        XCTAssertTrue(app.buttons["inspector-reset-size"].waitForExistence(timeout:2))
        app.buttons["inspector-reset-size"].tap()
        liveEdit(app,trigger:"inspector-symbol-title",multiline:false,clear:5,type:"B")
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        note.tap()
        app.buttons["確認"].tap()
        app.buttons["note-body-editor"].tap()
        let body = app.textViews["live-edit-field"]
        XCTAssertTrue(body.waitForExistence(timeout:2))
        // A single tap on this floating (position-placed) TextEditor does not reliably grant it keyboard
        // focus in this harness - a second tap does (5D; same underlying quirk noted elsewhere in this file
        // for TextEditor taps).
        body.tap(); body.tap()
        // Return must insert a newline (not end editing) - a TextField(axis: .vertical) could not do this.
        // Not asserting exact placement relative to the pre-existing text: where a plain tap lands the cursor
        // in a multi-line field is layout/device-sensitive, and is not what this is testing.
        body.typeText("1行目\n2行目")
        let value = body.value as? String ?? ""
        XCTAssertTrue(value.contains("1行目\n2行目"),"the newline must be preserved as typed, not end editing: \(value)")
        XCTAssertTrue(value.contains("10 kΩへ変更して波形を再測定"),"the original content must still be there: \(value)")
        app.buttons["live-edit-done"].tap()

        // The typed newline must actually be saved to the model, not just shown live in the field - reopening
        // live-edit for the same body must show it again, and it must also have survived a full sheet close.
        app.navigationBars["インスペクタ"].swipeDown()
        note.tap()
        app.buttons["確認"].tap()
        app.buttons["note-body-editor"].tap()
        let reopened = (app.textViews["live-edit-field"].value as? String ?? "")
        XCTAssertTrue(reopened.contains("1行目\n2行目"),"the newline must have been saved: \(reopened)")
    }

    @MainActor
    func testNoteInspectorIsRenamedHasAMemoTypeAndAnIconPicker() throws {
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp()
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
        let app = makeApp(); app.launch()
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

        // Editing its content live on the canvas (5D), triggered from the inspector like a note's body.
        text.tap()
        app.buttons["確認"].tap()
        XCTAssertTrue(app.staticTexts["テキスト"].waitForExistence(timeout:2))
        app.buttons["text-body-editor"].tap()
        let editor = app.textViews["live-edit-field"]
        XCTAssertTrue(editor.waitForExistence(timeout:2))
        editor.tap(); editor.tap()
        // Not asserting where in "テキスト" this lands (append/prepend/middle) - a plain tap's cursor position
        // in a multi-line field is layout/device-sensitive (same caveat as the note body tests elsewhere in
        // this file). A CONTAINS match on the card's own identifier (built from its body) sidesteps that.
        editor.typeText(" 編集済み")
        app.buttons["live-edit-done"].tap()
        app.navigationBars["インスペクタ"].swipeDown()
        let edited = app.descendants(matching: .any).matching(NSPredicate(format:"identifier CONTAINS %@","編集済み")).firstMatch
        XCTAssertTrue(edited.waitForExistence(timeout:2))
    }

    @MainActor
    func testEditModeDeletesATextItemWithConfirmation() throws {
        let app = makeApp(); app.launch()
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
    func testPlacingATextItemClearsAPreviouslySelectedSymbol() throws {
        let app = makeApp(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        element(app,"symbol-24 V → 5 V").tap()
        app.buttons["確認"].tap()
        XCTAssertTrue(app.staticTexts["シンボル"].waitForExistence(timeout:2))
        app.navigationBars["インスペクタ"].swipeDown()

        app.buttons["library-category-テキスト"].tap()
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:500)).tap()
        XCTAssertTrue(element(app,"text-テキスト").waitForExistence(timeout:2))

        // Codex minor (5C round 1): placing a text left the earlier symbol selection dangling, so the
        // inspector (which checks selectedSymbol first) still showed the old symbol instead of the new text.
        app.buttons["確認"].tap()
        XCTAssertTrue(app.staticTexts["テキスト"].waitForExistence(timeout:2),"the inspector must show the just-placed text, not a stale symbol selection")
        XCTAssertFalse(app.staticTexts["シンボル"].exists)
    }

    @MainActor
    func testUndoRedoOnAddingAndDeletingATextItem() throws {
        let app = makeApp(); app.launch()
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

    // MARK: - Live editing on the canvas (5D)

    @MainActor
    func testLiveEditingASymbolNameClosesInspectorBlocksOtherElementsUpdatesLiveAndReturnsOnDone() throws {
        let app = makeApp(); app.launch()
        XCTAssertTrue(element(app,"symbol-Main MCU").waitForExistence(timeout:3))
        element(app,"symbol-Main MCU").tap()
        app.buttons["確認"].tap()
        XCTAssertTrue(app.buttons["inspector-symbol-title"].waitForExistence(timeout:2))
        app.buttons["inspector-symbol-title"].tap()
        XCTAssertFalse(app.navigationBars["インスペクタ"].exists,"tapping the name must close the inspector sheet")
        let field = app.textFields["live-edit-field"]
        XCTAssertTrue(field.waitForExistence(timeout:2))
        XCTAssertTrue(element(app,"live-edit-scrim").exists)

        // Other elements are dimmed and unreachable while live-editing (the scrim sits above them and
        // absorbs the touch, even though the covered element is still in the accessibility tree).
        XCTAssertFalse(app.buttons["＋シンボル"].isEnabled)
        element(app,"symbol-CAN").tap()
        XCTAssertTrue(field.exists,"a tap on a dimmed symbol must not have done anything, e.g. selected it and dismissed this field")

        // Typing reflects immediately on the canvas's own card - it is the same binding, not a scratch copy
        // only written back on commit.
        field.tap()
        field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:20) + "Renamed MCU")
        XCTAssertTrue(element(app,"symbol-Renamed MCU").waitForExistence(timeout:2),"the canvas card itself must update live, not only after committing")

        // Confirming returns to the inspector.
        app.buttons["live-edit-done"].tap()
        XCTAssertTrue(app.navigationBars["インスペクタ"].waitForExistence(timeout:2))
        XCTAssertTrue(app.staticTexts["Renamed MCU"].exists)
    }

    @MainActor
    func testLiveEditingANoteBodyBlocksDraggingItAndSavesOnDone() throws {
        let app = makeApp(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        note.tap()
        app.buttons["確認"].tap()
        app.buttons["note-body-editor"].tap()
        let field = app.textViews["live-edit-field"]
        XCTAssertTrue(field.waitForExistence(timeout:2))

        // A drag over the note - still visible and interactive-looking through the scrim's hole over it -
        // must not actually move it while its body is being edited.
        let before = note.value as? String
        let start = note.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 60, dy: 60)))
        XCTAssertEqual(note.value as? String, before, "the note must not move while its body is being live-edited")

        field.tap(); field.tap()
        field.typeText(" 追記")
        app.buttons["live-edit-done"].tap()
        app.navigationBars["インスペクタ"].swipeDown()
        XCTAssertTrue(element(app,"experiment-note-R12を変更").waitForExistence(timeout:2))

        // The edit must actually have been saved to the model (Codex minor, 5D round 1: this test used to
        // stop at an assertion that could not fail even if the body write itself had silently done nothing).
        note.tap()
        app.buttons["確認"].tap()
        app.buttons["note-body-editor"].tap()
        let reopened = app.textViews["live-edit-field"]
        XCTAssertTrue(reopened.waitForExistence(timeout:2))
        XCTAssertTrue((reopened.value as? String ?? "").contains("追記"),"the body edit must have been saved")
        app.buttons["live-edit-done"].tap()
    }

    @MainActor
    func testEditModeToggleIsDisabledWhileLiveEditing() throws {
        let app = makeApp(); app.launch()
        let symbol = element(app,"symbol-Main MCU")
        XCTAssertTrue(symbol.waitForExistence(timeout:3))
        symbol.tap()
        app.buttons["確認"].tap()
        app.buttons["inspector-symbol-title"].tap()
        XCTAssertTrue(app.textFields["live-edit-field"].waitForExistence(timeout:2))
        // Entering edit mode clears the very selection the live-edit card depends on, which would strand it
        // with no way back to the inspector (Codex major, 5D round 1).
        XCTAssertFalse(app.buttons["edit-mode-toggle"].isEnabled,"edit mode must be unreachable while live-editing")
        app.buttons["live-edit-done"].tap()
        XCTAssertTrue(app.buttons["edit-mode-toggle"].isEnabled,"edit mode must work again once live-editing ends")
    }

    @MainActor
    func testUndoIsDisabledWhileLiveEditingAFreshlyAddedItem() throws {
        let app = makeApp(); app.launch()
        app.buttons["library-category-テキスト"].tap()
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:500)).tap()
        XCTAssertTrue(element(app,"text-テキスト").waitForExistence(timeout:2))
        XCTAssertTrue(app.buttons["undo-button"].isEnabled,"placing the text item must have pushed an undo step")

        element(app,"text-テキスト").tap()
        app.buttons["確認"].tap()
        app.buttons["text-body-editor"].tap()
        XCTAssertTrue(app.textViews["live-edit-field"].waitForExistence(timeout:2))
        // Undoing here would delete the very item the edit card is bound to, stranding the card with no
        // valid binding and no way to close (Codex major, 5D round 1).
        XCTAssertFalse(app.buttons["undo-button"].isEnabled,"undo must be unreachable while live-editing a freshly added item")
        app.buttons["live-edit-done"].tap()
        XCTAssertTrue(app.buttons["undo-button"].isEnabled,"undo must work again once live-editing ends")
    }

    // MARK: - Live-edit hole/card geometry (5D round 2)

    @MainActor
    func testLiveEditingARotatedNonBlockSymbolNameHoleIncludesItsLabel() throws {
        let app = makeApp(); app.launch()
        place(app, category:"受動部品", name:"抵抗", x:380, y:530)
        element(app,"symbol-抵抗").tap()
        // Rotate once (0° -> 90°): SymbolCard.label moves from below the body to its right - a case the
        // fixed body-only hole missed entirely before this fix (Codex major, 5D round 2).
        app.buttons["symbol-抵抗-rotate"].tap()
        let cardFrame = element(app,"symbol-抵抗").frame
        app.buttons["確認"].tap()
        XCTAssertTrue(app.buttons["inspector-symbol-title"].waitForExistence(timeout:2))
        app.buttons["inspector-symbol-title"].tap()
        XCTAssertTrue(app.textFields["live-edit-field"].waitForExistence(timeout:2))
        let hole = parseRect(element(app,"live-edit-hole").value as? String ?? "")
        // The label is drawn outside the symbol's own hit-test frame (cardFrame); the hole must have grown
        // to include it rather than staying pinned to cardFrame's own width.
        XCTAssertGreaterThan(hole.width, cardFrame.width, "the hole must widen to include the rotated label, not just the symbol's own body")
        app.buttons["live-edit-done"].tap()
    }

    @MainActor
    func testLiveEditingATextItemHoleGrowsWithLongerContent() throws {
        let app = makeApp(); app.launch()
        app.buttons["library-category-テキスト"].tap()
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:500)).tap()
        XCTAssertTrue(element(app,"text-テキスト").waitForExistence(timeout:2))
        element(app,"text-テキスト").tap()
        app.buttons["確認"].tap()
        app.buttons["text-body-editor"].tap()
        let field = app.textViews["live-edit-field"]
        XCTAssertTrue(field.waitForExistence(timeout:2))
        let holeBefore = parseRect(element(app,"live-edit-hole").value as? String ?? "")

        field.tap(); field.tap()
        field.typeText("とても長い本文をここに追記してテスト用に十分な幅と高さを要求します")
        let holeAfter = parseRect(element(app,"live-edit-hole").value as? String ?? "")
        // The old fixed 220x80 approximation never changed no matter what was typed; the real, measured
        // frame must grow with the content (Codex major, 5D round 2).
        XCTAssertTrue(holeAfter.width > holeBefore.width || holeAfter.height > holeBefore.height,
                      "a longer text body must grow the hole beyond the fixed approximation")
        app.buttons["live-edit-done"].tap()
    }

    @MainActor
    func testLiveEditInputCardNeverOverlapsATallExpandedNoteWhileEditingItsBody() throws {
        let app = makeApp(); app.launch()
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))
        note.tap()
        app.buttons["確認"].tap()
        app.navigationBars["インスペクタ"].swipeDown()
        // Grow the note toward its maximum height (320pt) - a hole this tall is what produced Codex's
        // concrete counterexample where neither below nor above had room and the old fallback clamped the
        // card straight onto the hole (Codex major, 5D round 2).
        let handle = element(app,"experiment-note-R12を変更-resize-br")
        XCTAssertTrue(handle.waitForExistence(timeout:2))
        let handleStart = handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        handleStart.press(forDuration:0.05,thenDragTo:handleStart.withOffset(CGVector(dx:100,dy:400)))

        note.tap()
        app.buttons["確認"].tap()
        app.buttons["note-body-editor"].tap()
        let field = app.textViews["live-edit-field"]
        XCTAssertTrue(field.waitForExistence(timeout:2))
        // The keyboard must actually be up: this must hold under the real on-screen conditions editing
        // happens in, not just in the instant before the field has focus (Codex major, 5D round 3 - the
        // previous version of this test checked before ever tapping the field).
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout:2),"the keyboard must appear for this check to be meaningful")
        // The card's rect is now its own real measured layout (LiveEditCardFrameKey), not the pre-layout
        // value this file computed for it - see that key's own doc comment (Codex major, 5D round 3).
        let hole = parseRect(element(app,"live-edit-hole").value as? String ?? "")
        let card = parseRect(element(app,"live-edit-card-rect").value as? String ?? "")
        XCTAssertFalse(hole.intersects(card), "the input card must never overlap the item being edited, even when it has grown tall")
        // Non-overlap alone would also pass a card pushed off past the viewport's own edge (the documented
        // last-resort trade-off for a hole that leaves no side with room for even the card's minimum size) -
        // a note at its ordinary maximum height, on a real iPad viewport, must never actually hit that
        // trade-off and must stay fully reachable on screen (Codex minor, 5D round 4).
        let viewportParts = (element(app,"viewport-size").value as? String ?? "").split(separator:",").compactMap { Double($0) }
        XCTAssertEqual(viewportParts.count,2,"could not read viewport-size")
        if viewportParts.count == 2 {
            let viewport = CGRect(x:0,y:0,width:viewportParts[0],height:viewportParts[1])
            XCTAssertTrue(viewport.contains(card),"the input card must stay fully on screen for a realistically-sized note, not just avoid the hole")
        }
        app.buttons["live-edit-done"].tap()
    }

    @MainActor
    func testLiveEditingRemainsOperableForAMaxSizedNoteAtMaximumZoom() throws {
        let app = makeApp()
        // UITEST_INITIAL_ZOOM (see ContentView's onAppear) starts the canvas at its maximum 2.5x scale -
        // XCUITest's synthetic pinch cannot reliably reach a non-preset scale in this harness, so this is the
        // established way an existing test opts into one (see the 4E zoom tests).
        app.launchEnvironment["UITEST_INITIAL_ZOOM"] = "2.5"
        app.launch()
        let canvas = element(app,"circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout:3))
        // Placed by tapping a point in SCREEN space (canvasTapGesture converts it through the current
        // scale/offset), so this lands centrally on screen regardless of zoom - unlike the seed note, which
        // at 2.5x zoom would itself sit too close to the viewport's edge to reliably drag its resize handle.
        app.buttons["＋メモ"].tap()
        canvas.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:400,dy:300)).tap()
        let note = element(app,"experiment-note-新しいメモ")
        XCTAssertTrue(note.waitForExistence(timeout:2))

        // Grow it to its maximum size (390x320 canvas-space) - combined with the 2.5x zoom this launched at,
        // its on-screen footprint (up to 975x800) can exceed the whole viewport, which used to leave the
        // input field and its 完了 button placed off screen and unreachable, with no way to zoom out during
        // live-editing to recover (Codex major, 5D round 5).
        note.tap()
        let handle = element(app,"experiment-note-新しいメモ-resize-br")
        XCTAssertTrue(handle.waitForExistence(timeout:2))
        let handleStart = handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        handleStart.press(forDuration:0.05,thenDragTo:handleStart.withOffset(CGVector(dx:600,dy:600)))

        note.tap()
        app.buttons["確認"].tap()
        app.buttons["note-body-editor"].tap()
        let field = app.textViews["live-edit-field"]
        XCTAssertTrue(field.waitForExistence(timeout:2))
        XCTAssertTrue(field.isHittable,"the field must stay reachable even when the target's on-screen footprint exceeds the viewport")
        field.tap()
        field.typeText(" 追記")
        let done = app.buttons["live-edit-done"]
        XCTAssertTrue(done.isHittable,"the 完了 button must stay reachable too, or live-editing could never be exited")
        done.tap()
        XCTAssertTrue(app.navigationBars["インスペクタ"].waitForExistence(timeout:2),"confirming must still return to the inspector")
    }

    // MARK: - Grouping (5E)

    /// Drags a marquee (in group-selection mode) over the given canvas-space rectangle corners and confirms
    /// the resulting "グループ化しますか？" alert - the drag path only needs to start on empty canvas (a
    /// touch starting exactly on an item is claimed by that item's own drag gesture instead, per
    /// canvasPanGesture/each item's highPriorityGesture), not on the items themselves.
    @MainActor
    private func groupViaMarquee(_ app: XCUIApplication, from: CGVector, to: CGVector) {
        app.buttons["group-mode-toggle"].tap()
        let canvas = element(app,"circuit-canvas")
        let start = canvas.coordinate(withNormalizedOffset:.zero).withOffset(from)
        let end = canvas.coordinate(withNormalizedOffset:.zero).withOffset(to)
        start.press(forDuration:0.2, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["グループ化しますか？"].waitForExistence(timeout:2))
        app.buttons["はい"].tap()
    }

    @MainActor
    func testGroupingViaMarqueeMergesPartiallyOverlappingItemsAndSelectingHidesIndividualEditingUI() throws {
        let app = makeApp(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        // Encloses "24 V → 5 V" (120,160) and "Temperature" (120,390) - both merely brush the marquee's own
        // edges, not fully inside it, per this task's "一部でも重なった...対象" requirement.
        groupViaMarquee(app, from: CGVector(dx:60,dy:120), to: CGVector(dx:200,dy:420))

        let groupA = element(app,"symbol-24 V → 5 V-group").value as? String ?? ""
        let groupB = element(app,"symbol-Temperature-group").value as? String ?? ""
        XCTAssertFalse(groupA.isEmpty,"both marquee-selected symbols must have joined a group")
        XCTAssertEqual(groupA, groupB, "both marquee-selected symbols must be in the SAME group")
        // A symbol not touched by the marquee must not have joined it.
        XCTAssertEqual(element(app,"symbol-Main MCU-group").value as? String, "")

        element(app,"symbol-24 V → 5 V").tap()
        XCTAssertTrue(element(app,"group-highlight").waitForExistence(timeout:2),"tapping a grouped member must select the whole group")
        XCTAssertTrue(app.buttons["group-ungroup"].exists)
        // "グループのメンバーは、個別編集...ができない" - a grouped block gets none of its own resize handles,
        // since those are only ever shown for selectedSymbol, which a grouped member never sets.
        XCTAssertFalse(element(app,"symbol-24 V → 5 V-resize-tl").exists,"a grouped member must not show its own individual resize handles")
    }

    @MainActor
    func testDraggingOneGroupedSymbolMovesTheOtherAndKeepsTheConnectingWireAttached() throws {
        let app = makeApp(); app.launch()
        // "24 V → 5 V" (120,160) and "Main MCU" (370,250) are wired together by the seed diagram's wire-0 -
        // excludes the seed note (y ≤ 130) and CAN/Temperature (outside this rectangle).
        groupViaMarquee(app, from: CGVector(dx:60,dy:140), to: CGVector(dx:420,dy:320))
        XCTAssertEqual(element(app,"symbol-24 V → 5 V-group").value as? String, element(app,"symbol-Main MCU-group").value as? String)
        XCTAssertFalse((element(app,"symbol-24 V → 5 V-group").value as? String ?? "").isEmpty)

        func pin(_ title: String, _ index: Int = 0) -> [Double] { (element(app,"symbol-\(title)-pin-\(index)").value as? String ?? "").split(separator:",").compactMap{Double($0)} }
        let beforeA = pin("24 V → 5 V"), beforeB = pin("Main MCU")

        // Dragging just the one member must move BOTH - "メンバーのどれかをドラッグすると、グループ全体が動く".
        let handle = element(app,"symbol-24 V → 5 V").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        handle.press(forDuration:0.2, thenDragTo: handle.withOffset(CGVector(dx:50,dy:50)))

        let afterA = pin("24 V → 5 V"), afterB = pin("Main MCU")
        XCTAssertEqual(afterA[0]-beforeA[0], 50, accuracy:2, "the dragged member itself must have moved")
        XCTAssertEqual(afterA[1]-beforeA[1], 50, accuracy:2)
        XCTAssertEqual(afterB[0]-beforeB[0], 50, accuracy:2, "the OTHER grouped member must have moved by the same amount")
        XCTAssertEqual(afterB[1]-beforeB[1], 50, accuracy:2)

        // "配線はつながったまま...自動で再描画する": wire-0's endpoints must still sit exactly on both symbols'
        // (now-moved) pins, not the old, now-stale positions. The seed wire actually runs from "24 V → 5 V"'s
        // RIGHT pin (pin-1, x = position + 45) to "Main MCU"'s LEFT pin (pin-0, x = position - 45) - pin-0
        // above was only ever used to measure how far each whole block moved, which is the same for every
        // one of its pins regardless of which one a wire happens to touch.
        let afterARightPin = pin("24 V → 5 V", 1), afterBLeftPin = pin("Main MCU", 0)
        let wireValue = (element(app,"wire-0").value as? String ?? "").split(separator:",").compactMap{Double($0)}
        XCTAssertEqual(wireValue.count, 4)
        XCTAssertEqual(wireValue[0], afterARightPin[0], accuracy:2); XCTAssertEqual(wireValue[1], afterARightPin[1], accuracy:2)
        XCTAssertEqual(wireValue[2], afterBLeftPin[0], accuracy:2); XCTAssertEqual(wireValue[3], afterBLeftPin[1], accuracy:2)
    }

    @MainActor
    func testEditModeOnlyDeletesTheWholeGroupNotIndividualMembers() throws {
        let app = makeApp(); app.launch()
        place(app, category:"受動部品", name:"抵抗", x:700, y:500)
        place(app, category:"受動部品", name:"コンデンサ", x:700, y:600)
        groupViaMarquee(app, from: CGVector(dx:620,dy:470), to: CGVector(dx:780,dy:630))
        let groupID = element(app,"symbol-抵抗-group").value as? String ?? ""
        XCTAssertFalse(groupID.isEmpty)
        XCTAssertEqual(groupID, element(app,"symbol-コンデンサ-group").value as? String)

        app.buttons["edit-mode-toggle"].tap()
        XCTAssertFalse(element(app,"symbol-抵抗-edit-delete").exists,"a grouped member must not show its own individual delete badge")
        XCTAssertFalse(element(app,"symbol-コンデンサ-edit-delete").exists)
        let groupDelete = element(app,"group-\(groupID)-edit-delete")
        XCTAssertTrue(groupDelete.waitForExistence(timeout:2),"the group itself must show exactly one delete badge")
        groupDelete.tap()
        XCTAssertTrue(app.staticTexts["削除しますか？"].waitForExistence(timeout:2))
        app.buttons["削除"].tap()
        XCTAssertFalse(element(app,"symbol-抵抗").exists,"deleting the group must delete every member")
        XCTAssertFalse(element(app,"symbol-コンデンサ").exists)
    }

    @MainActor
    func testUngroupingRestoresIndividualSelectionAndEditing() throws {
        let app = makeApp(); app.launch()
        place(app, category:"受動部品", name:"抵抗", x:700, y:500)
        place(app, category:"受動部品", name:"コンデンサ", x:700, y:600)
        groupViaMarquee(app, from: CGVector(dx:620,dy:470), to: CGVector(dx:780,dy:630))

        element(app,"symbol-抵抗").tap()
        XCTAssertTrue(app.buttons["group-ungroup"].waitForExistence(timeout:2))
        app.buttons["group-ungroup"].tap()

        XCTAssertEqual(element(app,"symbol-抵抗-group").value as? String, "", "ungrouping must clear both members' group membership")
        XCTAssertEqual(element(app,"symbol-コンデンサ-group").value as? String, "")

        // Individual editing must work again - a non-block circuit symbol's rotate button only ever shows for
        // an individually-selected (not grouped) symbol.
        element(app,"symbol-抵抗").tap()
        XCTAssertTrue(app.buttons["symbol-抵抗-rotate"].waitForExistence(timeout:2),"the ungrouped symbol must be individually selectable again")
    }

    @MainActor
    func testGroupingAnItemAlreadyInAGroupWidensItInsteadOfNesting() throws {
        let app = makeApp(); app.launch()
        place(app, category:"受動部品", name:"抵抗", x:700, y:500)
        place(app, category:"受動部品", name:"コンデンサ", x:700, y:580)
        place(app, category:"受動部品", name:"コイル", x:700, y:660)

        groupViaMarquee(app, from: CGVector(dx:620,dy:470), to: CGVector(dx:780,dy:610))   // 抵抗 + コンデンサ
        let firstGroup = element(app,"symbol-抵抗-group").value as? String ?? ""
        XCTAssertFalse(firstGroup.isEmpty)
        XCTAssertEqual(element(app,"symbol-コイル-group").value as? String, "", "コイル must not have joined the first group")

        groupViaMarquee(app, from: CGVector(dx:620,dy:550), to: CGVector(dx:780,dy:690))   // コンデンサ + コイル
        // "2つの既存グループにまたがって選択した場合も、1つのグループに統合する" - here it is one existing
        // group (抵抗+コンデンサ) touched by a new selection (コンデンサ+コイル): all three must end up in ONE
        // flat group, not a separate new one nested alongside the first.
        let merged = element(app,"symbol-抵抗-group").value as? String ?? ""
        XCTAssertFalse(merged.isEmpty)
        XCTAssertEqual(merged, element(app,"symbol-コンデンサ-group").value as? String)
        XCTAssertEqual(merged, element(app,"symbol-コイル-group").value as? String, "widening an existing group must not leave a member behind in a separate group")
    }

    /// A marquee drag that starts exactly on top of an existing item (not on empty canvas) must still reach
    /// canvasPanGesture and draw a marquee, rather than being swallowed by that item's own (still-attached)
    /// drag gesture - this task's own requirement has no such restriction on where the drag may begin (Codex
    /// major, 5E round 1: the original tests only ever started their marquees from empty space).
    @MainActor
    func testGroupSelectionMarqueeCanStartOnTopOfAnItem() throws {
        let app = makeApp(); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        app.buttons["group-mode-toggle"].tap()
        let start = element(app,"symbol-24 V → 5 V").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        let end = element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:200,dy:420))
        start.press(forDuration:0.2, thenDragTo:end)
        XCTAssertTrue(app.staticTexts["グループ化しますか？"].waitForExistence(timeout:2),"a marquee started on top of an item must still register as a drag on the canvas")
        app.buttons["はい"].tap()
        XCTAssertFalse((element(app,"symbol-24 V → 5 V-group").value as? String ?? "").isEmpty)
        XCTAssertEqual(element(app,"symbol-24 V → 5 V-group").value as? String, element(app,"symbol-Temperature-group").value as? String)
    }

    @MainActor
    func testWirePinOnAGroupedSymbolCannotBeReconnectedDirectlyOrViaANearbyBackgroundTap() throws {
        let app = makeApp(); app.launch()
        // "24 V → 5 V" (120,160) + "Main MCU" (370,250) - excludes the seed note and CAN/Temperature.
        groupViaMarquee(app, from: CGVector(dx:60,dy:140), to: CGVector(dx:420,dy:320))
        XCTAssertFalse((element(app,"symbol-24 V → 5 V-group").value as? String ?? "").isEmpty)
        app.buttons["配線"].tap()

        // Direct tap on the grouped symbol's own pin - SymbolCard's own selectPin guard.
        app.buttons["symbol-24 V → 5 V-pin-1"].tap()
        XCTAssertTrue(app.staticTexts["始点のピンをタップ"].exists,"a grouped symbol's pin must not start a wire from a direct tap on it")

        // A background tap NEAR (not on) that same pin - canvasTapGesture's own nearestPin fallback, which
        // has no group check of its own without this task's fix (Codex major, 5E round 1).
        let pinValue = (element(app,"symbol-24 V → 5 V-pin-1").value as? String ?? "").split(separator:",").compactMap{Double($0)}
        XCTAssertEqual(pinValue.count, 2)
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:pinValue[0],dy:pinValue[1]+30)).tap()
        XCTAssertTrue(app.staticTexts["始点のピンをタップ"].exists,"a background tap near a grouped symbol's pin must not start a wire either")
    }

    /// A short default "テキスト" is well within the old fixed 160x40 approximation's own half-width (80pt),
    /// so a marquee reaching only a MUCH longer text's real far edge - well past that old half-width - could
    /// only ever select it via the real measured frame (TextFramesKey/canvasRect), not the fixed guess it
    /// replaced (Codex minor, 5E round 2: the mixed-group test's default-length text left this fix itself
    /// unverified, since the old approximation would have matched it too).
    @MainActor
    func testGroupSelectionMarqueeUsesATextItemsRealMeasuredWidthNotAFixedApproximation() throws {
        let app = makeApp(); app.launch()
        app.buttons["library-category-テキスト"].tap()
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:300,dy:500)).tap()
        element(app,"text-テキスト").tap()
        app.buttons["確認"].tap()
        app.buttons["text-body-editor"].tap()
        let field = app.textViews["live-edit-field"]
        XCTAssertTrue(field.waitForExistence(timeout:2))
        field.tap(); field.tap()
        let longBody = String(repeating:"テキスト", count:10)
        field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:20) + longBody)
        app.buttons["live-edit-done"].tap()
        app.navigationBars["インスペクタ"].swipeDown()
        // A tap's cursor landing position inside a multiline field is layout/device-sensitive (documented
        // elsewhere in this file), so the typed text is not guaranteed to land at the very start - matching
        // by CONTAINS, then reading back the element's own real identifier, avoids assuming exact placement.
        let longTextElement = app.descendants(matching: .any).matching(NSPredicate(format:"identifier CONTAINS %@", longBody)).firstMatch
        XCTAssertTrue(longTextElement.waitForExistence(timeout:2))
        let longIdentifier = longTextElement.identifier

        // A thin strip 300-340pt to the right of the text's own center (300,500) - well beyond where the old
        // fixed approximation's half-width (80pt) could ever reach, but within this much longer text's real
        // rendered extent.
        groupViaMarquee(app, from: CGVector(dx:600,dy:480), to: CGVector(dx:640,dy:520))
        XCTAssertFalse((element(app,"\(longIdentifier)-group").value as? String ?? "").isEmpty,
                       "a marquee reaching only the far edge of a long text's REAL width must still select it")
    }

    /// Covers a group mixing all three item types, with a wire reaching OUTSIDE the group to an ungrouped
    /// symbol - the original 6 tests were all-symbol groups only (Codex major, 5E round 1).
    @MainActor
    func testMixedGroupMovesAllMemberTypesTogetherAndKeepsAnExternalWireAttachedWhileTheOtherEndStaysPut() throws {
        let app = makeApp(); app.launch()
        // A note and a text placed near "CAN" (620,250), which the seed diagram wires to "Main MCU" (370,250)
        // - well outside the marquee below, so that wire's far end must stay fixed while the near end moves.
        app.buttons["＋メモ"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:620,dy:350)).tap()
        app.buttons["確認"].tap()
        app.navigationBars["インスペクタ"].swipeDown()
        app.buttons["library-category-テキスト"].tap()
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:620,dy:420)).tap()

        groupViaMarquee(app, from: CGVector(dx:550,dy:220), to: CGVector(dx:700,dy:450))
        let groupID = element(app,"symbol-CAN-group").value as? String ?? ""
        XCTAssertFalse(groupID.isEmpty)
        XCTAssertEqual(groupID, element(app,"experiment-note-新しいメモ-group").value as? String)
        XCTAssertEqual(groupID, element(app,"text-テキスト-group").value as? String)

        func xy(_ value: String) -> (Double, Double) {
            let n = value.split(whereSeparator: { !("-0123456789.".contains($0)) }).compactMap { Double($0) }
            return (n.count > 0 ? n[0] : .nan, n.count > 1 ? n[1] : .nan)
        }
        func pin(_ title: String, _ index: Int) -> [Double] { (element(app,"symbol-\(title)-pin-\(index)").value as? String ?? "").split(separator:",").compactMap{Double($0)} }
        let notePosBefore = xy(element(app,"experiment-note-新しいメモ").value as? String ?? "")
        let textPosBefore = xy(element(app,"text-テキスト").value as? String ?? "")
        let canPinBefore = pin("CAN", 0)               // CAN's LEFT pin, wired to Main MCU
        let mainMCUPinBefore = pin("Main MCU", 1)      // Main MCU's RIGHT pin - outside the group, must not move

        // Drag the note (one of the three member types) - every member, of every type, must move together.
        let handle = element(app,"experiment-note-新しいメモ").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        handle.press(forDuration:0.2, thenDragTo: handle.withOffset(CGVector(dx:40,dy:-30)))

        let notePosAfter = xy(element(app,"experiment-note-新しいメモ").value as? String ?? "")
        let textPosAfter = xy(element(app,"text-テキスト").value as? String ?? "")
        let canPinAfter = pin("CAN", 0)
        let mainMCUPinAfter = pin("Main MCU", 1)

        XCTAssertEqual(notePosAfter.0-notePosBefore.0, 40, accuracy:2)
        XCTAssertEqual(notePosAfter.1-notePosBefore.1, -30, accuracy:2)
        XCTAssertEqual(textPosAfter.0-textPosBefore.0, 40, accuracy:2, "the text member must have moved by the same amount as the dragged note")
        XCTAssertEqual(textPosAfter.1-textPosBefore.1, -30, accuracy:2)
        XCTAssertEqual(canPinAfter[0]-canPinBefore[0], 40, accuracy:2, "the symbol member (CAN) must have moved too")
        XCTAssertEqual(canPinAfter[1]-canPinBefore[1], -30, accuracy:2)
        XCTAssertEqual(mainMCUPinAfter[0], mainMCUPinBefore[0], accuracy:2, "the OTHER end of the wire, outside the group, must not have moved")
        XCTAssertEqual(mainMCUPinAfter[1], mainMCUPinBefore[1], accuracy:2)

        // The wire's outside segment must have re-routed to the group's new position while staying attached
        // to Main MCU's own fixed pin - "配線はつながったまま...自動で再描画する".
        let wireValue = (element(app,"wire-1").value as? String ?? "").split(separator:",").compactMap{Double($0)}
        XCTAssertEqual(wireValue.count, 4)
        XCTAssertEqual(wireValue[0], mainMCUPinAfter[0], accuracy:2); XCTAssertEqual(wireValue[1], mainMCUPinAfter[1], accuracy:2)
        XCTAssertEqual(wireValue[2], canPinAfter[0], accuracy:2); XCTAssertEqual(wireValue[3], canPinAfter[1], accuracy:2)

        // Individual editing must be blocked for every member type, not only symbols.
        app.buttons["edit-mode-toggle"].tap()
        XCTAssertFalse(element(app,"experiment-note-新しいメモ-edit-delete").exists)
        XCTAssertFalse(element(app,"text-テキスト-edit-delete").exists)
        XCTAssertFalse(element(app,"symbol-CAN-edit-delete").exists)
    }

    /// Covers Undo/Redo for every group-level operation this task calls out - creating, ungrouping, moving
    /// (as one step for the whole group, not per member), and deleting - not only creation (Codex minor, 5E
    /// round 1: the original version of this test stopped there).
    @MainActor
    func testUndoRedoOnGroupingUngroupingMovingAndDeletingAGroup() throws {
        let app = makeApp(); app.launch()
        place(app, category:"受動部品", name:"抵抗", x:700, y:500)
        place(app, category:"受動部品", name:"コンデンサ", x:700, y:600)
        groupViaMarquee(app, from: CGVector(dx:620,dy:470), to: CGVector(dx:780,dy:630))
        let groupID = element(app,"symbol-抵抗-group").value as? String ?? ""
        XCTAssertFalse(groupID.isEmpty)

        app.buttons["undo-button"].tap()
        XCTAssertEqual(element(app,"symbol-抵抗-group").value as? String, "", "undo must remove the just-created group")

        app.buttons["redo-button"].tap()
        XCTAssertEqual(element(app,"symbol-抵抗-group").value as? String, groupID, "redo must restore the exact same group")
        XCTAssertEqual(element(app,"symbol-コンデンサ-group").value as? String, groupID)

        // Ungroup, then Undo/Redo that too.
        element(app,"symbol-抵抗").tap()
        app.buttons["group-ungroup"].tap()
        XCTAssertEqual(element(app,"symbol-抵抗-group").value as? String, "", "ungrouping must have taken effect")
        app.buttons["undo-button"].tap()
        XCTAssertEqual(element(app,"symbol-抵抗-group").value as? String, groupID, "undo must restore the group ungrouping just removed")
        XCTAssertEqual(element(app,"symbol-コンデンサ-group").value as? String, groupID)
        app.buttons["redo-button"].tap()
        XCTAssertEqual(element(app,"symbol-抵抗-group").value as? String, "", "redo must remove it again")
        app.buttons["undo-button"].tap()   // back to grouped, to continue with move/delete below
        XCTAssertEqual(element(app,"symbol-抵抗-group").value as? String, groupID)

        // Move the group, then Undo it in ONE step - both members must revert together, not one at a time.
        func pin(_ title: String) -> [Double] { (element(app,"symbol-\(title)-pin-0").value as? String ?? "").split(separator:",").compactMap{Double($0)} }
        let beforeMoveA = pin("抵抗"), beforeMoveB = pin("コンデンサ")
        let handle = element(app,"symbol-抵抗").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        handle.press(forDuration:0.2, thenDragTo: handle.withOffset(CGVector(dx:30,dy:30)))
        XCTAssertEqual(pin("抵抗")[0]-beforeMoveA[0], 30, accuracy:2, "the move must actually have happened, or undoing it below would prove nothing")
        app.buttons["undo-button"].tap()
        XCTAssertEqual(pin("抵抗")[0], beforeMoveA[0], accuracy:2, "undo must restore the dragged member's position")
        XCTAssertEqual(pin("抵抗")[1], beforeMoveA[1], accuracy:2)
        XCTAssertEqual(pin("コンデンサ")[0], beforeMoveB[0], accuracy:2, "and the OTHER member's position too, in the same single undo step")
        XCTAssertEqual(pin("コンデンサ")[1], beforeMoveB[1], accuracy:2)
        app.buttons["redo-button"].tap()
        XCTAssertEqual(pin("抵抗")[0]-beforeMoveA[0], 30, accuracy:2, "redo must reapply the move to the dragged member")
        XCTAssertEqual(pin("抵抗")[1]-beforeMoveA[1], 30, accuracy:2)
        XCTAssertEqual(pin("コンデンサ")[0]-beforeMoveB[0], 30, accuracy:2, "and to the other member, in the same single redo step")
        XCTAssertEqual(pin("コンデンサ")[1]-beforeMoveB[1], 30, accuracy:2)
        app.buttons["undo-button"].tap()   // back to pre-move, to continue with delete below
        XCTAssertEqual(pin("抵抗")[0], beforeMoveA[0], accuracy:2)

        // Delete the group, then Undo/Redo that.
        app.buttons["edit-mode-toggle"].tap()
        element(app,"group-\(groupID)-edit-delete").tap()
        XCTAssertTrue(app.staticTexts["削除しますか？"].waitForExistence(timeout:2))
        app.buttons["削除"].tap()
        XCTAssertFalse(element(app,"symbol-抵抗").exists)
        XCTAssertFalse(element(app,"symbol-コンデンサ").exists)
        app.buttons["undo-button"].tap()
        XCTAssertTrue(element(app,"symbol-抵抗").waitForExistence(timeout:2),"undo must restore every deleted member")
        XCTAssertTrue(element(app,"symbol-コンデンサ").exists)
        XCTAssertEqual(element(app,"symbol-抵抗-group").value as? String, groupID, "and their group membership")
        app.buttons["redo-button"].tap()
        XCTAssertFalse(element(app,"symbol-抵抗").exists,"redo must delete the whole group again")
        XCTAssertFalse(element(app,"symbol-コンデンサ").exists)
    }

    /// Parses the "x=..;y=..;w=..;h=.." accessibility values this feature exposes for its hole/card rects
    /// back into a CGRect. Not a plain "x,y,w,h" comma join: a value that reads as a pure number can come
    /// back from XCUITest with locale grouping separators inserted into it (e.g. "2400" as "2,400"), which
    /// silently broke a naive comma-split for any on-screen value at or past 1000 (Codex major, 5D round 3
    /// surfaced this - the card's real measured size routinely lands in that range).
    /// Fails the test outright on a malformed value, rather than silently substituting .zero - a rect that
    /// trivially satisfies any non-intersection check and so could hide a real regression.
    private func parseRect(_ value: String, file: StaticString = #filePath, line: UInt = #line) -> CGRect {
        var fields: [String: Double] = [:]
        for pair in value.split(separator:";") {
            let kv = pair.split(separator:"=", maxSplits:1)
            if kv.count == 2 { fields[String(kv[0])] = Double(kv[1]) }
        }
        guard let x = fields["x"], let y = fields["y"], let w = fields["w"], let h = fields["h"] else {
            XCTFail("could not parse a rect out of \"\(value)\"", file:file, line:line)
            return .zero
        }
        return CGRect(x:x, y:y, width:w, height:h)
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Drives the 5D live-edit round trip: tap an inspector row (dismissing the sheet), type into the
    /// canvas-side field it opens, then confirm (back to the inspector). `clear` backspaces that many
    /// characters of the field's existing content first, mirroring the old direct-TextField tests' own
    /// delete-then-retype pattern.
    @MainActor
    private func liveEdit(_ app: XCUIApplication, trigger: String, multiline: Bool, clear: Int = 0, type: String) {
        app.buttons[trigger].tap()
        let field = multiline ? app.textViews["live-edit-field"] : app.textFields["live-edit-field"]
        XCTAssertTrue(field.waitForExistence(timeout:2),"live-edit-field did not appear for \(trigger)")
        // A single tap on this floating (position-placed) TextEditor does not reliably grant it keyboard
        // focus in this harness - a second tap does; harmless for the single-line TextField case too.
        field.tap(); field.tap()
        if clear > 0 { field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:clear)) }
        field.typeText(type)
        app.buttons["live-edit-done"].tap()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp()
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
        let app = makeApp()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
        XCTAssertTrue(element(app,"two-finger-pan-attached").waitForExistence(timeout:3))
        XCTAssertEqual(element(app,"two-finger-pan-attached").value as? String,"true")
    }

    @MainActor
    func testPanModeToggleEnablesThenDisablesOneFingerCanvasPanning() throws {
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let blockApp = makeApp(); blockApp.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
        // The initial diagram's blocks are all "汎用ブロック" underneath, but keep their original look.
        for (name, icon) in [("24 V → 5 V","bolt.fill"),("Main MCU","cpu"),("CAN","arrow.left.and.right"),("Temperature","sensor.tag.radiowaves.forward")] {
            XCTAssertEqual(element(app,"symbol-\(name)-icon").value as? String,icon,name)
        }
        place(app,category:"ブロック",name:"汎用ブロック",x:400,y:550)
        element(app,"symbol-汎用ブロック").tap()
        app.buttons["確認"].tap()
        liveEdit(app,trigger:"inspector-symbol-title",multiline:false,clear:10,type:"電源ユニット")
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
        let app = makeApp(); app.launch()
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
        liveEdit(app,trigger:"inspector-symbol-title",multiline:false,clear:3,type:"接地")
        XCTAssertTrue(element(app,"symbol-接地").exists)
        app.buttons["シンボルを削除"].tap()
        XCTAssertFalse(element(app,"symbol-接地").exists)
        XCTAssertEqual(element(app,"wire-count").value as? String,"4")
    }

    @MainActor
    func testCircuitRotationControlsPreserveCenterAndWiring() {
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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
        let app = makeApp(); app.launch()
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

    // MARK: Grid snapping (5F)

    private func onFifteenPointGrid(_ value: Double) -> Bool { abs(value.truncatingRemainder(dividingBy: 15)) < 0.5 }

    @MainActor
    func testPlacingASymbolNoteAndTextSnapsThePositionToTheGrid() throws {
        let app = makeApp(gridSnap: true); app.launch()
        XCTAssertTrue(element(app,"symbol-24 V → 5 V").waitForExistence(timeout:3))
        func position(_ value: String?) -> [Double] {
            (value ?? "").components(separatedBy: CharacterSet(charactersIn: "xy=, ")).compactMap { Double($0) }
        }

        // Every tap point below (703/502, 704/803, 706/906) is deliberately off the 15pt grid.
        place(app, category:"受動部品", name:"抵抗", x:703, y:502)
        let pin = coordinates(app.buttons["symbol-抵抗-pin-0"])
        XCTAssertTrue(onFifteenPointGrid(pin[0]) && onFifteenPointGrid(pin[1]), "a placed symbol's pin must land on the 15pt grid: \(pin)")

        app.buttons["＋メモ"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:704,dy:803)).tap()
        let note = element(app,"experiment-note-新しいメモ")
        XCTAssertTrue(note.waitForExistence(timeout:2))
        let notePosition = position(note.value as? String)
        XCTAssertTrue(onFifteenPointGrid(notePosition[0]) && onFifteenPointGrid(notePosition[1]), "a placed note must land on the 15pt grid: \(notePosition)")

        app.buttons["library-category-テキスト"].tap()
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:706,dy:906)).tap()
        let text = element(app,"text-テキスト")
        XCTAssertTrue(text.waitForExistence(timeout:2))
        let textPosition = position(text.value as? String)
        XCTAssertTrue(onFifteenPointGrid(textPosition[0]) && onFifteenPointGrid(textPosition[1]), "a placed text item must land on the 15pt grid: \(textPosition)")
    }

    @MainActor
    func testDraggingASymbolNoteOrTextSnapsToTheGridOnRelease() throws {
        let app = makeApp(gridSnap: true); app.launch()
        func position(_ value: String?) -> [Double] {
            (value ?? "").components(separatedBy: CharacterSet(charactersIn: "xy=, ")).compactMap { Double($0) }
        }

        // The seed symbol's own position (120,160) is not itself on the grid, and neither is the drag
        // amount (37,23) - proving the RELEASE snaps it, not a lucky starting point or a round drag number.
        let symbol = element(app,"symbol-24 V → 5 V")
        XCTAssertTrue(symbol.waitForExistence(timeout:3))
        let symbolStart = symbol.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        symbolStart.press(forDuration:0.2,thenDragTo:symbolStart.withOffset(CGVector(dx:37,dy:23)))
        let pin = coordinates(app.buttons["symbol-24 V → 5 V-pin-0"])
        XCTAssertTrue(onFifteenPointGrid(pin[0]) && onFifteenPointGrid(pin[1]), "a dragged symbol's pin must land on the 15pt grid: \(pin)")

        let note = element(app,"experiment-note-R12を変更")
        let noteBefore = position(note.value as? String)
        let noteStart = note.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        noteStart.press(forDuration:0.2,thenDragTo:noteStart.withOffset(CGVector(dx:37,dy:23)))
        let noteAfter = position(note.value as? String)
        XCTAssertNotEqual(noteAfter, noteBefore, "the note must really have moved")
        XCTAssertTrue(onFifteenPointGrid(noteAfter[0]) && onFifteenPointGrid(noteAfter[1]), "a dragged note must land on the 15pt grid: \(noteAfter)")

        app.buttons["library-category-テキスト"].tap()
        app.buttons["library-テキスト"].tap()
        element(app,"circuit-canvas").coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:700,dy:800)).tap()
        let text = element(app,"text-テキスト")
        XCTAssertTrue(text.waitForExistence(timeout:2))
        let textBefore = position(text.value as? String)
        let textStart = text.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        textStart.press(forDuration:0.2,thenDragTo:textStart.withOffset(CGVector(dx:23,dy:37)))
        let textAfter = position(text.value as? String)
        // Placement already snapped it, so "on the grid" alone would pass without any drag at all - check
        // it reached the grid point nearest to where it was released (Codex minor, 5F round 2).
        XCTAssertEqual(textAfter[0], ((textBefore[0]+23)/15).rounded()*15, accuracy: 0.5, "a dragged text item must land on the nearest grid point: \(textBefore) -> \(textAfter)")
        XCTAssertEqual(textAfter[1], ((textBefore[1]+37)/15).rounded()*15, accuracy: 0.5)
    }

    @MainActor
    func testGridSnapToggleInSettingsControlsWhetherDraggingSnaps() throws {
        // Forced off at launch (makeApp, via UITEST_GRID_SNAP) rather than relying on the Settings toggle's
        // default - gridSnapEnabled is an @AppStorage preference, so an ambient value left over from another
        // test run must not affect whether this test starts "off".
        let app = makeApp(gridSnap: false); app.launch()
        func position(_ value: String?) -> [Double] {
            (value ?? "").components(separatedBy: CharacterSet(charactersIn: "xy=, ")).compactMap { Double($0) }
        }
        let note = element(app,"experiment-note-R12を変更")
        XCTAssertTrue(note.waitForExistence(timeout:3))

        // Off: the note lands exactly where the finger released it, not pulled to the grid.
        let before = position(note.value as? String)
        let start = note.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.2,thenDragTo:start.withOffset(CGVector(dx:37,dy:23)))
        let offResult = position(note.value as? String)
        XCTAssertEqual(offResult[0]-before[0], 37, accuracy: 2, "grid snap must be off")
        XCTAssertEqual(offResult[1]-before[1], 23, accuracy: 2)

        // Turning it on in Settings must take effect immediately, with no relaunch.
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout:2))
        let toggle = element(app,"settings-grid-snap")
        XCTAssertTrue(toggle.waitForExistence(timeout:2))
        XCTAssertEqual(toggle.value as? String, "0")
        // A plain toggle.tap() hits the centre of the whole row (the label), which does not flip a Form
        // switch on iPadOS - tap the switch itself at the row's trailing edge instead.
        toggle.coordinate(withNormalizedOffset:CGVector(dx:0.95,dy:0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1", "the Settings switch itself must have flipped on")
        app.navigationBars["設定"].swipeDown()

        let onStart = note.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        onStart.press(forDuration:0.2,thenDragTo:onStart.withOffset(CGVector(dx:37,dy:23)))
        let onResult = position(note.value as? String)
        XCTAssertTrue(onFifteenPointGrid(onResult[0]) && onFifteenPointGrid(onResult[1]), "after turning grid snap on, a drag must land on the 15pt grid: \(onResult)")
    }

    /// Drags the first interior segment of each orientation on a fresh wire to 3pt past the grid line two
    /// lines (30pt) away, towards the wire's middle - well over the segment gesture's 4pt minimum, so a drag that never happened cannot
    /// pass - and checks where it ends up: on that exact line with snapping on, 3pt off it with snapping off.
    @MainActor
    private func dragWireSegments(snap: Bool, horizontal wanted: Bool) {
        let app = makeApp(gridSnap: snap); app.launch()
        // A fresh, isolated connection - not one of the seed wires, whose steps sit close enough together
        // for WireRouting's step-straightening alignment to take over. Side-by-side pins route through a
        // vertical middle segment; a top pin to a bottom pin (as in testVerticalPowerSegmentDragBranchAndRotation)
        // through a horizontal one.
        if wanted {
            place(app,category:"電源",name:"直流電源",x:300,y:530)
            place(app,category:"電源",name:"GND",x:650,y:530)
            app.buttons["配線"].tap()
            app.buttons["symbol-直流電源-pin-1"].tap()
            app.buttons["symbol-GND-pin-0"].tap()
        } else {
            place(app, category:"受動部品", name:"抵抗", x:300, y:700)
            place(app, category:"受動部品", name:"コンデンサ", x:600, y:850)
            app.buttons["配線"].tap()
            app.buttons["symbol-抵抗-pin-1"].tap()
            app.buttons["symbol-コンデンサ-pin-0"].tap()
        }

        let initial = routePoints(app,3)
        let interior = initial.count > 3 ? Array(1..<(initial.count-2)) : []
        guard let firstWanted = interior.first(where: { (initial[$0].y == initial[$0+1].y) == wanted }) else {
            return XCTFail("expected an interior \(wanted ? "horizontal" : "vertical") segment on the new wire: \(initial)")
        }
        for segment in [firstWanted] {
            let before = routePoints(app,3)
            let horizontal = before[segment].y == before[segment+1].y
            let from = horizontal ? before[segment].y : before[segment].x
            // Vertical: towards the middle of the wire - the other way would soon shorten a pin's lead-out
            // below its minimum, which WireRouting.moved refuses, leaving the segment where it was.
            // Horizontal: downwards, away from the two symbols the segment runs between.
            let direction: CGFloat = horizontal ? 1 : ((before.first!.x+before.last!.x)/2 < from ? -1 : 1)
            let gridLine = (from/15).rounded()*15 + 30*direction
            let amount = gridLine + 3*direction - from
            let target = element(app,"wire-3-segment-\(segment)")
            XCTAssertTrue(target.waitForExistence(timeout:2))
            let start = target.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            start.press(forDuration:0.2,thenDragTo:start.withOffset(horizontal ? CGVector(dx:0,dy:amount) : CGVector(dx:amount,dy:0)))

            let after = routePoints(app,3)
            guard after.count == before.count else { return XCTFail("the drag must not have reshaped the route: \(before) -> \(after)") }
            let value = horizontal ? after[segment].y : after[segment].x
            if snap {
                XCTAssertEqual(value, gridLine, accuracy: 0.5, "a \(horizontal ? "horizontal" : "vertical") segment must land on the nearest grid line: \(before) -> \(after)")
            } else {
                XCTAssertEqual(value, gridLine + 3*direction, accuracy: 1.5, "with snapping off, the segment must stay where it was released: \(before) -> \(after)")
            }
            XCTAssertEqual(after.first, before.first); XCTAssertEqual(after.last, before.last)
        }
    }

    @MainActor
    func testDraggingAWireSegmentSnapsItsSharedCoordinateToTheGridOnRelease() throws {
        dragWireSegments(snap: true, horizontal: false)
        dragWireSegments(snap: true, horizontal: true)
    }

    @MainActor
    func testDraggingAWireSegmentWithGridSnapOffKeepsTheReleasedCoordinate() throws {
        dragWireSegments(snap: false, horizontal: false)
        dragWireSegments(snap: false, horizontal: true)
    }

    /// The grid wins over step-straightening (user decision, 2026-09-29; Codex major, 5F round 2). Seed
    /// wire 2's step (x = 289 and 301, both off the grid) straightens onto 289 with snapping off
    /// (testDraggingOneSideOfAStepStraightensTheWire); with it on, the same -10pt drag - which passes within
    /// alignSnap of 289, and so straightens mid-drag - must still be released onto the grid line 285.
    @MainActor
    func testWithGridSnapOnAReleasedSegmentLandsOnTheGridNotOnAnOffGridNeighbour() throws {
        let app = makeApp(gridSnap: true); app.launch()
        let before = routePoints(app,2)
        guard before.count == 6 else { return XCTFail("wire 2 should start with a step: \(before)") }
        XCTAssertEqual(before[1].x,289); XCTAssertEqual(before[3].x,301)
        XCTAssertTrue(element(app,"wire-2-segment-3").waitForExistence(timeout:2))
        let side = element(app,"wire-2-segment-3").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        side.press(forDuration:0.2,thenDragTo:side.withOffset(CGVector(dx:-10,dy:0)))
        let after = routePoints(app,2)
        guard after.count == 6 else { return XCTFail("the dragged side must stay its own segment, on the grid: \(after)") }
        XCTAssertEqual(after[3].x,285); XCTAssertEqual(after[4].x,285)
        XCTAssertEqual(after[1].x,289,"the other, untouched side of the step stays put")
        XCTAssertEqual(after.first,before.first); XCTAssertEqual(after.last,before.last)
    }

    /// A group whose members both start off the grid (the seed "CAN" block at 620,250 and the seed note at
    /// 430,80) snaps each member to its own nearest grid point on release, keeps its external wire attached,
    /// and a single Undo restores every member - and the wire - to exactly where they were (Codex minor, 5F
    /// round 1).
    @MainActor
    func testDraggingAGroupSnapsEachMemberAndOneUndoRestoresThemAll() throws {
        let app = makeApp(gridSnap: true); app.launch()
        XCTAssertTrue(element(app,"symbol-CAN").waitForExistence(timeout:3))
        groupViaMarquee(app, from: CGVector(dx:700,dy:300), to: CGVector(dx:440,dy:60))
        let groupID = element(app,"symbol-CAN-group").value as? String ?? ""
        XCTAssertFalse(groupID.isEmpty)
        XCTAssertEqual(groupID, element(app,"experiment-note-R12を変更-group").value as? String)
        XCTAssertEqual(element(app,"symbol-Main MCU-group").value as? String, "", "Main MCU must stay outside the group")

        func position(_ value: String?) -> [Double] {
            (value ?? "").components(separatedBy: CharacterSet(charactersIn: "xy=, ")).compactMap { Double($0) }
        }
        func pin(_ title: String, _ index: Int) -> [Double] { coordinates(app.buttons["symbol-\(title)-pin-\(index)"]) }
        let note = element(app,"experiment-note-R12を変更")
        let noteBefore = position(note.value as? String), canPinBefore = pin("CAN",0), wireBefore = routePoints(app,1)
        XCTAssertFalse(onFifteenPointGrid(noteBefore[0]) && onFifteenPointGrid(noteBefore[1]), "the note must start off the grid: \(noteBefore)")

        let handle = element(app,"symbol-CAN").coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        handle.press(forDuration:0.2, thenDragTo: handle.withOffset(CGVector(dx:37,dy:23)))

        let noteAfter = position(note.value as? String), canPinAfter = pin("CAN",0)
        XCTAssertTrue(onFifteenPointGrid(noteAfter[0]) && onFifteenPointGrid(noteAfter[1]), "the note member must land on the grid: \(noteAfter)")
        XCTAssertTrue(onFifteenPointGrid(canPinAfter[0]) && onFifteenPointGrid(canPinAfter[1]), "the symbol member's pin must land on the grid: \(canPinAfter)")
        XCTAssertEqual(noteAfter[0]-noteBefore[0], 37, accuracy: 7.5); XCTAssertEqual(noteAfter[1]-noteBefore[1], 23, accuracy: 7.5)
        let wireAfter = routePoints(app,1)
        XCTAssertEqual(wireAfter.last.map { [Double($0.x),Double($0.y)] }, canPinAfter, "the external wire must stay attached to the snapped pin")
        XCTAssertEqual(wireAfter.first, wireBefore.first, "the wire's far end (Main MCU, outside the group) must not move")

        app.buttons["undo-button"].tap()
        XCTAssertEqual(position(note.value as? String), noteBefore, "one Undo must restore the note, snap included")
        XCTAssertEqual(pin("CAN",0), canPinBefore, "and the symbol, in the same single step")
        XCTAssertEqual(routePoints(app,1), wireBefore, "and the wire's route")
    }

    /// A drag refused in edit mode must not snap on release either - it would move an off-grid item (and its
    /// wires) without an Undo step (Codex major, 5F round 3).
    @MainActor
    func testARefusedDragInEditModeDoesNotSnapOnRelease() throws {
        let app = makeApp(gridSnap: true); app.launch()
        let symbol = element(app,"symbol-24 V → 5 V")
        XCTAssertTrue(symbol.waitForExistence(timeout:3))
        let pinBefore = coordinates(app.buttons["symbol-24 V → 5 V-pin-0"]), wireBefore = routePoints(app,0)
        XCTAssertFalse(onFifteenPointGrid(pinBefore[0]) && onFifteenPointGrid(pinBefore[1]), "the seed symbol must start off the grid: \(pinBefore)")
        XCTAssertFalse(app.buttons["undo-button"].isEnabled)
        app.buttons["edit-mode-toggle"].tap()
        let start = symbol.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.2,thenDragTo:start.withOffset(CGVector(dx:37,dy:23)))
        app.buttons["edit-mode-toggle"].tap()
        XCTAssertEqual(coordinates(app.buttons["symbol-24 V → 5 V-pin-0"]), pinBefore, "a refused drag must leave the symbol where it was")
        XCTAssertEqual(routePoints(app,0), wireBefore, "and its wire")
        XCTAssertFalse(app.buttons["undo-button"].isEnabled, "and add nothing to the Undo history")
    }

    // MARK: - Onboarding coachmarks (3D) and the blank, centered launch

    /// A real (unseeded) launch. `onboarding`: "reset" forgets "次回から表示しない" first (a genuine first
    /// launch); nil leaves the stored preference as it is (a later, ordinary launch).
    @MainActor private func makeOnboardingApp(onboarding: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_GRID_SNAP"] = "0"
        if let onboarding { app.launchEnvironment["UITEST_ONBOARDING"] = onboarding }
        return app
    }
    private func rect(_ value: Any?) -> CGRect? {
        var fields: [String: Double] = [:]
        for pair in (value as? String ?? "").split(separator: ";") {
            let parts = pair.split(separator: "=")
            if parts.count == 2, let number = Double(parts[1].replacingOccurrences(of: ",", with: "")) { fields[String(parts[0])] = number }
        }
        guard let x = fields["x"], let y = fields["y"], let w = fields["w"], let h = fields["h"] else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
    /// The bubble must sit right next to (above or below) the element it describes, and overlap it
    /// horizontally - or, for a target too tall to leave room on either side, sit on top of it.
    /// `expected`: the real elements (as XCUITest itself locates them) the highlight must cover - so a
    /// locator that found the wrong view cannot pass just because the bubble sits next to whatever it found.
    /// `expected` holds on-screen rects rather than elements because the canvas element reports the whole
    /// 2400x1800 canvas as its frame, not the visible viewport (see visibleCanvasRect).
    @MainActor private func assertBubbleIsNextToItsTarget(_ app: XCUIApplication, step: String, expected: [CGRect], file: StaticString = #filePath, line: UInt = #line) {
        let bubble = element(app, "coachmark").frame
        guard let target = rect(element(app, "coachmark-target").value) else {
            return XCTFail("step \(step): no highlighted target (\(String(describing: element(app, "coachmark-target").value)))", file: file, line: line)
        }
        XCTAssertFalse(expected.isEmpty, "step \(step): name the element(s) the highlight must cover", file: file, line: line)
        for frame in expected {
            XCTAssertTrue(target.insetBy(dx: -2, dy: -2).contains(frame), "step \(step): highlight \(target) must cover \(frame)", file: file, line: line)
        }
        // ...and no more than that (plus the overlay's own 6pt padding and some slack - a container's
        // accessibility frame hugs its content, e.g. the 132pt library panel reports 118.5pt), so highlighting,
        // say, the whole screen by mistake cannot pass too.
        let union = expected.reduce(CGRect.null) { $0.union($1) }
        XCTAssertLessThanOrEqual(target.width, union.width + 40, "step \(step): highlight \(target) is wider than its target \(union)", file: file, line: line)
        XCTAssertLessThanOrEqual(target.height, union.height + 40, "step \(step): highlight \(target) is taller than its target \(union)", file: file, line: line)
        XCTAssertTrue(bubble.minX < target.maxX && bubble.maxX > target.minX, "step \(step): bubble \(bubble) must overlap target \(target) horizontally", file: file, line: line)
        let gap = min(abs(bubble.minY - target.maxY), abs(target.minY - bubble.maxY))
        XCTAssertTrue(gap <= 20 || target.contains(bubble), "step \(step): bubble \(bubble) must be next to target \(target)", file: file, line: line)
        XCTAssertTrue(app.frame.contains(bubble), "step \(step): bubble \(bubble) must be fully on screen", file: file, line: line)
    }

    @MainActor
    func testLaunchStartsWithABlankCanvasCenteredInTheViewport() throws {
        let app = makeOnboardingApp(onboarding: "off"); app.launch()
        let canvas = element(app, "circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'symbol-'")).count, 0)
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'experiment-note-'")).count, 0)
        let viewport = (element(app, "viewport-size").value as? String ?? "").split(separator: ",").compactMap { Double($0) }
        let offset = (element(app, "canvas-offset-exact").value as? String ?? "").split(separator: ",").compactMap { Double($0) }
        guard viewport.count == 2, offset.count == 2 else { return XCTFail("cannot read viewport/offset") }
        // The canvas is 2400x1800 at 100%: its center (1200, 900) must be at the viewport's center.
        XCTAssertEqual(viewport[0]/2 - offset[0], 1200, accuracy: 1)
        XCTAssertEqual(viewport[1]/2 - offset[1], 900, accuracy: 1)
        XCTAssertFalse(element(app, "coachmark").exists, "UITEST_ONBOARDING=off must keep the tour away")
        assertWireCount(app, "0")
    }

    @MainActor
    func testOnboardingStartsOnFirstLaunchAndNextWalksEveryStepToTheQuestion() throws {
        let app = makeOnboardingApp(onboarding: "reset"); app.launch()
        let bubble = element(app, "coachmark")
        XCTAssertTrue(bubble.waitForExistence(timeout: 3), "O1: the tour starts by itself on a first launch")
        let titles = ["ライブラリ", "追加と配線", "キャンバス", "確認（インスペクタ）", "拡大・縮小と移動"]
        // The visible canvas: the canvas element's top-left, sized to the viewport the app reports.
        func visibleCanvasRect() -> CGRect {
            let size = (element(app, "viewport-size").value as? String ?? "").split(separator: ",").compactMap { Double($0) }
            let origin = element(app, "circuit-canvas").frame.origin
            return size.count == 2 ? CGRect(x: origin.x, y: origin.y, width: size[0], height: size[1]) : .null
        }
        let targets: [() -> [CGRect]] = [
            { [self.element(app, "library-panel").frame] },
            { [app.buttons["配線"].frame, app.buttons["＋シンボル"].frame, app.buttons["＋メモ"].frame] },
            { [visibleCanvasRect()] },
            { [app.buttons["確認"].frame] },
            { [app.buttons["zoom-menu"].frame] }
        ]
        for (index, title) in titles.enumerated() {
            let progress = element(app, "coachmark-progress")
            XCTAssertTrue(progress.waitForExistence(timeout: 2))
            XCTAssertEqual(progress.label, "\(index + 1) / \(titles.count)")
            XCTAssertEqual(element(app, "coachmark-title").label, title)
            assertBubbleIsNextToItsTarget(app, step: title, expected: targets[index]())
            XCTAssertEqual(app.buttons["coachmark-next"].label, index == titles.count - 1 ? "完了" : "次へ")
            app.buttons["coachmark-next"].tap()
        }
        XCTAssertTrue(app.alerts.buttons["次回から表示しない"].waitForExistence(timeout: 2), "O2: the question follows the last step")
        XCTAssertFalse(bubble.exists)
        app.alerts.buttons["次回も表示する"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    @MainActor
    func testOnboardingSkipAlsoAsksTheQuestion() throws {
        let app = makeOnboardingApp(onboarding: "reset"); app.launch()
        XCTAssertTrue(element(app, "coachmark").waitForExistence(timeout: 3))
        app.buttons["coachmark-next"].tap()
        XCTAssertTrue(element(app, "coachmark-progress").waitForExistence(timeout: 2))
        XCTAssertEqual(element(app, "coachmark-progress").label, "2 / 5")
        app.buttons["coachmark-skip"].tap()
        XCTAssertTrue(app.alerts.buttons["次回から表示しない"].waitForExistence(timeout: 2), "O3")
        XCTAssertFalse(element(app, "coachmark").exists)
        // While the tour runs, nothing beneath it reacts; once it is over, the canvas works again.
        app.alerts.buttons["次回も表示する"].tap()
        app.buttons["＋メモ"].tap()
        XCTAssertTrue(app.staticTexts["キャンバスをタップして付箋を配置"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDontShowAgainSurvivesARelaunchAndShowAgainDoesNot() throws {
        // "次回も表示する": the next ordinary launch shows the tour again.
        var app = makeOnboardingApp(onboarding: "reset"); app.launch()
        XCTAssertTrue(element(app, "coachmark").waitForExistence(timeout: 3))
        app.buttons["coachmark-skip"].tap()
        app.alerts.buttons["次回も表示する"].tap()
        app.terminate()
        app = makeOnboardingApp(onboarding: nil); app.launch()
        XCTAssertTrue(element(app, "coachmark").waitForExistence(timeout: 3))
        // "次回から表示しない": it does not start by itself any more (O4).
        app.buttons["coachmark-skip"].tap()
        app.alerts.buttons["次回から表示しない"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        sleep(1)   // let the preference reach disk before the process is killed
        app.terminate()
        app = makeOnboardingApp(onboarding: nil); app.launch()
        XCTAssertTrue(element(app, "circuit-canvas").waitForExistence(timeout: 3))
        XCTAssertFalse(element(app, "coachmark").waitForExistence(timeout: 2), "O4: 次回から表示しない must survive a relaunch")
    }

    @MainActor
    func testSettingsReplaysTheTourFromTheFirstStep() throws {
        let app = makeOnboardingApp(onboarding: "off"); app.launch()
        XCTAssertTrue(element(app, "circuit-canvas").waitForExistence(timeout: 3))
        XCTAssertFalse(element(app, "coachmark").exists)
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 2))
        app.buttons["settings-show-onboarding"].tap()
        XCTAssertTrue(element(app, "coachmark").waitForExistence(timeout: 3), "O5: 使い方を見る replays the tour")
        XCTAssertFalse(app.navigationBars["設定"].exists, "and closes Settings first, so the tour points at the real screen")
        XCTAssertEqual(element(app, "coachmark-progress").label, "1 / 5")
        assertBubbleIsNextToItsTarget(app, step: "replay 1", expected: [element(app, "library-panel").frame])
        app.buttons["coachmark-next"].tap()
        XCTAssertEqual(element(app, "coachmark-progress").label, "2 / 5")
        app.buttons["coachmark-skip"].tap()
        XCTAssertTrue(app.alerts.buttons["次回から表示しない"].waitForExistence(timeout: 2))
        app.alerts.buttons["次回も表示する"].tap()
    }

    // MARK: - Save / open and PDF/PNG export (MVP)

    /// UITEST_DOCUMENT_FILE: a file in the app's own temporary directory, opened at launch when it exists and
    /// otherwise this diagram's file from the start - so saving and reopening need no system file picker.
    @MainActor private func makeDocumentApp(file: String, seed: Bool) -> XCUIApplication {
        let app = makeApp()
        app.launchEnvironment["UITEST_SEED_SAMPLE"] = seed ? "1" : "0"
        app.launchEnvironment["UITEST_DOCUMENT_FILE"] = file
        return app
    }

    @MainActor private func documentState(_ app: XCUIApplication) -> String {
        element(app, "document-state").value as? String ?? ""
    }

    @MainActor private func waitForDocumentState(_ app: XCUIApplication, containing text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element(app, "document-state"))], timeout: timeout) == .completed
    }

    @MainActor private func chooseFileMenuItem(_ app: XCUIApplication, _ title: String) {
        app.buttons["file-menu"].tap()
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 2), "the file menu has no \(title)")
        item.tap()
    }

    @MainActor
    func testSaveThenReopenRestoresTheWholeDiagram() {
        let file = "save-\(UUID().uuidString).circuitcanvas"
        let app = makeDocumentApp(file: file, seed: true); app.launch()
        XCTAssertTrue(element(app, "symbol-Main MCU").waitForExistence(timeout: 3))
        XCTAssertTrue(documentState(app).hasPrefix("file=\(file);"), documentState(app))
        connectTemperatureToCAN(app)
        chooseFileMenuItem(app, "保存")
        XCTAssertTrue(waitForDocumentState(app, containing: "unsaved=0"), documentState(app))
        app.terminate()

        // Relaunched without the sample: everything on screen now comes from the file.
        let reopened = makeDocumentApp(file: file, seed: false); reopened.launch()
        for name in ["24 V → 5 V", "Main MCU", "CAN", "Temperature"] {
            XCTAssertTrue(element(reopened, "symbol-\(name)").waitForExistence(timeout: 3), "\(name) was not restored")
        }
        XCTAssertTrue(element(reopened, "wire-3").exists, "the wire added before saving was not restored")
        XCTAssertTrue(element(reopened, "experiment-note-R12を変更").exists, "the note was not restored")
        XCTAssertTrue(documentState(reopened).contains("unsaved=0"), documentState(reopened))
        assertWireCount(reopened, "4")
    }

    @MainActor
    func testEditsToASavedFileAreSavedAutomatically() {
        let file = "autosave-\(UUID().uuidString).circuitcanvas"
        let app = makeDocumentApp(file: file, seed: true); app.launch()
        XCTAssertTrue(element(app, "symbol-Main MCU").waitForExistence(timeout: 3))
        connectTemperatureToCAN(app)
        // No 保存: the change is written on its own shortly afterwards.
        XCTAssertTrue(waitForDocumentState(app, containing: "unsaved=0"), documentState(app))
        app.terminate()

        let reopened = makeDocumentApp(file: file, seed: false); reopened.launch()
        XCTAssertTrue(element(reopened, "symbol-Main MCU").waitForExistence(timeout: 3))
        XCTAssertTrue(element(reopened, "wire-3").exists, "the autosaved wire was not restored")
    }

    @MainActor
    func testNewAsksBeforeDiscardingAnUntitledDiagram() {
        let app = makeApp(); app.launch()
        XCTAssertTrue(element(app, "symbol-Main MCU").waitForExistence(timeout: 3))
        XCTAssertTrue(documentState(app).hasPrefix("file=none;unsaved=0"), documentState(app))
        connectTemperatureToCAN(app)
        XCTAssertTrue(documentState(app).contains("unsaved=1"), documentState(app))

        chooseFileMenuItem(app, "新規")
        XCTAssertTrue(app.alerts["保存されていない変更があります"].waitForExistence(timeout: 2))
        app.alerts.buttons["キャンセル"].tap()
        XCTAssertTrue(element(app, "wire-3").exists, "cancelling must keep the diagram")

        chooseFileMenuItem(app, "新規")
        XCTAssertTrue(app.alerts["保存されていない変更があります"].waitForExistence(timeout: 2))
        app.alerts.buttons["保存しないで続ける"].tap()
        XCTAssertTrue(element(app, "symbol-Main MCU").waitForNonExistence(timeout: 2), "新規 must start blank")
        XCTAssertFalse(element(app, "experiment-note-R12を変更").exists)
        XCTAssertTrue(documentState(app).hasPrefix("file=none;unsaved=0"), documentState(app))
        XCTAssertEqual(app.buttons["元に戻す"].isEnabled, false, "a new diagram has nothing to undo")
    }

    /// A Form toggle only flips when its switch itself is tapped, not the row's center.
    @MainActor private func flip(_ toggle: XCUIElement) {
        let knob = toggle.switches.firstMatch
        (knob.exists ? knob : toggle).tap()
    }

    @MainActor private func exportSummary(_ app: XCUIApplication) -> [String: String] {
        let value = element(app, "export-summary").value as? String ?? ""
        return Dictionary(uniqueKeysWithValues: value.split(separator: ";").compactMap { pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            return parts.count == 2 ? (String(parts[0]), String(parts[1])) : nil
        })
    }

    @MainActor private func waitForExportSummary(_ app: XCUIApplication, containing text: String) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element(app, "export-summary"))], timeout: 5) == .completed
    }

    @MainActor
    func testExportWritesAOnePagePDFAndA2xPNGAndHonorsTheNotesOption() {
        let app = makeApp(); app.launch()
        XCTAssertTrue(element(app, "symbol-Main MCU").waitForExistence(timeout: 3))
        chooseFileMenuItem(app, "書き出す（PDF・PNG）…")
        XCTAssertTrue(waitForExportSummary(app, containing: "format=pdf"), "no PDF was produced")
        let withNotes = exportSummary(app)
        XCTAssertEqual(withNotes["pages"], "1")
        XCTAssertTrue(element(app, "export-preview").exists)
        XCTAssertTrue(app.buttons["export-save-to-files"].isEnabled)
        let pdfWidth = Int(withNotes["width"] ?? "") ?? 0, pdfHeight = Int(withNotes["height"] ?? "") ?? 0
        // The sample spans roughly x 75-665, y 30-420 on the canvas: cropped to it, not the whole 2400x1800.
        XCTAssertTrue((600...800).contains(pdfWidth), "PDF width \(pdfWidth)")
        XCTAssertTrue((400...560).contains(pdfHeight), "PDF height \(pdfHeight)")

        // Without the note (which sits above everything else), the page is shorter.
        let toggle = app.switches["export-include-notes"]
        XCTAssertTrue(toggle.exists)
        flip(toggle)
        XCTAssertTrue(waitForExportSummary(app, containing: "format=pdf"))
        let expectation = expectation(for: NSPredicate { _, _ in
            (Int(self.exportSummary(app)["height"] ?? "") ?? .max) < pdfHeight
        }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed, "\(self.exportSummary(app))")

        // PNG: the same area, at 2x.
        flip(toggle)
        app.segmentedControls["export-format"].buttons["PNG"].tap()
        XCTAssertTrue(waitForExportSummary(app, containing: "format=png"))
        let png = exportSummary(app)
        XCTAssertEqual(Int(png["width"] ?? ""), pdfWidth * 2)
        XCTAssertEqual(Int(png["height"] ?? ""), pdfHeight * 2)
        app.buttons["export-close"].tap()
        XCTAssertTrue(element(app, "export-summary").waitForNonExistence(timeout: 2))
    }

    @MainActor
    func testExportOfABlankCanvasIsRefused() {
        let app = makeApp()
        app.launchEnvironment["UITEST_SEED_SAMPLE"] = "0"
        app.launch()
        chooseFileMenuItem(app, "書き出す（PDF・PNG）…")
        XCTAssertTrue(waitForExportSummary(app, containing: "empty"), "a blank canvas must not produce a file")
        XCTAssertTrue(app.staticTexts["キャンバスに何も配置されていないため、書き出せません。"].exists)
        XCTAssertFalse(app.buttons["export-save-to-files"].isEnabled)
        XCTAssertFalse(app.buttons["export-share"].exists)
    }

    // MARK: - Pinch-to-zoom sensitivity (feedback, 2026-10-03)

    /// A pinch zooms gently (damped, never straight to a limit) and around the point between the fingers.
    /// XCUITest's pinch is centered on the element, here the whole viewport, so the canvas point at the
    /// viewport's center must stay there.
    @MainActor
    func testPinchZoomsGentlyAroundTheFingers() {
        let app = makeApp(); app.launch()
        let canvas = element(app, "circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        func scale() -> Double { Double(element(app, "zoom-scale-exact").value as? String ?? "") ?? .nan }
        func offset() -> (x: Double, y: Double) {
            let parts = (element(app, "canvas-offset-exact").value as? String ?? "").split(separator: ",").compactMap { Double($0) }
            return parts.count == 2 ? (parts[0], parts[1]) : (.nan, .nan)
        }
        let size = (element(app, "viewport-size").value as? String ?? "").split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(size.count, 2)
        let center = (x: size[0] / 2, y: size[1] / 2)
        func canvasPointAtCenter() -> (x: Double, y: Double) {
            let s = scale(), o = offset()
            return ((center.x - o.x) / s, (center.y - o.y) / s)
        }
        XCTAssertEqual(scale(), 1, accuracy: 0.0001)
        let before = canvasPointAtCenter()

        canvas.pinch(withScale: 2, velocity: 1)
        let zoomedIn = scale()
        XCTAssertGreaterThan(zoomedIn, 1.15, "the pinch did not zoom in")
        XCTAssertLessThan(zoomedIn, 1.9, "spreading the fingers to twice their distance must zoom well under 2x")
        let afterIn = canvasPointAtCenter()
        XCTAssertEqual(afterIn.x, before.x, accuracy: 20, "the zoom must stay centered on the fingers")
        XCTAssertEqual(afterIn.y, before.y, accuracy: 20, "the zoom must stay centered on the fingers")

        canvas.pinch(withScale: 0.5, velocity: -1)
        let zoomedOut = scale()
        XCTAssertLessThan(zoomedOut, zoomedIn - 0.15, "the pinch did not zoom out")
        XCTAssertGreaterThan(zoomedOut, 0.5, "pinching to half the distance must not drop straight to the minimum")
        let afterOut = canvasPointAtCenter()
        XCTAssertEqual(afterOut.x, before.x, accuracy: 20, "zooming out must stay centered on the fingers too")
        XCTAssertEqual(afterOut.y, before.y, accuracy: 20, "zooming out must stay centered on the fingers too")
    }

    /// A pinch over the gray margin outside the canvas zooms around a point that is not on the canvas, which
    /// can push the canvas itself off screen while the fingers are down. Once they lift, the canvas is brought
    /// back to where the usual pan margin keeps at least 200pt of it visible (Codex, pinch round 3).
    @MainActor
    func testPinchingOverTheMarginLeavesTheCanvasOnScreen() {
        let app = makeApp(); app.launch()
        let canvas = element(app, "circuit-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        func scale() -> Double { Double(element(app, "zoom-scale-exact").value as? String ?? "") ?? .nan }
        func offsetX() -> Double {
            Double((element(app, "canvas-offset-exact").value as? String ?? "").split(separator: ",").first ?? "") ?? .nan
        }
        // Pan as far left as the pan margin allows: the canvas's right edge ends up 200pt from the left, so the
        // viewport's center (where XCUITest pinches) is over the gray margin.
        app.buttons["pan-mode-toggle"].tap()
        for _ in 0..<5 {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)))
        }
        XCTAssertEqual(offsetX(), 200 - 2400, accuracy: 1, "the pan should have stopped at the margin")

        canvas.pinch(withScale: 2, velocity: 1)
        let s = scale()
        XCTAssertGreaterThan(s, 1.15, "the pinch did not zoom in")
        // Zooming in around a point beyond the canvas's right edge pushes that edge left of the margin while
        // pinching; after release it must be back at (at least) the margin.
        XCTAssertGreaterThanOrEqual(offsetX(), 200 - 2400 * s - 1, "the canvas was left (partly) off screen after the pinch")
    }
}

