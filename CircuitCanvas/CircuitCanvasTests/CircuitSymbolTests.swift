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
        #expect(SymbolKind.allCases.count == 41)
        #expect(SymbolKind.allCases.filter(\.isBlock).count == 5)
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
}
