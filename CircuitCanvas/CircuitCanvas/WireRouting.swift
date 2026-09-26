import Foundation
import CoreGraphics


/// Logical canvas geometry, independent of rendering and viewport transforms.
enum WireRouting {
    enum Direction: Int {
        case left, up, right, down
        var vector: CGPoint {
            switch self { case .left: CGPoint(x:-1,y:0); case .up: CGPoint(x:0,y:-1)
            case .right: CGPoint(x:1,y:0); case .down: CGPoint(x:0,y:1) }
        }
    }
    struct Connection {
        var start: CGPoint; var end: CGPoint
        var startDirection: Direction? = nil
        var endDirection: Direction? = nil
    }
    struct Crossing: Equatable { var point: CGPoint; var segment: Int; var radius: CGFloat }
    static func segments(_ p: [CGPoint]) -> [(CGPoint, CGPoint)] { Array(zip(p, p.dropFirst())) }
    static func intersectsInterior(_ a: CGPoint, _ b: CGPoint, _ r: CGRect) -> Bool {
        if a.y == b.y { return a.y > r.minY && a.y < r.maxY && max(a.x,b.x) > r.minX && min(a.x,b.x) < r.maxX }
        return a.x > r.minX && a.x < r.maxX && max(a.y,b.y) > r.minY && min(a.y,b.y) < r.maxY
    }
    static func overlap(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        if a.y == b.y && c.y == d.y && a.y == c.y { return min(max(a.x,b.x),max(c.x,d.x)) > max(min(a.x,b.x),min(c.x,d.x)) }
        if a.x == b.x && c.x == d.x && a.x == c.x { return min(max(a.y,b.y),max(c.y,d.y)) > max(min(a.y,b.y),min(c.y,d.y)) }
        return false
    }
    static func simplify(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for p in points where result.last != p {
            while result.count >= 2 {
                let a = result[result.count-2], b = result[result.count-1]
                guard (a.x == b.x && b.x == p.x) || (a.y == b.y && b.y == p.y) else { break }
                result.removeLast()
            }
            result.append(p)
        }
        return result
    }
    /// Preserve room around bodies, reducing each facing margin in narrow gaps.
    static func routingBounds(_ bodies: [CGRect]) -> [CGRect] {
        bodies.map { body in
            var left: CGFloat = 24, right: CGFloat = 24
            var top: CGFloat = body.width == 50 ? 24 : 20
            var bottom = top
            for other in bodies where other != body {
                if other.maxY > body.minY && other.minY < body.maxY {
                    if other.maxX <= body.minX { left = min(left, (body.minX-other.maxX)/2) }
                    if other.minX >= body.maxX { right = min(right, (other.minX-body.maxX)/2) }
                }
                if other.maxX > body.minX && other.minX < body.maxX {
                    if other.maxY <= body.minY { top = min(top, (body.minY-other.maxY)/2) }
                    if other.minY >= body.maxY { bottom = min(bottom, (other.minY-body.maxY)/2) }
                }
            }
            return CGRect(x:body.minX-left,y:body.minY-top,width:body.width+left+right,height:body.height+top+bottom)
        }
    }

    /// Walk pairs from their common pin until the first divergence, even when
    /// one path has an extra collinear vertex. Later crossings are not junctions.
    static func junctions(_ paths: [[CGPoint]]) -> [CGPoint] {
        var result: [CGPoint] = []
        let paths = paths.map { path in
            path.reduce(into: [CGPoint]()) { result, point in
                if result.last != point { result.append(point) }
            }
        }
        let pins = paths.flatMap { [$0.first, $0.last].compactMap { $0 } }
        for i in paths.indices {
            for j in paths.indices where j > i {
                for pin in [paths[i].first, paths[i].last].compactMap({ $0 }) {
                    guard paths[j].first == pin || paths[j].last == pin else { continue }
                    let a = paths[i].first == pin ? paths[i] : Array(paths[i].reversed())
                    let b = paths[j].first == pin ? paths[j] : Array(paths[j].reversed())
                    var ai = 1, bi = 1, current = pin
                    while ai < a.count && bi < b.count {
                        let av = CGPoint(x:a[ai].x-current.x,y:a[ai].y-current.y)
                        let bv = CGPoint(x:b[bi].x-current.x,y:b[bi].y-current.y)
                        let same = (av.x == 0 && bv.x == 0 && av.y*bv.y > 0) ||
                            (av.y == 0 && bv.y == 0 && av.x*bv.x > 0)
                        guard same else {
                            if !pins.contains(current) && !result.contains(current) { result.append(current) }
                            break
                        }
                        let al = abs(av.x)+abs(av.y), bl = abs(bv.x)+abs(bv.y)
                        current = al <= bl ? a[ai] : b[bi]
                        if al <= bl { ai += 1 }; if bl <= al { bi += 1 }
                    }
                }
            }
        }
        return result.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
    }

