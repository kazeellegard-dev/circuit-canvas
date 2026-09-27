import Testing
import SwiftUI
@testable import CircuitCanvas

struct CircuitSymbolTests {
    private func rotate(_ point: CGPoint, _ rotation: Int) -> CGPoint {
        switch rotation {
        case 90: CGPoint(x:-point.y,y:point.x)
        case 180: CGPoint(x:-point.x,y:-point.y)
        case 270: CGPoint(x:point.y,y:-point.x)
        default: point
        }
    }

    /// Every kind, every rotation: pins are the unrotated pin list turned clockwise around the centre,
    /// they sit on the edge of the body and lead outward, and neighbouring pins are far enough apart.
    @Test func pinsBodyAndOutwardDirectionsForEveryKindAndRotation() {
        let center = CGPoint(x:300,y:200)
        for kind in SymbolKind.allCases {
            #expect(kind.pinCount == kind.pinSpecs.count && kind.pinCount >= 1)
            if kind.isBlock {
                #expect(kind.frameSize == CGSize(width:90,height:30))
                #expect(kind.pins(at:center) == [CGPoint(x:255,y:200),CGPoint(x:345,y:200)])
                #expect(kind.pins(at:center,rotation:90) == kind.pins(at:center))
                continue
            }
            let frame = kind.frameSize
            for rotation in [0,90,180,270] {
                let pins = kind.pins(at:center,rotation:rotation)
                let body = kind.body(at:center,rotation:rotation)
                #expect(body.midX == center.x && body.midY == center.y)
                #expect(body.size == (rotation % 180 == 0 ? frame : CGSize(width:frame.height,height:frame.width)))
                for (index,spec) in kind.pinSpecs.enumerated() {
                    let turned = rotate(spec.offset,rotation)
                    #expect(pins[index] == CGPoint(x:center.x+turned.x,y:center.y+turned.y), "\(kind) pin \(index) at \(rotation)")
                    let direction = kind.direction(for:index,rotation:rotation)
                    #expect(direction.rawValue == (spec.direction.rawValue + rotation/90) % 4)
                    // Pin on the body edge, lead pointing away from the body.
                    let vector = direction.vector
                    let onEdge = vector.x != 0
                        ? abs(pins[index].x-center.x) == body.width/2 && (pins[index].x-center.x)*vector.x > 0
                        : abs(pins[index].y-center.y) == body.height/2 && (pins[index].y-center.y)*vector.y > 0
                    #expect(onEdge, "\(kind) pin \(index) at \(rotation)")
                }
                for i in pins.indices { for j in pins.indices where j > i {
                    #expect(hypot(pins[i].x-pins[j].x,pins[i].y-pins[j].y) >= 30, "\(kind) pins \(i),\(j) at \(rotation)")
                } }
            }
        }
    }

    @Test func twoTerminalAndSingleTerminalSymbolsKeepTheirOriginalPinOrder() {
        let center = CGPoint(x:300,y:200)
        for kind in SymbolKind.allCases where !kind.isBlock && kind.frameSize == CGSize(width:60,height:30) {
            #expect(kind.pinCount == (kind == .ground || kind == .vcc ? 1 : 2), "\(kind)")
            for rotation in [0,90,180,270] {
                let pins = kind.pins(at:center,rotation:rotation)
                let first = [CGPoint(x:270,y:200),CGPoint(x:300,y:170),CGPoint(x:330,y:200),CGPoint(x:300,y:230)][rotation/90]
                #expect(pins[0] == first)
                #expect(kind.direction(for:0,rotation:rotation).rawValue == rotation/90)
                if pins.count == 2 {
                    #expect(pins[1] == CGPoint(x:600-first.x,y:400-first.y))
                    #expect(kind.direction(for:1,rotation:rotation).rawValue == (rotation/90+2)%4)
                }
            }
        }
    }

