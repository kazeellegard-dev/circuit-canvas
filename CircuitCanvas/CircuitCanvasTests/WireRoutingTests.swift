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
        #expect(h[2] == p(20,110) && h[3] == p(100,110))
        #expect(h.first == horizontal.first && h.last == horizontal.last)
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
}