    /// A wire is never left undrawn: when the preferred route does not fit (symbols placed
    /// close together), relax the margins, then the lead-out length, then the overlap rule,
    /// and finally fall back to a plain orthogonal path.
    static func route(_ wire: Connection, bodies: [CGRect], occupied: [[CGPoint]]) -> [CGPoint] {
        let attempts: [(lead: CGFloat, margin: Bool, avoidOccupied: Bool)] = [
            (24, true, true), (24, false, true), (12, false, true), (12, false, false)
        ]
        for attempt in attempts {
            let path = plannedRoute(wire, bodies: bodies, occupied: attempt.avoidOccupied ? occupied : [],
                                    leadLength: attempt.lead, margin: attempt.margin)
            if !path.isEmpty { return path }
        }
        func stub(_ pin: CGPoint, _ direction: Direction?) -> CGPoint {
            guard let v = direction?.vector else { return pin }
            return CGPoint(x:pin.x+v.x*12,y:pin.y+v.y*12)
        }
        let s = stub(wire.start, wire.startDirection), e = stub(wire.end, wire.endDirection)
        return simplify([wire.start, s, CGPoint(x:e.x,y:s.y), e, wire.end])
    }

    private static func plannedRoute(_ wire: Connection, bodies: [CGRect], occupied: [[CGPoint]],
                                     leadLength: CGFloat, margin: Bool) -> [CGPoint] {
        let bounds = margin ? routingBounds(bodies) : bodies
        func lead(_ pin: CGPoint, direction: Direction?) -> CGPoint {
            if let direction {
                let v = direction.vector
                return CGPoint(x:pin.x+v.x*leadLength,y:pin.y+v.y*leadLength)
            }
            for (i, body) in bodies.enumerated() {
                if body.midY == pin.y {
                    if body.minX == pin.x { return CGPoint(x:bounds[i].minX,y:pin.y) }
                    if body.maxX == pin.x { return CGPoint(x:bounds[i].maxX,y:pin.y) }
                }
                if body.midX == pin.x {
                    if body.minY == pin.y { return CGPoint(x:pin.x,y:min(pin.y-24,bounds[i].minY)) }
                    if body.maxY == pin.y { return CGPoint(x:pin.x,y:max(pin.y+24,bounds[i].maxY)) }
                }
            }
            return CGPoint(x:pin.x+24,y:pin.y)
        }
        let start = wire.start, end = wire.end
        let s = lead(start,direction:wire.startDirection), e = lead(end,direction:wire.endDirection)
        var xs = [start.x, end.x, s.x, e.x], ys = [start.y,end.y,s.y,e.y]
        for r in bounds { xs += [r.minX,r.maxX]; ys += [r.minY,r.maxY] }
        for p in occupied.flatMap({ $0 }) { xs += [p.x-12,p.x+12]; ys += [p.y-12,p.y+12] }
        xs = Array(Set(xs)).sorted(); ys = Array(Set(ys)).sorted()
        func clear(_ a: CGPoint, _ b: CGPoint, terminal: Bool = false) -> Bool {
            guard !(terminal ? bodies : bounds).contains(where: { intersectsInterior(a,b,$0) }) else { return false }
            for path in occupied {
                let shared: [CGPoint] = [start,end].filter { $0 == path.first || $0 == path.last }
                for (c,d) in segments(path) where overlap(a,b,c,d) {
                    // Only a collinear trunk incident to the common pin may be shared.
                    if !shared.contains(where: { pin in (c == pin || d == pin) && ((a.y == pin.y && b.y == pin.y) || (a.x == pin.x && b.x == pin.x)) }) { return false }
                }
            }
            return true
        }
        guard clear(start,s,terminal:true), clear(e,end,terminal:true) else { return [] }
        let width = xs.count, count = width * ys.count
        func point(_ i: Int) -> CGPoint { CGPoint(x: xs[i % width], y: ys[i / width]) }
        let source = ys.firstIndex(of:s.y)! * width + xs.firstIndex(of:s.x)!
        let target = ys.firstIndex(of:e.y)! * width + xs.firstIndex(of:e.x)!
        // Queue-based shortest path on the rectilinear visibility grid.
        var distance = Array(repeating: CGFloat.infinity, count: count)
        var previous = Array(repeating: -1, count: count)
        var queued = Array(repeating: false, count: count)
        var queue = [source], head = 0
        distance[source] = 0; queued[source] = true
        while head < queue.count {
            let i = queue[head]; head += 1; queued[i] = false
            var neighbors: [Int] = []
            if i % width > 0 { neighbors.append(i-1) }; if i % width+1 < width { neighbors.append(i+1) }
            if i >= width { neighbors.append(i-width) }; if i+width < count { neighbors.append(i+width) }
            for j in neighbors {
                let a = point(i), b = point(j)
                guard clear(a,b) else { continue }
                let cost = distance[i] + abs(a.x-b.x) + abs(a.y-b.y) + 0.01
                if cost < distance[j] {
                    distance[j] = cost; previous[j] = i
                    if !queued[j] { queue.append(j); queued[j] = true }
                }
            }
        }
        guard distance[target].isFinite else { return [] }
        var reversed: [CGPoint] = [], cursor = target
        while cursor != source { reversed.append(point(cursor)); cursor = previous[cursor] }
        return simplify([start,s] + reversed.reversed() + [end])
    }
    static func crossings(_ path: [CGPoint], others: [[CGPoint]]) -> [Crossing] {
        var result: [Crossing] = []
        let branches = junctions([path] + others)
        for (i, pair) in segments(path).enumerated() {
            let (a,b) = pair
            guard a.x == b.x, a.y != b.y else { continue }
            for other in others {
                for (c,d) in segments(other) where c.y == d.y && c.x != d.x {
                    guard a.x > min(c.x,d.x), a.x < max(c.x,d.x), c.y > min(a.y,b.y), c.y < max(a.y,b.y) else { continue }
                    let p = CGPoint(x:a.x,y:c.y)
                    guard !branches.contains(p) else { continue }
                    let room = min(abs(p.y-a.y),abs(p.y-b.y))
                    let crossing = Crossing(point:p,segment:i,radius:room >= 7 ? 7 : 0)
                    if !result.contains(crossing) { result.append(crossing) }
                }
            }
        }
        return result
    }
    /// Resolve ambiguous neighboring hit targets by distance to the visible line.
    /// A finite maximum distance lets the canvas distinguish lines from blank space.
    static func nearestInteriorSegment(to point: CGPoint, paths: [[CGPoint]], maximumDistance: CGFloat = .infinity, translation: CGSize = .zero) -> (wire: Int, segment: Int)? {
        var nearest: (wire: Int, segment: Int)?
        var distance = CGFloat.infinity
        var perpendicularMotion: CGFloat = -1
        for (wire, path) in paths.enumerated() where path.count > 3 {
            for segment in 1..<(path.count-2) {
                let a = path[segment], b = path[segment+1]
                guard a != b else { continue }
                let x = min(max(point.x, min(a.x,b.x)), max(a.x,b.x))
                let y = min(max(point.y, min(a.y,b.y)), max(a.y,b.y))
                let squared = (point.x-x)*(point.x-x) + (point.y-y)*(point.y-y)
                // At an exact crossing both lines are equally close. Prefer the
                // line perpendicular to the initial movement, then lock it upstream.
                let motion = a.y == b.y ? abs(translation.height) : abs(translation.width)
                if squared <= maximumDistance * maximumDistance &&
                    (squared < distance || (squared == distance && motion > perpendicularMotion)) {
                    perpendicularMotion = motion
                    distance = squared
                    nearest = (wire, segment)
                }
            }
        }
        return nearest
    }