    @Test func multiTerminalPinLayoutsMatchTheSpecification() {
        typealias Layout = [(name: String, x: CGFloat, y: CGFloat)]
        let transistor: Layout = [("B",-30,0),("C",15,-30),("E",15,30)]
        let logic2: Layout = [("IN1",-30,-15),("IN2",-30,15),("OUT",30,0)]
        let expected: [SymbolKind: (size: CGSize, pins: Layout)] = [
            .npn: (CGSize(width:60,height:60), transistor), .pnp: (CGSize(width:60,height:60), transistor),
            .nmos: (CGSize(width:60,height:60), [("G",-30,0),("D",15,-30),("S",15,30)]),
            .pmos: (CGSize(width:60,height:60), [("G",-30,0),("D",15,-30),("S",15,30)]),
            .opAmp: (CGSize(width:60,height:60), [("IN+",-30,-15),("IN−",-30,15),("OUT",30,0)]),
            .andGate: (CGSize(width:60,height:60), logic2), .orGate: (CGSize(width:60,height:60), logic2),
            .nandGate: (CGSize(width:60,height:60), logic2), .norGate: (CGSize(width:60,height:60), logic2),
            .xorGate: (CGSize(width:60,height:60), logic2),
            .notGate: (CGSize(width:60,height:60), [("IN",-30,0),("OUT",30,0)]),
            .relay: (CGSize(width:60,height:60), [("コイルA",-15,-30),("コイルB",-15,30),("COM",15,-30),("NO",15,30)]),
            .connector: (CGSize(width:60,height:120), [("P1",-30,-45),("P2",-30,-15),("P3",-30,15),("P4",-30,45)])
        ]
        #expect(expected.count == 13)
        let center = CGPoint(x:500,y:400)
        for (kind,spec) in expected {
            #expect(kind.frameSize == spec.size, "\(kind)")
            #expect(kind.defaultRotation == 0)
            #expect(kind.pinCount == spec.pins.count, "\(kind)")
            let pins = kind.pins(at:center)
            for (index,pin) in spec.pins.enumerated() {
                #expect(pins[index] == CGPoint(x:500+pin.x,y:400+pin.y), "\(kind) \(pin.name)")
                #expect(kind.pinSpecs[index].name.hasPrefix(pin.name), "\(kind) \(pin.name)")
            }
        }
        // A quarter turn clockwise sends the transistor's base (left) to the top.
        #expect(SymbolKind.npn.pins(at:center,rotation:90)[0] == CGPoint(x:500,y:370))
    }

    @Test func defaultPowerOrientationsAndUprightLetters() {
        for kind in SymbolKind.allCases {
            #expect(kind.defaultRotation == (kind == .vcc ? 270 : kind.category == .power ? 90 : 0))
        }
        #expect(SymbolKind.motor.letter == "M")
        #expect(SymbolKind.voltmeter.letter == "V")
        #expect(SymbolKind.ammeter.letter == "A")
    }

    @Test func catalogueCategoriesAndVectorGeometry() {
        #expect(SymbolKind.allCases.count == 37)
        #expect(SymbolKind.allCases.filter(\.isBlock).count == 1)
        let counts = Dictionary(grouping:SymbolKind.allCases,by:\.category).mapValues(\.count)
        #expect(counts[.semiconductor] == 9 && counts[.logic] == 6 && counts[.relayConnector] == 2)
        #expect(counts[.power] == 5 && counts[.passive] == 5 && counts[.protection] == 3 && counts[.load] == 6)
        for kind in SymbolKind.allCases where !kind.isBlock {
            let design = kind.designSize
            let path = CircuitSymbolShape(kind:kind).path(in:CGRect(origin:.zero,size:design))
            #expect(!path.isEmpty)
            #expect(path.boundingRect.minX >= 0 && path.boundingRect.maxX <= design.width, "\(kind)")
            #expect(path.boundingRect.minY >= 0 && path.boundingRect.maxY <= design.height, "\(kind)")
            #expect(kind.libraryScale > 0 && kind.libraryScale <= 1)
        }
    }

    /// Every pin needs a drawn lead: a line ending exactly on the pin position in design space.
    @Test func multiTerminalShapesReachEveryPin() {
        for kind in SymbolKind.allCases where !kind.isBlock && !kind.usesAxisLeads {
            let design = kind.designSize, frame = kind.frameSize
            let path = CircuitSymbolShape(kind:kind).path(in:CGRect(origin:.zero,size:design))
            var endpoints: [CGPoint] = []
            path.forEach { element in
                switch element {
                case .move(to: let point), .line(to: let point), .curve(to: let point, control1: _, control2: _),
                     .quadCurve(to: let point, control: _): endpoints.append(point)
                default: break
                }
            }
            for spec in kind.pinSpecs {
                // Pin offset (centre origin, frame units) -> design coordinates.
                let x = (spec.offset.x + frame.width/2) * design.width/frame.width
                let y = (spec.offset.y + frame.height/2) * design.height/frame.height
                #expect(endpoints.contains { abs($0.x-x) < 0.001 && abs($0.y-y) < 0.001 }, "\(kind) \(spec.name)")
            }
        }
    }

