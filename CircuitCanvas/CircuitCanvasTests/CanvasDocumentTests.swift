import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CircuitCanvas

@MainActor struct CanvasDocumentTests {
    private func sample() -> CanvasDocument {
        var block = SymbolItem(title: "Main MCU", kind: .block, position: .init(x: 370, y: 250), icon: "cpu")
        block.blockPins.append(.init(side: .right, slot: 1))
        block.rotation = 90
        var note = NoteItem(type: .unresolved, title: "R12", body: "10 kΩ", position: .init(x: 430, y: 80), anchor: .init(x: 370, y: 190))
        note.complete = true; note.relateCorner = .bottomTrailing; note.size = .init(width: 210, height: 120)
        let text = TextItem(body: "電源系", position: .init(x: 100, y: 500))
        var wire = WireItem(start: .init(x: 165, y: 160), end: .init(x: 325, y: 250))
        wire.points = [.init(x: 165, y: 160), .init(x: 245, y: 160), .init(x: 245, y: 250), .init(x: 325, y: 250)]
        wire.manual = true; wire.manualPoints = [.init(x: 245, y: 200)]
        let group = GroupItem(members: [.symbol(block.id), .text(text.id)])
        return CanvasDocument(name: "実験用基板", description: "1行目\n2行目", symbols: [block], notes: [note], texts: [text],
                              wires: [wire], groups: [group], viewport: .init(scale: 1.5, offset: .init(width: -120, height: 40)))
    }

    @Test func roundTripKeepsEverythingIncludingIDs() throws {
        let document = sample()
        let decoded = try CanvasDocument.decoded(from: document.encoded())
        #expect(decoded == document)
        // Groups refer to their members by id, so the ids themselves must survive.
        #expect(decoded.groups[0].members.contains(.symbol(decoded.symbols[0].id)))
        #expect(decoded.version == CanvasDocument.currentVersion)
    }

    @Test func writesAndReadsAFile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).circuitcanvas")
        defer { try? FileManager.default.removeItem(at: url) }
        try sample().write(to: url)
        #expect(try CanvasDocument.read(from: url) == sample())
    }

    @Test func aNewerFormatIsReportedAsSuchNotAsBroken() throws {
        var json = try JSONSerialization.jsonObject(with: sample().encoded()) as! [String: Any]
        json["version"] = CanvasDocument.currentVersion + 1
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect {
            try CanvasDocument.decoded(from: data)
        } throws: { error in
            if case CanvasDocument.ReadError.newerVersion(let version) = error { version == CanvasDocument.currentVersion + 1 } else { false }
        }
    }

    @Test func somethingElseIsUnreadable() {
        for data in [Data("not json".utf8), Data(#"{"version":1,"name":"x"}"#.utf8)] {
            #expect {
                try CanvasDocument.decoded(from: data)
            } throws: { error in
                if case CanvasDocument.ReadError.unreadable = error { true } else { false }
            }
        }
    }

    @Test func aFailedReadNeverTouchesTheFile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).circuitcanvas")
        defer { try? FileManager.default.removeItem(at: url) }
        let broken = Data("{ broken".utf8)
        try broken.write(to: url)
        #expect(throws: CanvasDocument.ReadError.self) { try CanvasDocument.read(from: url) }
        #expect(try Data(contentsOf: url) == broken)
    }
}

@MainActor struct ExportTests {
    private let canvas = CGRect(x: 0, y: 0, width: 2400, height: 1800)

    @Test func nothingDrawnMeansNothingToExport() {
        #expect(ExportLayout.bounds(of: [], in: canvas) == nil)
        #expect(ExportLayout.bounds(of: [.null], in: canvas) == nil)
    }

    @Test func boundsCoverEverythingPlusTheMargin() {
        let area = ExportLayout.bounds(of: [CGRect(x: 100, y: 200, width: 50, height: 40), CGRect(origin: .init(x: 400, y: 300), size: .zero)], in: canvas)
        let m = ExportLayout.margin
        #expect(area == CGRect(x: 100 - m, y: 200 - m, width: 300 + 2*m, height: 100 + 2*m))
    }

    @Test func boundsStayOnTheCanvas() {
        let area = ExportLayout.bounds(of: [CGRect(x: 5, y: 10, width: 2390, height: 1785)], in: canvas)
        #expect(area == canvas)
    }

    @Test func fileNamesAvoidPathSeparators() {
        #expect(ExportLayout.fileName(for: "24 V / 5 V: 基板") == "24 V - 5 V- 基板")
        #expect(ExportLayout.fileName(for: "   ") == "Circuit Canvas")
    }

    @Test func pdfIsOnePageOfTheDrawingsSize() throws {
        let size = CGSize(width: 300, height: 200)
        let data = try #require(ExportRenderer.data(for: Color.red, size: size, format: .pdf))
        let summary = try #require(ExportRenderer.summary(of: data, format: .pdf))
        #expect(summary.pages == 1)
        #expect(summary.size == size)
    }

    @Test func pngIsTwiceTheDrawingsSizeInPixels() throws {
        let data = try #require(ExportRenderer.data(for: Color.red, size: CGSize(width: 300, height: 200), format: .png))
        let summary = try #require(ExportRenderer.summary(of: data, format: .png))
        #expect(summary.size == CGSize(width: 600, height: 400))
    }
}
