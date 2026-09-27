import Foundation
import CoreGraphics

import Testing
@testable import CircuitCanvas

@MainActor
struct WireRoutingTests {
    let centers: [CGPoint] = [.init(x:120,y:160),.init(x:370,y:250),.init(x:620,y:250),.init(x:120,y:390)]
    var bodies: [CGRect] { centers.map { CGRect(x:$0.x-45,y:$0.y-15,width:90,height:30) } }
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x:x,y:y) }

    @Test func initialAndRequestedRoutesAvoidBodiesAndOverlaps() {
        let pairs = [(p(165,160),p(325,250)),(p(415,250),p(575,250)),(p(165,390),p(325,250)),(p(165,390),p(575,250)),(p(165,390),p(415,250)),(p(75,160),p(325,250))]
        for shift in [CGFloat(0),48] {
            var obstacles = bodies
            obstacles[1] = obstacles[1].offsetBy(dx:shift,dy:shift)
            var routes: [[CGPoint]] = []
            for (originalStart,originalEnd) in pairs {
                func shifted(_ pin: CGPoint) -> CGPoint { pin == p(325,250) || pin == p(415,250) ? p(pin.x+shift,pin.y+shift) : pin }
                let start = shifted(originalStart), end = shifted(originalEnd)
                let path = WireRouting.route(.init(start:start,end:end),bodies:obstacles,occupied:routes)
                #expect(path.count >= 2)
                guard path.count >= 2 else { continue }
                #expect(path.first == start && path.last == end)
                for (a,b) in WireRouting.segments(path) {
                    #expect(a.x == b.x || a.y == b.y)
                    #expect(!obstacles.contains { WireRouting.intersectsInterior(a,b,$0) })
                    for other in routes {
                        for (c,d) in WireRouting.segments(other) where WireRouting.overlap(a,b,c,d) {
                            let shared: [CGPoint] = [start,end]
                            let allowed = shared.contains { pin in (pin == other.first || pin == other.last) && (a == pin || b == pin) && (c == pin || d == pin) }
                            #expect(allowed)
                        }
                    }
                }
                for (pin,next) in [(start,path[1]),(end,path[path.count-2])] {
                    let left = obstacles.contains { $0.minX == pin.x && $0.midY == pin.y }
                    #expect(pin.y == next.y)
                    #expect(left ? next.x < pin.x : next.x > pin.x)
                    #expect(abs(next.x-pin.x) >= 24)
                }
                let padded = WireRouting.routingBounds(obstacles)
                for (a,b) in WireRouting.segments(path).dropFirst().dropLast() {
                    #expect(!padded.contains { WireRouting.intersectsInterior(a,b,$0) })
                }
                routes.append(path)
            }
        }
    }

    @Test func closeBodiesUseHalfGapForLeadsAndClearance() {
        let obstacles = [CGRect(x:0,y:0,width:150,height:64),CGRect(x:180,y:0,width:150,height:64)]
        let bounds = WireRouting.routingBounds(obstacles)
        #expect(bounds[0].maxX == 165 && bounds[1].minX == 165)
        let path = WireRouting.route(.init(start:p(150,32),end:p(180,32)),bodies:obstacles,occupied:[])
        #expect(path == [p(150,32),p(180,32)])
        let around = WireRouting.route(.init(start:p(150,32),end:p(330,32)),bodies:obstacles,occupied:[])
        #expect(around[1] == p(165,32))
        #expect(WireRouting.segments(around).dropFirst().dropLast().allSatisfy { a,b in
            !bounds.contains { WireRouting.intersectsInterior(a,b,$0) }
        })
        let stacked = WireRouting.routingBounds([obstacles[0],obstacles[0].offsetBy(dx:0,dy:80)])
        #expect(stacked[0].maxY == 72 && stacked[1].minY == 72)
    }

    @Test func junctionsDeduplicateMultipleBranchesAndExcludePinsAndCrossings() {
        let a = [p(0,0),p(40,0),p(40,60),p(100,60)]
        let b = [p(0,0),p(20,0),p(20,80),p(100,80)]
        let c = [p(0,0),p(60,0),p(60,100),p(100,100)]
        #expect(WireRouting.junctions([a,b,c]) == [p(20,0),p(40,0)])
        #expect(WireRouting.junctions([a,b,c,Array(b.reversed())]) == [p(20,0),p(40,0)])
        #expect(WireRouting.junctions([a,[p(0,0),p(0,80),p(100,80)]]).isEmpty)
        #expect(WireRouting.junctions([a,[p(20,-20),p(20,20)]]).isEmpty)
        #expect(WireRouting.junctions([a,a]).isEmpty)
        let split = [p(0,0),p(10,0),p(20,0),p(20,80)]
        #expect(WireRouting.junctions([a,split]) == [p(20,0)])
        #expect(WireRouting.junctions([a,[p(0,0),p(10,0),p(10,0),p(20,0),p(20,80)]]) == [p(20,0)])
    }

    @Test func segmentDragIsPerpendicularAttachedAndCannotTunnelThroughBody() {
        let path = [p(165,160),p(245,160),p(245,250),p(325,250)]
        let moved = WireRouting.moved(path,segment:1,delta:200,bodies:bodies)
        #expect(moved[1].x <= 325 && moved[1].x > 324.99)
        #expect(moved.first == path.first && moved.last == path.last)
        #expect(moved[1].y == 160 && moved[2].y == 250)
        #expect(moved[1].x == moved[2].x)
        let horizontal = [p(0,0),p(20,0),p(20,80),p(100,80),p(100,100),p(120,100)]
        let h = WireRouting.moved(horizontal,segment:2,delta:30,bodies:[])
        // 80 + 30 = 110 is within the snap distance of the line at y = 100 below it: it lands on that line,
        // and the step it formed disappears.
        #expect(h == [p(0,0),p(20,0),p(20,100),p(120,100)])
        let free = WireRouting.moved(horizontal,segment:2,delta:-30,bodies:[])
        #expect(free[2] == p(20,50) && free[3] == p(100,50))
        #expect(free.first == horizontal.first && free.last == horizontal.last)
    }

    @Test func shortHorizontalTouchChoosesVisibleLineAndMovesOnlyItsY() throws {
        let path = [p(165,390),p(263,390),p(263,302),p(275,302),p(275,250),p(325,250)]
        // The neighboring vertical targets are only 6pt from the touch.
        for x in [CGFloat(268),269,270] {
            let hit = try #require(WireRouting.nearestInteriorSegment(to:p(x,302),paths:[path]))
            #expect(hit.wire == 0 && hit.segment == 2)
            let moved = WireRouting.moved(path,segment:hit.segment,delta:-97,bodies:bodies)
            #expect(moved == [p(165,390),p(263,390),p(263,205),p(275,205),p(275,250),p(325,250)])
        }
        #expect(WireRouting.nearestInteriorSegment(to:p(275,270),paths:[path])?.segment == 3)
        #expect(WireRouting.nearestInteriorSegment(to:p(263,350),paths:[path])?.segment == 1)
        #expect(WireRouting.nearestInteriorSegment(to:p(50,0),paths:[[p(0,0),p(100,0)]]) == nil)
    }

    @Test func shortHorizontalDragCreatesAndRemovesCrossingOnOtherWire() throws {
        let vertical = [p(165,160),p(269,160),p(269,250),p(325,250)]
        let horizontal = [p(165,390),p(263,390),p(263,302),p(275,302),p(275,250),p(325,250)]
        let hit = try #require(WireRouting.nearestInteriorSegment(to:p(269,302),paths:[vertical,horizontal]))
        #expect(hit.wire == 1 && hit.segment == 2)
        let moved = WireRouting.moved(horizontal,segment:hit.segment,delta:-97,bodies:bodies)
        #expect(WireRouting.crossings(vertical,others:[moved]) == [.init(point:p(269,205),segment:1,radius:7)])
        let restored = WireRouting.moved(moved,segment:hit.segment,delta:97,bodies:bodies)
        #expect(restored == horizontal)
        #expect(WireRouting.crossings(vertical,others:[restored]).isEmpty)
    }

    @Test func crossingTouchUsesPerpendicularMotionForReturnDrag() throws {
        let vertical = [p(165,160),p(269,160),p(269,250),p(325,250)]
        let horizontal = [p(165,390),p(263,390),p(263,205),p(275,205),p(275,250),p(325,250)]
        let hit = try #require(WireRouting.nearestInteriorSegment(to:p(269,205),paths:[vertical,horizontal],maximumDistance:8,translation:CGSize(width:-1,height:5)))
        #expect(hit.wire == 1 && hit.segment == 2)
        let side = try #require(WireRouting.nearestInteriorSegment(to:p(269,205),paths:[vertical,horizontal],maximumDistance:8,translation:CGSize(width:5,height:1)))
        #expect(side.wire == 0 && side.segment == 1)
        let restored = WireRouting.moved(horizontal,segment:hit.segment,delta:97,bodies:bodies)
        #expect(restored[2].y == 302 && restored[3].y == 302)
        #expect(WireRouting.crossings(vertical,others:[restored]).isEmpty)
    }

    @Test func backgroundHitResolutionRejectsBlankSpaceAndTerminalLeads() {
        let path = [p(165,390),p(263,390),p(263,302),p(275,302),p(275,250),p(325,250)]
        #expect(WireRouting.nearestInteriorSegment(to:p(269,302),paths:[path],maximumDistance:8)?.segment == 2)
        #expect(WireRouting.nearestInteriorSegment(to:p(240,330),paths:[path],maximumDistance:8) == nil)
        #expect(WireRouting.nearestInteriorSegment(to:p(220,390),paths:[path],maximumDistance:8) == nil)
        #expect(WireRouting.nearestInteriorSegment(to:p(300,302),paths:[path],maximumDistance:8) == nil)
    }

    @Test func manualSegmentPositionSurvivesEndpointMovement() {
        let path = [p(165,160),p(260,160),p(260,250),p(325,250)]
        let attached = WireRouting.reattach(path,start:p(210,180),end:p(320,280))
        #expect(attached.first == p(210,180) && attached.last == p(320,280))
        #expect(WireRouting.segments(attached).contains { $0.x == 260 && $1.x == 260 })
        #expect(WireRouting.segments(attached).allSatisfy { $0.x == $1.x || $0.y == $1.y })
    }

    @Test func crossingsExcludeCornersBranchesAndRecomputeAfterMovement() {
        let vertical = [p(50,0),p(50,100)]
        let horizontal = [p(0,50),p(100,50)]
        let hops = WireRouting.crossings(vertical,others:[horizontal])
        #expect(hops == [.init(point:p(50,50),segment:0,radius:7)])
        #expect(WireRouting.crossings(horizontal,others:[vertical]).isEmpty)
        #expect(WireRouting.crossings(vertical,others:[[p(50,50),p(100,50)]]).isEmpty)
        #expect(WireRouting.crossings(vertical,others:[[p(0,0),p(50,0)]]).isEmpty)
        #expect(WireRouting.crossings(vertical,others:[[p(0,3),p(100,3)]]).first?.radius == 0)
        #expect(WireRouting.crossings([p(150,0),p(150,100)],others:[horizontal]).isEmpty)
    }
    /// Two-, three- and four-terminal symbols at every rotation: routes stay orthogonal, avoid every
    /// body, leave each pin outward by at least the compact lead, and wires from one pin share a trunk.
    @Test func rotatedPinsRouteOutwardAvoidBodiesAndShareOnlyTerminalTrunks() {
        for kind in [SymbolKind.resistor,.npn,.opAmp,.relay,.connector] {
            for rotation in [0,90,180,270] {
                let centers = [p(200,200),p(500,400),p(600,100)]
                let obstacles = centers.map { kind.body(at:$0,rotation:rotation) }
                let pins = centers.map { kind.pins(at:$0,rotation:rotation) }
                let margins = [CGFloat?](repeating:WireRouting.symbolLead,count:obstacles.count)
                let last = kind.pinCount - 1
                var paths: [[CGPoint]] = []
                for target in [1,2] {
                    let connection = WireRouting.Connection(
                        start:pins[0][0],end:pins[target][last],
                        startDirection:kind.direction(for:0,rotation:rotation),
                        endDirection:kind.direction(for:last,rotation:rotation))
                    let path = WireRouting.route(connection,bodies:obstacles,occupied:paths,margins:margins)
                    #expect(path.count >= 3, "\(kind) at \(rotation)")
                    guard path.count >= 3 else { continue }
                    #expect(path.first == connection.start && path.last == connection.end)
                    for (a,b) in WireRouting.segments(path) {
                        #expect(a.x == b.x || a.y == b.y)
                        #expect(!obstacles.contains { WireRouting.intersectsInterior(a,b,$0) }, "\(kind) at \(rotation)")
                        // Wires may only overlap along a trunk that starts at a pin they share.
                        for other in paths {
                            for (c,d) in WireRouting.segments(other) where WireRouting.overlap(a,b,c,d) {
                                let pin = connection.start
                                #expect(pin == other.first && (a == pin || b == pin) && (c == pin || d == pin), "\(kind) at \(rotation)")
                            }
                        }
                    }
                    for (pin,next,direction) in [(path[0],path[1],connection.startDirection!),(path.last!,path[path.count-2],connection.endDirection!)] {
                        let along = (next.x-pin.x)*direction.vector.x + (next.y-pin.y)*direction.vector.y
                        #expect(along >= WireRouting.symbolLead - 0.001, "\(kind) at \(rotation)")
                        #expect((next.x-pin.x)*direction.vector.y == 0 && (next.y-pin.y)*direction.vector.x == 0)
                    }
                    paths.append(path)
                }
                #expect(!WireRouting.junctions(paths).isEmpty, "\(kind) at \(rotation)")
            }
        }
    }

    @Test func verticalTerminalManualDragAndReattachment() {
        let path = [p(100,100),p(100,150),p(300,150),p(300,200)]
        let moved = WireRouting.moved(path,segment:1,delta:20,bodies:[])
        #expect(moved == [p(100,100),p(100,170),p(300,170),p(300,200)])
        let attached = WireRouting.reattach(moved,start:p(110,90),end:p(310,210))
        #expect(attached == [p(110,90),p(110,170),p(310,170),p(310,210)])
        #expect(WireRouting.junctions([path,[p(100,100),p(100,130),p(400,130),p(400,200)]]) == [p(100,130)])
    }

    /// Regression: with symbols placed close together no route fit, and the wire
    /// disappeared while both pins still showed as connected.
    @Test func tightLayoutsStillDrawAnOrthogonalWire() {
        // A row of vertical parts (VCC among them), a vertical resistor 24pt below it,
        // and coil / LED / diode 12pt apart on the row beneath.
        var bodies = [54,126,198,270,342].map { CGRect(x:CGFloat($0)-15,y:402,width:30,height:60) }
        bodies.append(CGRect(x:63,y:486,width:30,height:60))
        bodies += [198,270,342].map { CGRect(x:CGFloat($0)-30,y:525,width:60,height:30) }
        let margins = [CGFloat?](repeating:WireRouting.symbolLead,count:bodies.count)
        let vccToResistor = WireRouting.Connection(start:p(270,462),end:p(78,486),startDirection:.down,endDirection:.up)
        let resistorToLED = WireRouting.Connection(start:p(78,546),end:p(240,540),startDirection:.down,endDirection:.left)
        var occupied: [[CGPoint]] = []
        for connection in [vccToResistor, resistorToLED] {
            let path = WireRouting.route(connection, bodies: bodies, occupied: occupied, margins: margins)
            #expect(path.count >= 2, "wire must be drawn")
            #expect(path.first == connection.start && path.last == connection.end)
            for (a,b) in WireRouting.segments(path) { #expect(a.x == b.x || a.y == b.y) }
            occupied.append(path)
        }
    }

    /// The last resort. The start pin's lead ends inside another body for every lead length, so no
    /// planned route exists; the wire must still be drawn, as the plain orthogonal path with 8pt stubs.
    /// (That path crosses the blocking body, which no planned route ever does - so equality proves the fallback ran.)
    @Test func wireIsStillDrawnWhenNoPlannedRouteExists() {
        let blocker = CGRect(x:5,y:-50,width:95,height:100)     // the start lead (8...15pt) lands inside it
        let start = p(0,0), end = p(200,100)
        let path = WireRouting.route(.init(start:start,end:end,startDirection:.right,endDirection:.left),
                                     bodies:[blocker],occupied:[],margins:[WireRouting.symbolLead])
        #expect(path == [p(0,0),p(192,0),p(192,100),p(200,100)])
        #expect(WireRouting.segments(path).contains { WireRouting.intersectsInterior($0,$1,blocker) })
    }

    /// A pin in the first row slot of a tall block leaves outward through the block's side, not along its edge.
    @Test func wireLeavesTheFirstRowSlotOfATallBlockSideways() {
        let tall = CGRect(x:325,y:235,width:150,height:90)          // pins at (325,250) and (475,250)
        let other = CGRect(x:0,y:235,width:90,height:30)             // pin at (90,250)
        let bodies = [tall,other]
        let path = WireRouting.route(.init(start:p(90,250),end:p(325,250)),bodies:bodies,occupied:[])
        #expect(path.first == p(90,250) && path.last == p(325,250))
        #expect(WireRouting.segments(path).allSatisfy { a,b in !bodies.contains { WireRouting.intersectsInterior(a,b,$0) } })
        #expect(path.count >= 2 && path[path.count-2].x < 325)        // arrives from the left, outside the block
        // The right pin's lead heads right, away from the block.
        let up = WireRouting.route(.init(start:p(475,250),end:p(600,100)),bodies:bodies,occupied:[])
        #expect(up.count >= 2 && up[1].x > 475 && up[1].y == 250)
    }

    // MARK: incremental rerouting (a moved block must not disturb unrelated wires)

    /// Six blocks / four wires; `moved` shifts block 0 (whose pin drives wire 0 only).
    private func scene(moving delta: CGSize = .zero) -> (bodies: [CGRect], wires: [WireRouting.Wire]) {
        let centers = [p(120,160),p(420,160),p(120,400),p(420,400),p(120,640),p(420,640)]
        var bodies = centers.map { CGRect(x:$0.x-45,y:$0.y-15,width:90,height:30) }
        bodies[0] = bodies[0].offsetBy(dx:delta.width,dy:delta.height)
        func pin(_ b: Int, _ right: Bool) -> CGPoint { p(right ? bodies[b].maxX : bodies[b].minX, bodies[b].midY) }
        let wires = [WireRouting.Wire(start:pin(0,true),end:pin(1,false)),
                     WireRouting.Wire(start:pin(2,true),end:pin(3,false)),
                     WireRouting.Wire(start:pin(3,true),end:pin(5,true)),
                     WireRouting.Wire(start:pin(4,true),end:pin(5,false))]
        return (bodies,wires)
    }

    @Test func firstRoutingPlansEveryWireInOrderAndLaterRoutingKeepsUnrelatedOnes() {
        let before = scene()
        let margins = [CGFloat?](repeating:nil,count:6)
        let initial = WireRouting.reroute(before.wires,bodies:before.bodies,margins:margins)
        // Same as planning each wire in turn around the ones before it.
        var occupied: [[CGPoint]] = []
        for (i,wire) in before.wires.enumerated() {
            let expected = WireRouting.route(.init(start:wire.start,end:wire.end),bodies:before.bodies,occupied:occupied,margins:margins)
            #expect(initial[i] == expected, "wire \(i)")
            occupied.append(expected)
        }
        for delta in [CGSize(width:0,height:30),CGSize(width:36,height:-24),CGSize(width:-60,height:150)] {
            var after = scene(moving:delta)
            for i in after.wires.indices { after.wires[i].points = initial[i] }
            let next = WireRouting.reroute(after.wires,bodies:after.bodies,margins:margins)
            #expect(next[0].first == after.wires[0].start && next[0].last == after.wires[0].end)
            #expect(WireRouting.isClear(next[0],bodies:after.bodies))
            for i in 1..<4 { #expect(next[i] == initial[i], "wire \(i) must not move when block 0 moves by \(delta)") }
        }
    }

    @Test func aWireThatABodyNowSitsOnIsRoutedAgainAndOthersStay() {
        let scene = scene()
        let margins = [CGFloat?](repeating:nil,count:6)
        let initial = WireRouting.reroute(scene.wires,bodies:scene.bodies,margins:margins)
        // Drop block 4 onto wire 1's route.
        let target = p((scene.wires[1].start.x+scene.wires[1].end.x)/2,(scene.wires[1].start.y+scene.wires[1].end.y)/2)
        var bodies = scene.bodies
        bodies[4] = CGRect(x:target.x-45,y:target.y-15,width:90,height:30)
        var wires = scene.wires
        for i in wires.indices { wires[i].points = initial[i] }
        wires[3].start = p(bodies[4].maxX,bodies[4].midY)
        #expect(!WireRouting.isClear(initial[1],bodies:bodies))
        let next = WireRouting.reroute(wires,bodies:bodies,margins:margins)
        #expect(WireRouting.isClear(next[1],bodies:bodies) && next[1] != initial[1])
        #expect(next[1].first == wires[1].start && next[1].last == wires[1].end)
        #expect(next[0] == initial[0] && next[2] == initial[2])
    }

    @Test func manualRoutesAreReattachedNotReplanned() {
        let scene = scene()
        var wires = scene.wires
        wires[0].manual = true
        wires[0].manualPoints = [wires[0].start,p(200,160),p(200,220),p(300,220),p(300,160),wires[0].end]
        let next = WireRouting.reroute(wires,bodies:scene.bodies,margins:[CGFloat?](repeating:nil,count:6))
        #expect(next[0] == WireRouting.reattach(wires[0].manualPoints,start:wires[0].start,end:wires[0].end))
    }

    /// Codex review: a reattached hand-placed route may lie along a kept automatic wire; that wire is planned again.
    @Test func aKeptWireThatNowOverlapsAManualRouteIsPlannedAgain() {
        let scene = scene()
        let margins = [CGFloat?](repeating:nil,count:6)
        let initial = WireRouting.reroute(scene.wires,bodies:scene.bodies,margins:margins)
        var wires = scene.wires
        for i in wires.indices { wires[i].points = initial[i] }
        // Wire 1 runs straight along y = 400; wire 0's hand-placed route now runs along the same line.
        #expect(initial[1] == [wires[1].start,wires[1].end])
        wires[0].manual = true
        wires[0].manualPoints = [wires[0].start,p(200,160),p(200,400),p(300,400),p(300,160),wires[0].end]
        let next = WireRouting.reroute(wires,bodies:scene.bodies,margins:margins)
        #expect(next[1] != initial[1])
        #expect(next[1].first == wires[1].start && next[1].last == wires[1].end)
        #expect(!WireRouting.hasForbiddenOverlap(next[1],with:[next[0]]))
        #expect(WireRouting.isClear(next[1],bodies:scene.bodies))
        #expect(next[2] == initial[2] && next[3] == initial[3])
    }

    /// Which overlaps count as a problem: only a trunk leaving a pin both wires share is allowed.
    @Test func overlapIsAllowedOnlyAlongTheTrunkOfASharedPin() {
        let pin = p(100,100)
        let a = [pin,p(140,100),p(140,160)]
        // Shared pin, same first leg (horizontal or vertical): allowed.
        #expect(!WireRouting.hasForbiddenOverlap(a,with:[[pin,p(140,100),p(140,40)]]))
        let down = [pin,p(100,160),p(180,160)]
        #expect(!WireRouting.hasForbiddenOverlap(down,with:[[pin,p(100,200)]]))
        // Overlap that does not start at a shared pin: forbidden, horizontally and vertically.
        #expect(WireRouting.hasForbiddenOverlap([p(0,50),p(200,50)],with:[[p(60,50),p(120,50),p(120,0)]]))
        #expect(WireRouting.hasForbiddenOverlap([p(300,0),p(300,100)],with:[[p(280,40),p(300,40),p(300,140)]]))
        // Shared pin but the overlap is further along (not the pin's own trunk): forbidden.
        #expect(WireRouting.hasForbiddenOverlap([pin,p(140,100),p(140,200)],with:[[p(100,300),p(100,120),p(140,120),p(140,180),p(200,180),p(200,100),pin]]))
        // Crossing without overlap is fine.
        #expect(!WireRouting.hasForbiddenOverlap([p(0,50),p(200,50)],with:[[p(100,0),p(100,100)]]))
    }

    // MARK: straightening steps (snap within 13pt + merging collinear points)

    /// A trunk with a 10pt step: ... -> (100,0) -> (100,80) -> (110,80) -> (110,200) -> ...
    private var stepped: [CGPoint] { [p(0,0),p(100,0),p(100,80),p(110,80),p(110,200),p(300,200)] }

    @Test func draggingOneSideOfAStepOntoTheOtherMakesOneStraightSegment() {
        // Segment 3 (the lower vertical, x = 110) dragged towards the upper one (x = 100).
        for delta in [CGFloat(-10),-8,-12.9,-13,-14.9] {
            let straight = WireRouting.moved(stepped,segment:3,delta:delta,bodies:[])
            #expect(straight == [p(0,0),p(100,0),p(100,200),p(300,200)], "delta \(delta)")
        }
        // ... and the other way round: the upper vertical (x = 100) towards the lower one.
        #expect(WireRouting.moved(stepped,segment:1,delta:7,bodies:[]) == [p(0,0),p(110,0),p(110,200),p(300,200)])
        // Ends never move.
        let result = WireRouting.moved(stepped,segment:3,delta:-9,bodies:[])
        #expect(result.first == stepped.first && result.last == stepped.last)
    }

    @Test func snapReachesExactlyThirteenPointsAndNoFurther() {
        // Line at x = 110, neighbour at x = 100: proposals 113 (13 away) snap, 114 (14 away) do not.
        let snapped = WireRouting.moved(stepped,segment:3,delta:3,bodies:[])
        #expect(snapped == [p(0,0),p(100,0),p(100,200),p(300,200)])
        let free = WireRouting.moved(stepped,segment:3,delta:4,bodies:[])
        #expect(free == [p(0,0),p(100,0),p(100,80),p(114,80),p(114,200),p(300,200)])
        // Far from every neighbour nothing snaps.
        let far = WireRouting.moved(stepped,segment:3,delta:-40,bodies:[])
        #expect(far == [p(0,0),p(100,0),p(100,80),p(70,80),p(70,200),p(300,200)])
    }

    @Test func aStraightenedRouteHasNoZeroLengthOrCollinearSegments() {
        for delta in stride(from:-20.0,through:20.0,by:1.0) {
            let path = WireRouting.moved(stepped,segment:3,delta:CGFloat(delta),bodies:[])
            for (a,b) in WireRouting.segments(path) { #expect(a != b, "delta \(delta)") }
            for i in 0..<max(0,path.count-2) {
                let (a,b,c) = (path[i],path[i+1],path[i+2])
                #expect(!((a.x == b.x && b.x == c.x) || (a.y == b.y && b.y == c.y)), "delta \(delta)")
            }
        }
    }

    @Test func snappingNeverPullsASegmentThroughABody() {
        // A body between the two vertical lines (x 102...108) is in the way: the lower line stops at its edge
        // instead of jumping to the neighbour it would otherwise snap to.
        let body = CGRect(x:102,y:100,width:6,height:50)
        #expect(WireRouting.isClear(stepped,bodies:[body]))
        let result = WireRouting.moved(stepped,segment:3,delta:-9,bodies:[body])
        #expect(WireRouting.isClear(result,bodies:[body]))
        #expect(result.first == stepped.first && result.last == stepped.last)
        #expect(result.contains { $0.x == 108 })                    // stopped at the body, not at x = 100
    }

    @Test func aStraightenedManualRouteStillFollowsItsMovedEnds() {
        let straight = WireRouting.simplify(WireRouting.moved(stepped,segment:3,delta:-10,bodies:[]))
        #expect(straight.count == 4)
        // Down to one segment: both ends aligned.
        #expect(WireRouting.reattach([p(0,0),p(100,0)],start:p(0,0),end:p(100,0)) == [p(0,0),p(100,0)])
        // Move an end so the two are no longer in line: rejoined orthogonally, first leg horizontal as before.
        let elbow = WireRouting.reattach([p(0,0),p(100,0)],start:p(0,0),end:p(100,40))
        #expect(elbow == [p(0,0),p(100,0),p(100,40)])
        let vertical = WireRouting.reattach([p(0,0),p(0,100)],start:p(0,0),end:p(30,100))
        #expect(vertical == [p(0,0),p(0,100),p(30,100)])
        #expect(WireRouting.segments(elbow).allSatisfy { $0.x == $1.x || $0.y == $1.y })
    }

    /// Codex review: a route planned through a narrow gap (10pt clear on each side) must stay draggable, while a
    /// segment that is dragged towards a body still stops before it.
    @Test func routesThroughNarrowGapsStayDraggableAndStillAvoidBodies() {
        let upper = CGRect(x:100,y:-100,width:50,height:100), lower = CGRect(x:100,y:20,width:50,height:100)
        let path = [p(0,-150),p(60,-150),p(60,10),p(200,10),p(200,200),p(300,200)]      // segment 2 runs through the gap at y = 10
        let bodies = [upper,lower]
        #expect(WireRouting.isClear(path,bodies:bodies))
        // A segment beside the gap is dragged: the route through the gap is not what changed, so the drag works.
        let moved = WireRouting.moved(path,segment:3,delta:50,bodies:bodies,minimumTerminalLead:8)
        #expect(moved[3].x == 250 && moved[4].x == 250)
        #expect(WireRouting.isClear(moved,bodies:bodies))
        // The other way: the vertical at x = 60 is pushed towards the upper body and stops short of it.
        let towards = WireRouting.moved(path,segment:1,delta:200,bodies:bodies,minimumTerminalLead:8)
        #expect(WireRouting.isClear(towards,bodies:bodies))
        #expect(towards[1].x <= 100 && towards[1].x > 60)
        // Without the lead limit nothing changes: a segment may go right up to a body.
        let plain = WireRouting.moved(path,segment:1,delta:200,bodies:bodies)
        #expect(WireRouting.isClear(plain,bodies:bodies) && plain[1].x == 100)
    }

    // MARK: fuzzing the production algorithm (move / resize / rotate / drag) for a stray diagonal wire

    /// Mirrors ContentView's own state machine (SymbolItem-like blocks/circuit symbols, WireItem-like wires) using
    /// only the public WireRouting / SymbolKind API - the same calls ContentView.move, .rotateSymbol,
    /// .applyBlockGeometry and .updateSegmentDrag make - so a bug in that combination shows up here too.
    private struct FuzzWire { var start: CGPoint; var end: CGPoint; var manual = false; var manualPoints: [CGPoint] = []; var points: [CGPoint] = [] }
    private struct FuzzSymbol { var kind: SymbolKind; var position: CGPoint; var rotation: Int; var size: CGSize?
        var pins: [CGPoint] { kind.pins(at:position,rotation:rotation,size:size) }
        var body: CGRect { kind.body(at:position,rotation:rotation,size:size) }
    }

    /// A small seedable generator so a failure is reproducible: rerun with the seed printed in the failure message.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0xdead_beef : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            return state
        }
    }

    @Test(arguments: [UInt64(1), 2, 3, 42, 12345])
    func fuzzedMovesResizesRotationsAndDragsNeverProduceADiagonalWire(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        var symbols = [
            FuzzSymbol(kind:.block,position:p(300,300),rotation:0,size:BlockSize.standard),
            FuzzSymbol(kind:.block,position:p(700,300),rotation:0,size:BlockSize.standard),
            FuzzSymbol(kind:.resistor,position:p(500,600),rotation:0,size:nil),
            FuzzSymbol(kind:.npn,position:p(300,600),rotation:0,size:nil)
        ]
        var wires = [
            FuzzWire(start:symbols[0].pins[1],end:symbols[2].pins[0]),
            FuzzWire(start:symbols[2].pins[1],end:symbols[1].pins[0]),
            FuzzWire(start:symbols[3].pins[0],end:symbols[1].pins[1])
        ]
        func bodies() -> [CGRect] { symbols.map(\.body) }
        func margins() -> [CGFloat?] { symbols.map { $0.kind.isBlock ? nil : WireRouting.symbolLead } }
        func direction(at pin: CGPoint) -> WireRouting.Direction? {
            for symbol in symbols where !symbol.kind.isBlock {
                if let i = symbol.pins.firstIndex(where:{ hypot($0.x-pin.x,$0.y-pin.y) < 1 }) { return symbol.kind.direction(for:i,rotation:symbol.rotation) }
            }
            return nil
        }
        func reroute() {
            let planned = WireRouting.reroute(wires.map { .init(start:$0.start,end:$0.end,startDirection:direction(at:$0.start),endDirection:direction(at:$0.end),
                                                                  manual:$0.manual,manualPoints:$0.manualPoints,points:$0.points) },
                                              bodies:bodies(),margins:margins())
            for i in wires.indices { wires[i].points = planned[i] }
        }
        func assertOrthogonal(_ context: String) {
            for (i,wire) in wires.enumerated() {
                #expect(wire.points.count >= 2, "seed \(seed), \(context): wire \(i) has no route")
                guard wire.points.count >= 2 else { continue }
                #expect(wire.points.first == wire.start && wire.points.last == wire.end, "seed \(seed), \(context): wire \(i) detached")
                for (a,b) in WireRouting.segments(wire.points) {
                    #expect(a.x == b.x || a.y == b.y, "seed \(seed), \(context): wire \(i) has a diagonal segment \(a)->\(b), full path \(wire.points)")
                }
            }
        }
        func moveSymbol(_ i: Int, by translation: CGSize) {
            let old = symbols[i].pins
            symbols[i].position = p(symbols[i].position.x+translation.width,symbols[i].position.y+translation.height)
            let new = symbols[i].pins
            for j in wires.indices {
                if let point = SymbolKind.remapped(wires[j].start,from:old,to:new) { wires[j].start = point }
                if let point = SymbolKind.remapped(wires[j].end,from:old,to:new) { wires[j].end = point }
            }
        }
        func resizeSymbol(_ i: Int, sx: CGFloat, sy: CGFloat, translation: CGSize) {
            guard symbols[i].kind.isBlock, let size = symbols[i].size else { return }
            let old = symbols[i].pins
            let result = BlockSize.resized(center:symbols[i].position,size:size,sx:sx,sy:sy,translation:translation)
            symbols[i].position = result.center; symbols[i].size = result.size
            let new = symbols[i].pins
            for j in wires.indices {
                if let point = SymbolKind.remapped(wires[j].start,from:old,to:new) { wires[j].start = point }
                if let point = SymbolKind.remapped(wires[j].end,from:old,to:new) { wires[j].end = point }
            }
        }
        func rotateSymbol(_ i: Int) {
            guard !symbols[i].kind.isBlock else { return }
            let old = symbols[i].pins
            symbols[i].rotation = (symbols[i].rotation+90)%360
            let new = symbols[i].pins
            for j in wires.indices {
                if let point = SymbolKind.remapped(wires[j].start,from:old,to:new) { wires[j].start = point; wires[j].manual = false }
                if let point = SymbolKind.remapped(wires[j].end,from:old,to:new) { wires[j].end = point; wires[j].manual = false }
            }
        }
        func dragSegment(_ wireIndex: Int, delta: CGFloat) {
            guard wires[wireIndex].points.count > 3 else { return }
            let segment = Int.random(in:1..<(wires[wireIndex].points.count-2),using:&rng)
            let lead = max(direction(at:wires[wireIndex].start) != nil ? WireRouting.symbolLead : 0,
                           direction(at:wires[wireIndex].end) != nil ? WireRouting.symbolLead : 0)
            wires[wireIndex].points = WireRouting.moved(wires[wireIndex].points,segment:segment,delta:delta,bodies:bodies(),minimumTerminalLead:lead)
            wires[wireIndex].manual = true
            wires[wireIndex].manualPoints = wires[wireIndex].points
        }
        reroute(); assertOrthogonal("seed \(seed), initial")
        for step in 0..<300 {
            let symbolIndex = Int.random(in:0..<symbols.count,using:&rng)
            switch Int.random(in:0..<4,using:&rng) {
            case 0: moveSymbol(symbolIndex,by:CGSize(width:CGFloat(Int.random(in:-80...80,using:&rng)),height:CGFloat(Int.random(in:-80...80,using:&rng))))
            case 1: resizeSymbol(symbolIndex,sx:[-1.0,1.0].randomElement(using:&rng)!,sy:[-1.0,1.0].randomElement(using:&rng)!,
                                 translation:CGSize(width:CGFloat(Int.random(in:-90...90,using:&rng)),height:CGFloat(Int.random(in:-90...90,using:&rng))))
            case 2: rotateSymbol(symbolIndex)
            default:
                if !wires.isEmpty { dragSegment(Int.random(in:0..<wires.count,using:&rng),delta:CGFloat(Int.random(in:-60...60,using:&rng))) }
            }
            reroute()
            assertOrthogonal("seed \(seed), step \(step)")
        }
    }

    /// Defence in depth: reroute must never keep a stale route that is not orthogonal, even if something upstream
    /// produced one - it should replan it instead of perpetuating it forever.
    @Test func rerouteReplacesAKeptRouteThatIsNotOrthogonal() {
        // Simulate a stray diagonal that somehow ended up stored (pins not aligned on either axis).
        let wire = WireRouting.Wire(start:p(0,0),end:p(200,150),points:[p(0,0),p(200,150)])
        #expect(!WireRouting.isOrthogonal(wire.points))
        let result = WireRouting.reroute([wire],bodies:[],margins:[nil])
        #expect(WireRouting.isOrthogonal(result[0]))
        #expect(result[0].first == wire.start && result[0].last == wire.end)
    }

    // MARK: edit mode wire deletion (4C)

    /// Deleting the only segment of a straight, 2-point wire leaves nothing on either side.
    @Test func splittingTheOnlySegmentOfAStraightWireLeavesNothingOnEitherSide() {
        let points = [p(0,0),p(100,0)]
        let (front,back) = WireRouting.split(points, at: 0)
        #expect(front == nil)
        #expect(back == nil)
    }

    /// Deleting the first segment of a multi-segment path drops it and keeps the rest as the "back" side;
    /// there is nothing left on the "front" side (a single point cannot be a wire).
    @Test func splittingTheFirstSegmentKeepsOnlyTheRemainingBackSide() {
        let points = [p(0,0),p(0,100),p(100,100),p(100,0)]
        let (front,back) = WireRouting.split(points, at: 0)
        #expect(front == nil)
        #expect(back == [p(0,100),p(100,100),p(100,0)])
    }

    /// Deleting the last segment is the mirror image: the "front" side keeps everything up to the cut, and
    /// there is nothing left on the "back" side.
    @Test func splittingTheLastSegmentKeepsOnlyTheRemainingFrontSide() {
        let points = [p(0,0),p(0,100),p(100,100),p(100,0)]
        let (front,back) = WireRouting.split(points, at: 2)
        #expect(front == [p(0,0),p(0,100),p(100,100)])
        #expect(back == nil)
    }

    /// Deleting a middle segment splits the path into two independent remaining sides.
    @Test func splittingAMiddleSegmentKeepsBothRemainingSidesSeparately() {
        let points = [p(0,0),p(0,100),p(100,100),p(100,0),p(200,0)]
        let (front,back) = WireRouting.split(points, at: 1)
        #expect(front == [p(0,0),p(0,100)])
        #expect(back == [p(100,100),p(100,0),p(200,0)])
    }

    /// Out-of-range segments are ignored rather than corrupting the path.
    @Test func splittingAnOutOfRangeSegmentKeepsTheOriginalPathAsTheFrontSide() {
        let points = [p(0,0),p(100,0)]
        let (front,back) = WireRouting.split(points, at: 5)
        #expect(front == points)
        #expect(back == nil)
    }
}