    @Test func externalLeadsAreFifteenPointsExceptNarrowPlateSymbols() {
        let plates: Set<SymbolKind> = [.dc, .battery, .capacitor, .polarizedCapacitor, .diode, .led, .zener, .photodiode]
        for kind in SymbolKind.allCases where !kind.isBlock && kind.usesAxisLeads && kind.pinCount == 2 {
            let path = CircuitSymbolShape(kind:kind).path(in:CGRect(x:0,y:0,width:100,height:50))
            var previous = CGPoint.zero
            var lengths: [CGFloat] = []
            path.forEach { element in
                switch element {
                case .move(to: let point): previous = point
                case .line(to: let point):
                    if abs(previous.y-25) < 0.001 && abs(point.y-25) < 0.001 &&
                        (abs(previous.x) < 0.001 || abs(point.x-100) < 0.001) { lengths.append(abs(point.x-previous.x)) }
                    previous = point
                default: break
                }
            }
            #expect(lengths.count == 2)
            // Design space is drawn at 60 %: 25 design points are the 15 pt lead. Plate and diode
            // bodies are narrower, so their leads are longer (25...45 design points).
            #expect(lengths.allSatisfy { plates.contains(kind) ? ($0 >= 25 && $0 <= 45) : abs($0-25) < 0.001 })
        }
    }

    @Test func plateSymbolsKeepTheirPlatesClose() {
        // Regression: plates once drifted ~40pt apart and read as two separate parts.
        for kind in [SymbolKind.dc, .capacitor, .polarizedCapacitor] {
            let path = CircuitSymbolShape(kind:kind).path(in:CGRect(x:0,y:0,width:100,height:50))
            var previous = CGPoint.zero
            var plateXs: [CGFloat] = []
            path.forEach { element in
                switch element {
                case .move(to: let point): previous = point
                case .line(to: let point):
                    if abs(previous.x-point.x) < 0.001 && abs(previous.y-point.y) > 10 { plateXs.append(point.x) }
                    previous = point
                default: break
                }
            }
            #expect(plateXs.count == 2)
            #expect((plateXs.max() ?? 0) - (plateXs.min() ?? 0) <= 16)
        }
    }

    /// Regression (Codex review): a wire end used to be re-matched against the remaining old pins after
    /// it had been moved, so moving a connector by one pin pitch sent P1's wire on to P4.
    @Test func wireEndsFollowTheirOwnPinWhenNewPinsCoincideWithOldOnes() {
        let connector = SymbolKind.connector
        let old = connector.pins(at:CGPoint(x:300,y:200))
        let moved = connector.pins(at:CGPoint(x:300,y:230))            // exactly one pitch down
        for index in old.indices {
            #expect(SymbolKind.remapped(old[index],from:old,to:moved) == moved[index], "P\(index+1)")
        }
        // Two-terminal symbol shifted by its own pin distance: pin 0 lands on the old pin 1.
        let resistor = SymbolKind.resistor
        let before = resistor.pins(at:CGPoint(x:300,y:200)), after = resistor.pins(at:CGPoint(x:360,y:200))
        #expect(SymbolKind.remapped(before[0],from:before,to:after) == after[0])
        #expect(SymbolKind.remapped(before[1],from:before,to:after) == after[1])
        #expect(SymbolKind.remapped(CGPoint(x:1,y:1),from:before,to:after) == nil)
    }

    // MARK: block resizing

    @Test func blockSizesSnapToThirtyPointStepsWithinLimits() {
        typealias Size = CGSize
        #expect(BlockSize.standard == Size(width:90,height:30))
        #expect(BlockSize.snapped(Size(width:90,height:30)) == Size(width:90,height:30))
        #expect(BlockSize.snapped(Size(width:104,height:44)) == Size(width:90,height:30))     // rounds down
        #expect(BlockSize.snapped(Size(width:106,height:46)) == Size(width:120,height:60))     // rounds up
        #expect(BlockSize.snapped(Size(width:1000,height:1000)) == Size(width:300,height:180)) // maximum
        #expect(BlockSize.snapped(Size(width:-50,height:0)) == Size(width:90,height:30))       // minimum
        for width in stride(from:0.0,through:400.0,by:7.0) { for height in stride(from:0.0,through:250.0,by:7.0) {
            let size = BlockSize.snapped(Size(width:width,height:height))
            #expect(size.height.truncatingRemainder(dividingBy:30) == 0 && size.height >= 30 && size.height <= 180)
            #expect(size.width.truncatingRemainder(dividingBy:30) == 0 && size.width >= 90 && size.width <= 300)
        } }
    }

