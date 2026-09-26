import Testing
import SwiftUI
@testable import CircuitCanvas

struct CircuitSymbolTests {
    @Test func terminalCountsAndCoordinates() {
        for kind in SymbolKind.allCases {
            let pins = kind.pins(at: CGPoint(x:300,y:200))
            #expect(pins.first == CGPoint(x:225,y:200))
            if kind == .ground || kind == .vcc {
                #expect(pins.count == 1)
            } else {
                #expect(pins == [CGPoint(x:225,y:200),CGPoint(x:375,y:200)])
            }
        }
    }

    @Test func catalogueAndVectorGeometry() {
        #expect(SymbolKind.allCases.count == 28)
        #expect(SymbolKind.allCases.filter(\.isBlock).count == 5)
        for kind in SymbolKind.allCases where !kind.isBlock {
            let path = CircuitSymbolShape(kind:kind).path(in:CGRect(x:0,y:0,width:150,height:64))
            #expect(!path.isEmpty)
            #expect(path.boundingRect.minX == 0)
            #expect(path.boundingRect.maxX == (kind.pinCount == 2 ? 150 : kind == .ground ? 90 : 88))
            #expect(path.boundingRect.minY >= 0)
            #expect(path.boundingRect.maxY <= 53)
        }
    }
}
