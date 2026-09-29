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
        let document = sample()
        try document.write(to: url)
        #expect(try CanvasDocument.read(from: url) == document)
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

    @Test func aFileChangedElsewhereIsNotOverwritten() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).circuitcanvas")
        defer { try? FileManager.default.removeItem(at: url) }
        let mine = sample()
        let written = try mine.write(to: url, unlessModifiedSince: nil)
        let (read, readDate) = try CanvasDocument.readWithDate(from: url)
        #expect(read == mine)
        #expect(readDate == written)

        // Another device (via iCloud Drive) replaces the file after this app last read it.
        var theirs = mine; theirs.name = "ほかの端末"
        try theirs.encoded().write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: url.path(percentEncoded: false))
        var edited = mine; edited.name = "この端末"
        #expect(throws: CanvasDocument.WriteError.self) { try edited.write(to: url, unlessModifiedSince: readDate) }
        #expect(try CanvasDocument.read(from: url).name == "ほかの端末", "the other device's version must survive")

        // Overwriting on purpose (no expected date) still works, and reports the new date.
        let forced = try edited.write(to: url, unlessModifiedSince: nil)
        #expect(try CanvasDocument.readWithDate(from: url).modified == forced)
        #expect(try CanvasDocument.read(from: url).name == "この端末")
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

    /// A circuit symbol's name hangs outside its body (below it, or to its right when turned): the exported
    /// area must still hold all of it, however long, at every rotation.
    @Test func exportedAreaHoldsASymbolsWholeNameAtEveryRotation() throws {
        for rotation in [0, 90, 180, 270] {
            var symbol = SymbolItem(title: "R12 10kΩ 1/4W 金属皮膜 抵抗器", kind: .resistor, position: CGPoint(x: 1200, y: 900))
            symbol.rotation = rotation
            let label = try #require(symbol.kind.labelRect(title: symbol.title, rotation: rotation, size: symbol.size, blockPins: symbol.blockPins))
                .offsetBy(dx: symbol.position.x, dy: symbol.position.y)
            let area = try #require(ExportLayout.bounds(of: ExportLayout.symbolRects(symbol), in: canvas))
            #expect(area.contains(label), "rotation \(rotation): label \(label) outside \(area)")
            // The label really is outside the body: without it the area would be too small.
            let bodyOnly = try #require(ExportLayout.bounds(of: [symbol.kind.body(at: symbol.position, rotation: rotation, size: symbol.size)], in: canvas))
            #expect(!bodyOnly.contains(label), "rotation \(rotation)")
        }
    }

    @Test func aBlocksTitleIsInsideItsBody() {
        let block = SymbolItem(title: "Main MCU", kind: .block, position: CGPoint(x: 300, y: 300))
        #expect(block.kind.labelRect(title: block.title, rotation: 0, size: block.size, blockPins: block.blockPins) == nil)
        #expect(ExportLayout.symbolRects(block).count == 1)
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

@MainActor struct SaveContinuationTests {
    enum Action: Equatable { case new, open }

    @Test func runsOnlyAfterItsOwnSaveSucceedsAndOnlyOnce() {
        var continuation = SaveContinuation<Action>()
        continuation.saveStarted(continuingWith: .new)
        #expect(continuation.saveFinished(succeeded: true) == .new)
        #expect(continuation.saveFinished(succeeded: true) == nil, "carried out once only")
    }

    @Test func aFailedSaveDropsIt() {
        var continuation = SaveContinuation<Action>()
        continuation.saveStarted(continuingWith: .new)
        #expect(continuation.saveFinished(succeeded: false) == nil)
        #expect(continuation.saveFinished(succeeded: true) == nil, "a later save must not revive it")
    }

    /// Codex round 2: 新規 → 保存… → cancel the panel → 開く → 保存しないで続ける → a later save must not
    /// suddenly start a blank diagram.
    @Test func aCancelledPanelFollowedByAnotherDocumentSwitchDropsIt() {
        var continuation = SaveContinuation<Action>()
        continuation.saveStarted(continuingWith: .new)
        // (cancelled: no completion arrives)
        continuation.documentReplacementRequested()
        #expect(continuation.pending == nil)
        #expect(continuation.saveFinished(succeeded: true) == nil)
    }

    @Test func anyOtherSaveDropsIt() {
        var continuation = SaveContinuation<Action>()
        continuation.saveStarted(continuingWith: .open)
        continuation.otherSaveStarted()
        #expect(continuation.saveFinished(succeeded: true) == nil)
    }
}