    @Test func draggingACornerKeepsTheOppositeCornerFixed() {
        let center = CGPoint(x:370,y:250), size = BlockSize.standard        // top-left (325,235), bottom-right (415,265)
        func corners(_ c: CGPoint, _ s: CGSize) -> (CGPoint,CGPoint) { (CGPoint(x:c.x-s.width/2,y:c.y-s.height/2),CGPoint(x:c.x+s.width/2,y:c.y+s.height/2)) }
        let br = BlockSize.resized(center:center,size:size,sx:1,sy:1,translation:CGSize(width:60,height:60))
        #expect(br.size == CGSize(width:150,height:90))
        #expect(corners(br.center,br.size).0 == CGPoint(x:325,y:235))
        let tl = BlockSize.resized(center:br.center,size:br.size,sx:-1,sy:-1,translation:CGSize(width:-30,height:-30))
        #expect(tl.size == CGSize(width:180,height:120))
        #expect(corners(tl.center,tl.size).1 == corners(br.center,br.size).1)
        let tr = BlockSize.resized(center:center,size:size,sx:1,sy:-1,translation:CGSize(width:30,height:-30))
        #expect(corners(tr.center,tr.size).0.x == 325 && corners(tr.center,tr.size).1.y == 265)
        // Dragging past the limit stops at the limit and the fixed corner still holds.
        let huge = BlockSize.resized(center:center,size:size,sx:1,sy:1,translation:CGSize(width:900,height:900))
        #expect(huge.size == CGSize(width:300,height:180) && corners(huge.center,huge.size).0 == CGPoint(x:325,y:235))
        // A drag too small to reach the next step changes nothing.
        let none = BlockSize.resized(center:center,size:size,sx:1,sy:1,translation:CGSize(width:10,height:10))
        #expect(none.size == size && none.center == center)
    }

    @Test func blockPinsUseTheFirstRowSlotAndBodiesFollowTheSize() {
        let center = CGPoint(x:400,y:300)
        for kind in SymbolKind.allCases where kind.isBlock {
            #expect(kind.pins(at:center,size:BlockSize.standard) == [CGPoint(x:355,y:300),CGPoint(x:445,y:300)])
            let size = CGSize(width:150,height:90)
            let body = kind.body(at:center,rotation:0,size:size)
            #expect(body == CGRect(x:325,y:255,width:150,height:90))
            let pins = kind.pins(at:center,size:size)
            #expect(pins == [CGPoint(x:325,y:270),CGPoint(x:475,y:270)])          // top + 15, on the left / right edges
            #expect(pins.allSatisfy { $0.y > body.minY && $0.y < body.maxY })
        }
        // Circuit symbols ignore any size.
        #expect(SymbolKind.resistor.pins(at:center,size:CGSize(width:300,height:180)) == SymbolKind.resistor.pins(at:center))
    }

