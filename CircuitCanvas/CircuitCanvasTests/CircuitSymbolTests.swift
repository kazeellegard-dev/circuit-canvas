import Testing
import SwiftUI
@testable import CircuitCanvas

struct CircuitSymbolTests {
    @Test func terminalCountsAndCoordinates() {
        let center = CGPoint(x:300,y:200)
        for kind in SymbolKind.allCases {
            #expect(kind.pins(at:center).count == kind.pinCount)
            if kind.isBlock {
                #expect(kind.pins(at:center) == [CGPoint(x:225,y:200),CGPoint(x:375,y:200)])
            } else {
                for rotation in [0,90,180,270] {
                    let pins = kind.pins(at:center,rotation:rotation)
                    let first = [CGPoint(x:250,y:200),CGPoint(x:300,y:150),CGPoint(x:350,y:200),CGPoint(x:300,y:250)][rotation/90]
                    #expect(pins[0] == first)
                    #expect(kind.direction(for:0,rotation:rotation).rawValue == rotation/90)
                    #expect(kind.direction(for:1,rotation:rotation).rawValue == (rotation/90+2)%4)
                    if pins.count == 2 { #expect(pins[1] == CGPoint(x:600-first.x,y:400-first.y)) }
                    let body = kind.body(at:center,rotation:rotation)
                    #expect(body.midX == center.x && body.midY == center.y)
                    #expect(body.size == CGSize(width:rotation % 180 == 0 ? 100 : 50,height:rotation % 180 == 0 ? 50 : 100))
                }
            }
        }
    }

    @Test func defaultPowerOrientationsAndUprightLetters() {
        for kind in SymbolKind.allCases {
            #expect(kind.defaultRotation == (kind == .vcc ? 270 : kind.category == .power ? 90 : 0))
        }
        #expect(SymbolKind.motor.letter == "M")
        #expect(SymbolKind.voltmeter.letter == "V")
        #expect(SymbolKind.ammeter.letter == "A")
    }

    @Test func catalogueAndVectorGeometry() {
        #expect(SymbolKind.allCases.count == 28)
        #expect(SymbolKind.allCases.filter(\.isBlock).count == 5)
        for kind in SymbolKind.allCases where !kind.isBlock {
            let path = CircuitSymbolShape(kind:kind).path(in:CGRect(x:0,y:0,width:100,height:50))
            #expect(!path.isEmpty)
            #expect(path.boundingRect.minX == 0)
            #expect(path.boundingRect.maxX <= 100)
            #expect(path.boundingRect.minY >= 0)
            #expect(path.boundingRect.maxY <= 50)
        }
    }
    @Test func externalLeadsAreTwentyFivePointsExceptNarrowPlateSymbols() {
        let plates: Set<SymbolKind> = [.dc, .battery, .capacitor, .polarizedCapacitor, .diode, .led, .zener, .photodiode]
        for kind in SymbolKind.allCases where !kind.isBlock && kind.pinCount == 2 {
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
            // Half of the former 50pt leads; plate and diode bodies are narrower, so their leads are longer.
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
