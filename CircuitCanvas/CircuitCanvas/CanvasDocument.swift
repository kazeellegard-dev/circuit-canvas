//
//  CanvasDocument.swift
//  CircuitCanvas
//
//  The saved file format (.circuitcanvas: versioned JSON) and the file reading/writing around it.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Declared in CircuitCanvas-Info.plist (UTExportedTypeDeclarations), with the .circuitcanvas extension.
    static let circuitCanvas = UTType(exportedAs: "com.kazeellegard.circuitcanvas.diagram", conformingTo: .json)
}

/// Everything a saved diagram holds. Selections, tools, the Undo history and device preferences (grid
/// snapping, the onboarding flag) are deliberately not part of it.
struct CanvasDocument: Codable, Equatable {
    /// Bumped whenever the format changes in a way an older app could not read correctly.
    static let currentVersion = 1

    struct Viewport: Codable, Equatable {
        var scale: CGFloat
        var offset: CGSize
    }

    var version = CanvasDocument.currentVersion
    var name: String
    var description: String
    var symbols: [SymbolItem]
    var notes: [NoteItem]
    var texts: [TextItem]
    var wires: [WireItem]
    var groups: [GroupItem]
    /// Where the canvas was scrolled to and how far it was zoomed; nil in a file written without one.
    var viewport: Viewport?

    enum ReadError: LocalizedError {
        case newerVersion(Int)
        case unreadable
        var errorDescription: String? {
            switch self {
            case .newerVersion(let version): "新しいバージョンのアプリで保存されたファイルです（形式 \(version)）。アプリを更新してから開いてください。"
            case .unreadable: "ファイルが壊れているか、Circuit Canvas のファイルではありません。"
            }
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> CanvasDocument {
        // The version is checked on its own first, so a newer file is reported as such rather than as broken.
        struct VersionOnly: Decodable { var version: Int }
        guard let version = try? JSONDecoder().decode(VersionOnly.self, from: data).version else { throw ReadError.unreadable }
        guard version <= currentVersion else { throw ReadError.newerVersion(version) }
        guard let document = try? JSONDecoder().decode(CanvasDocument.self, from: data) else { throw ReadError.unreadable }
        return document
    }

    /// Reads a file picked in Files (or opened from it), which may live outside the sandbox (iCloud Drive).
    static func read(from url: URL) throws -> CanvasDocument {
        try FileAccess.coordinated(url, writing: false) { try decoded(from: Data(contentsOf: $0)) }
    }

    /// Writes atomically, so a failure part-way leaves the previous file intact.
    func write(to url: URL) throws {
        let data = try encoded()
        try FileAccess.coordinated(url, writing: true) { try data.write(to: $0, options: .atomic) }
    }
}

enum FileAccess {
    /// Runs `body` with security-scoped access to `url` (needed for files outside the sandbox, picked in
    /// Files) under an NSFileCoordinator, so iCloud Drive never sees a half-read or half-written file.
    static func coordinated<T>(_ url: URL, writing: Bool, _ body: (URL) throws -> T) throws -> T {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<T, Error>?
        let coordinator = NSFileCoordinator()
        if writing {
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
                result = Result { try body(url) }
            }
        } else {
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
                result = Result { try body(url) }
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileNoSuchFile) }
        return try result.get()
    }

    /// The file's modification date as it is now on disk (nil if it cannot be read), used to notice that
    /// another device or app changed a file since this app last read or wrote it.
    static func modificationDate(of url: URL) -> Date? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}

/// The value fileExporter writes for "別名で保存".
struct CanvasFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.circuitCanvas]
    var document: CanvasDocument
    init(document: CanvasDocument) { self.document = document }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CanvasDocument.ReadError.unreadable }
        document = try CanvasDocument.decoded(from: data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try document.encoded())
    }
}

/// File commands for the menu bar (iPad with a keyboard, Mac): the focused canvas window publishes these.
struct DocumentCommandActions {
    var new: () -> Void
    var open: () -> Void
    var save: () -> Void
    var saveAs: () -> Void
    var export: () -> Void
}

extension FocusedValues {
    @Entry var documentCommands: DocumentCommandActions?
}

struct DocumentCommands: Commands {
    @FocusedValue(\.documentCommands) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新規") { actions?.new() }.keyboardShortcut("n").disabled(actions == nil)
            Button("開く…") { actions?.open() }.keyboardShortcut("o").disabled(actions == nil)
        }
        CommandGroup(replacing: .saveItem) {
            Button("保存") { actions?.save() }.keyboardShortcut("s").disabled(actions == nil)
            Button("別名で保存…") { actions?.saveAs() }.keyboardShortcut("s", modifiers: [.command, .shift]).disabled(actions == nil)
        }
        CommandGroup(replacing: .importExport) {
            Button("書き出す（PDF・PNG）…") { actions?.export() }.keyboardShortcut("e").disabled(actions == nil)
        }
    }
}