    /// Corner handles stay >= 32pt on screen and clear of the pins' 28pt squares at every zoom (Codex review).
    @Test func resizeHandlesAreFingerSizedAndClearOfPinsAtEveryZoom() {
        let center = CGPoint(x:400,y:300)
        for size in [CGSize(width:90,height:30),CGSize(width:150,height:90),CGSize(width:300,height:180)] {
            let body = SymbolKind.block.body(at:center,rotation:0,size:size)
            let pins = SymbolKind.block.pins(at:center,size:size)
            let pinSquares = pins.map { CGRect(x:$0.x-14,y:$0.y-14,width:28,height:28) }
            for scale in [CGFloat(0.5),0.75,1,1.5,2.5] {
                var squares: [CGRect] = []
                for (sx,sy) in [(-1.0,-1.0),(1,-1),(-1,1),(1,1)] {
                    let rect = BlockSize.handleRect(body:body,sx:CGFloat(sx),sy:CGFloat(sy),scale:scale)
                    #expect(rect.width * scale >= 32 - 0.001 && rect.height * scale >= 32 - 0.001, "scale \(scale)")
                    #expect(pinSquares.allSatisfy { !$0.intersects(rect) }, "\(size) scale \(scale) corner \(sx),\(sy)")
                    #expect(!body.insetBy(dx:1,dy:1).intersects(rect))        // outside the block itself
                    squares.append(rect)
                }
                for i in squares.indices { for j in squares.indices where j > i { #expect(!squares[i].intersects(squares[j]), "handles overlap at scale \(scale)") } }
            }
        }
    }

    /// The rotate/relate canvas buttons use this to stay >= 32pt on screen below 100% zoom (Codex review: a live
    /// pinch-based UI check of this could not be trusted, since XCUITest's synthetic pinch turned out to be
    /// unreliable in this harness - it sometimes lands as a plain pan and never changes the reported scale at all).
    @Test func screenConstantGrowsBelowFullZoomAndNeverShrinksAboveIt() {
        #expect(ResizableGeometry.screenConstant(32, scale: 1) == 32)
        #expect(ResizableGeometry.screenConstant(32, scale: 0.5) == 64)
        #expect(ResizableGeometry.screenConstant(32, scale: 0.25) == 128)
        #expect(ResizableGeometry.screenConstant(32, scale: 2) == 32)     // zoomed in: never smaller than the base
        #expect(ResizableGeometry.screenConstant(24, scale: 0.5) == 48)
    }

    /// The zoom menu (4E) must keep the same canvas point centered in the viewport across a scale change,
    /// even when the current pan is already using part of boundedCanvasOffset's edge margin - which is
    /// exactly why this must NOT be run through boundedCanvasOffset (Codex major, 4E round 1: applying that
    /// clamp moved the center whenever the pan was already near an edge).
    @Test func canvasZoomKeepsTheViewportCenterOnTheSameCanvasPointEvenWhenPannedNearAnEdge() {
        let viewport = CGSize(width: 1000, height: 800)
        func canvasCenter(_ offset: CGSize, _ scale: CGFloat) -> CGPoint {
            CGPoint(x: (viewport.width/2 - offset.width) / scale, y: (viewport.height/2 - offset.height) / scale)
        }
        // Codex's own example: offsetX 800 at scale 1 puts the center at canvas x = -300 - already past what
        // boundedCanvasOffset would allow if it were (wrongly) reapplied for a scale-only change.
        let oldOffset = CGSize(width: 800, height: 300), oldScale: CGFloat = 1, newScale: CGFloat = 2
        let newOffset = CanvasZoom.offset(oldOffset: oldOffset, oldScale: oldScale, newScale: newScale, viewportSize: viewport)
        #expect(abs(newOffset.width - 1100) < 0.001)
        let before = canvasCenter(oldOffset, oldScale), after = canvasCenter(newOffset, newScale)
        #expect(abs(before.x - after.x) < 0.001)
        #expect(abs(before.y - after.y) < 0.001)
        // Also holds shrinking, and from/to fractional (pinch-reached) scales, not just menu presets.
        for (o,s,n) in [(CGSize(width:-400,height:-250),CGFloat(1.5),CGFloat(0.5)),
                        (CGSize(width:120,height:-80),CGFloat(0.73),CGFloat(1))] {
            let newO = CanvasZoom.offset(oldOffset:o, oldScale:s, newScale:n, viewportSize:viewport)
            let b = canvasCenter(o,s), a = canvasCenter(newO,n)
            #expect(abs(b.x - a.x) < 0.001); #expect(abs(b.y - a.y) < 0.001)
        }
    }

    // MARK: block pin addition (3C)

    @Test func blockPinSlotsCoverOneLeftAndRightPerThirtyPointRow() {
        #expect(SymbolKind.blockPinSlots(height:30) == [.init(side:.left,slot:0),.init(side:.right,slot:0)])
        #expect(SymbolKind.blockPinSlots(height:90) == [.init(side:.left,slot:0),.init(side:.right,slot:0),
                                                         .init(side:.left,slot:1),.init(side:.right,slot:1),
                                                         .init(side:.left,slot:2),.init(side:.right,slot:2)])
        #expect(SymbolKind.defaultBlockPins == [.init(side:.left,slot:0),.init(side:.right,slot:0)])
    }

