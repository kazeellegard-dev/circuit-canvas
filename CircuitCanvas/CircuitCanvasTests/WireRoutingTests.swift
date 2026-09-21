import Foundation
import CoreGraphics

import Testing
@testable import CircuitCanvas

@MainActor
struct WireRoutingTests {
    let centers: [CGPoint] = [.init(x:120,y:160),.init(x:370,y:250),.init(x:620,y:250),.init(x:120,y:390)]
    var bodies: [CGRect] { centers.map { CGRect(x:$0.x-75,y:$0.y-32,width:150,height:64) } }
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x:x,y:y) }

    @Test func initialAndRequestedRoutesAvoidBodiesAndOverlaps() {
        let pairs = [(p(195,160),p(295,250)),(p(445,250),p(545,250)),(p(195,390),p(295,250)),(p(195,390),p(545,250)),(p(195,390),p(445,250)),(p(45,160),p(295,250))]
        for shift in [CGFloat(0),48] {
            var obstacles = bodies
            obstacles[1] = obstacles[1].offsetBy(dx:shift,dy:shift)
            var routes: [[CGPoint]] = []
            for (originalStart,originalEnd) in pairs {
                func shifted(_ pin: CGPoint) -> CGPoint { pin == p(295,250) || pin == p(445,250) ? p(pin.x+shift,pin.y+shift) : pin }
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
                }
                routes.append(path)
            }
        }
    }

    @Test func segmentDragIsPerpendicularAttachedAndCannotTunnelThroughBody() {
        let path = [p(195,160),p(245,160),p(245,250),p(295,250)]
        let moved = WireRouting.moved(path,segment:1,delta:200,bodies:bodies)
        #expect(moved[1].x <= 295 && moved[1].x > 294.99)
        #expect(moved.first == path.first && moved.last == path.last)
        #expect(moved[1].y == 160 && moved[2].y == 250)
        #expect(moved[1].x == moved[2].x)
        let horizontal = [p(0,0),p(20,0),p(20,80),p(100,80),p(100,100),p(120,100)]
        let h = WireRouting.moved(horizontal,segment:2,delta:30,bodies:[])
        #expect(h[2] == p(20,110) && h[3] == p(100,110))
        #expect(h.first == horizontal.first && h.last == horizontal.last)
    }

    @Test func manualSegmentPositionSurvivesEndpointMovement() {
        let path = [p(195,160),p(260,160),p(260,250),p(295,250)]
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
}