    static func moved(_ path: [CGPoint], segment: Int, delta: CGFloat, bodies: [CGRect], minimumTerminalLead: CGFloat = 0) -> [CGPoint] {
        guard segment > 0, segment+1 < path.count-1 else { return path }
        let horizontal = path[segment].y == path[segment+1].y
        func candidate(_ amount: CGFloat) -> [CGPoint] {
            var p = path
            if horizontal { p[segment].y += amount; p[segment+1].y += amount }
            else { p[segment].x += amount; p[segment+1].x += amount }
            return p
        }
        func valid(_ p: [CGPoint]) -> Bool {
            guard !segments(p).contains(where: { a,b in bodies.contains { intersectsInterior(a,b,$0) } }) else { return false }
            if minimumTerminalLead > 0 {
                for (pin,next,originalNext) in [(p[0],p[1],path[1]),(p.last!,p[p.count-2],path[path.count-2])] {
                    let dx = originalNext.x-pin.x, dy = originalNext.y-pin.y
                    let length = abs(dx)+abs(dy)
                    guard length > 0, ((next.x-pin.x)*dx+(next.y-pin.y)*dy)/length >= minimumTerminalLead else { return false }
                }
                for (a,b) in segments(p).dropFirst().dropLast() {
                    if bodies.contains(where: { intersectsInterior(a,b,$0.insetBy(dx:-12,dy:-12)) }) { return false }
                }
            }
            return true
        }
        // Sweep to the first boundary, so a large gesture cannot tunnel through a body.
        var accepted: CGFloat = 0
        let steps = max(1,Int(ceil(abs(delta))))
        for step in 1...steps {
            let amount = delta * CGFloat(step)/CGFloat(steps)
            if !valid(candidate(amount)) {
                var low = accepted, high = amount
                for _ in 0..<24 { let mid = (low+high)/2; if valid(candidate(mid)) { low = mid } else { high = mid } }
                return candidate(low)
            }
            accepted = amount
        }
        return candidate(accepted)
    }
    static func reattach(_ path: [CGPoint], start: CGPoint, end: CGPoint) -> [CGPoint] {
        guard path.count >= 4 else { return path }
        var p = path
        if path[0].x == path[1].x { p[1].x = start.x } else { p[1].y = start.y }
        if path[path.count-1].x == path[path.count-2].x { p[p.count-2].x = end.x }
        else { p[p.count-2].y = end.y }
        p[0] = start; p[p.count-1] = end
        return p
    }
}