    @Test func addedBlockPinsSitOnTheirRowAndLeadOutward() {
        let center = CGPoint(x:400,y:300)
        let pins: [SymbolKind.BlockPin] = [.init(side:.left,slot:0),.init(side:.right,slot:0),
                                            .init(side:.left,slot:1),.init(side:.right,slot:2)]
        let size = CGSize(width:90,height:90)   // 3 rows
        let positions = SymbolKind.block.pins(at:center,size:size,blockPins:pins)
        let body = SymbolKind.block.body(at:center,rotation:0,size:size)
        #expect(positions[0] == CGPoint(x:body.minX,y:body.minY+15))
        #expect(positions[1] == CGPoint(x:body.maxX,y:body.minY+15))
        #expect(positions[2] == CGPoint(x:body.minX,y:body.minY+45))     // row 1
        #expect(positions[3] == CGPoint(x:body.maxX,y:body.minY+75))     // row 2
        for (index,pin) in pins.enumerated() {
            #expect(SymbolKind.block.direction(for:index,rotation:0,blockPins:pins) == pin.direction)
        }
        // Every added pin sits on the body edge and is at least 30pt from every other pin (Codex-review pattern
        // from the multi-terminal task: adjacent pins must not share a tap target).
        for i in positions.indices { for j in positions.indices where j > i {
            #expect(hypot(positions[i].x-positions[j].x,positions[i].y-positions[j].y) >= 30)
        } }
    }

    /// The "+" indicator (fixed 26pt, offset 2pt outside the pin column) must clear a same-row pin's 28pt square,
    /// an adjacent row's, and every resize handle - at every zoom the app allows (0.5x...2.5x). Mirrors the
    /// geometry ContentView.swift computes for the "+" buttons and resize handles.
    @Test func addPinIndicatorNeverOverlapsAPinOrAResizeHandleAtAnyZoom() {
        let plusSide: CGFloat = 26
        func plusRect(edgeX: CGFloat, y: CGFloat, outward: CGFloat) -> CGRect {
            CGRect(x: edgeX+outward-plusSide/2, y: y-plusSide/2, width: plusSide, height: plusSide)
        }
        for size in [CGSize(width:90,height:60), CGSize(width:90,height:90), CGSize(width:150,height:180)] {
            let body = SymbolKind.block.body(at:.zero, rotation:0, size:size)
            let occupied: [SymbolKind.BlockPin] = [.init(side:.left,slot:0),.init(side:.right,slot:0)]
            let occupiedPositions = Set(SymbolKind.block.pins(at:.zero,size:size,blockPins:occupied).map { "\($0.x),\($0.y)" })
            let open = SymbolKind.blockPinSlots(height:size.height).filter { !occupied.contains($0) }
            var plusRects: [CGRect] = []
            for slot in open {
                let y = body.minY + 15 + CGFloat(slot.slot)*30
                let plus = plusRect(edgeX: slot.side == .left ? body.minX : body.maxX, y: y, outward: slot.side == .left ? -(plusSide/2+2) : (plusSide/2+2))
                for other in plusRects { #expect(!plus.intersects(other), "size \(size) slot \(slot) vs another + indicator") }
                plusRects.append(plus)
                // Every ALREADY-OCCUPIED pin (the slot this "+" offers is, by definition, still empty, so its own
                // eventual pin can never coexist with it on screen - that comparison would not be a real conflict).
                for pinY in stride(from: body.minY+15, through: body.maxY-15, by: 30) {
                    let pinX = slot.side == .left ? body.minX : body.maxX
                    guard occupiedPositions.contains("\(pinX),\(pinY)") else { continue }
                    let pinRect = CGRect(x:pinX-14,y:pinY-14,width:28,height:28)
                    #expect(!plus.intersects(pinRect), "size \(size) slot \(slot) vs pin row at \(pinY)")
                }
                // Every resize handle, at the zoom extremes the app allows.
                for scale in [CGFloat(0.5), 1, 2.5] {
                    for (sx,sy) in [(-1.0,-1.0),(1,-1),(-1,1),(1,1)] {
                        let handle = BlockSize.handleRect(body: body, sx: CGFloat(sx), sy: CGFloat(sy), scale: scale)
                        #expect(!plus.intersects(handle), "size \(size) slot \(slot) vs handle \(sx),\(sy) at scale \(scale)")
                    }
                }
            }
        }
    }

    // MARK: minimum block height respects added pins

    @Test func minimumBlockHeightGrowsWithTheDeepestAddedPin() {
        #expect(BlockSize.minimumHeight(for: SymbolKind.defaultBlockPins) == 30)
        #expect(BlockSize.minimumHeight(for: SymbolKind.defaultBlockPins + [.init(side:.left,slot:2)]) == 90)
        #expect(BlockSize.minimumHeight(for: SymbolKind.defaultBlockPins + [.init(side:.right,slot:1)]) == 60)
        #expect(BlockSize.minimumHeight(for: []) == BlockSize.minimum.height,"an empty pin list still respects the standard minimum")
    }
}
