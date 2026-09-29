//
//  CanvasModel.swift
//  CircuitCanvas
//
//  The diagram's own content types, shared by the editor (ContentView) and the saved file format
//  (CanvasDocument). Moved out of ContentView.swift, unchanged apart from Codable/Equatable.
//

import SwiftUI

/// Resizing of experiment notes: 20pt steps, wide enough to read the body text at the minimum size.
enum NoteSize {
    static let step: CGFloat = 20
    // Aligned to `standard` (170,100) so the first resize snaps predictably rather than jumping to a
    // grid the starting size does not sit on.
    static let minimum = CGSize(width:150,height:80)
    static let maximum = CGSize(width:390,height:320)
    static let standard = CGSize(width:170,height:100)
    static func snapped(_ proposed: CGSize) -> CGSize { ResizableGeometry.snapped(proposed, step:step, minimum:minimum, maximum:maximum) }
    static func handleRect(body: CGRect, sx: CGFloat, sy: CGFloat, scale: CGFloat) -> CGRect {
        ResizableGeometry.handleRect(body:body, sx:sx, sy:sy, scale:scale)
    }
    static func resized(center: CGPoint, size: CGSize, sx: CGFloat, sy: CGFloat, translation: CGSize) -> (center: CGPoint, size: CGSize) {
        ResizableGeometry.resized(center:center, size:size, sx:sx, sy:sy, translation:translation, step:step, minimum:minimum, maximum:maximum)
    }
}
/// One member of a group (5E) - a group can freely mix symbols, notes, and texts.
enum GroupMember: Hashable {
    case symbol(UUID), note(UUID), text(UUID)
}
/// A flat collection of symbols/notes/texts that move, get selected, and get deleted together. Never
/// nested, per this task's own scope - grouping a selection that touches an existing group's members
/// widens that same group instead of creating a group-of-groups (see createOrMergeGroup).
struct GroupItem: Identifiable {
    var id = UUID()
    var members: Set<GroupMember>
}
enum NoteType: String, CaseIterable, Identifiable {
    case modification = "改造", measurement = "測定", confirmation = "確認", unresolved = "未解決", caution = "注意", memo = "メモ"
    var id: Self { self }
    /// The icon associated with this type; also the default icon a newly created note starts with.
    var icon: String {
        switch self {
        case .modification: "wrench.and.screwdriver.fill"
        case .measurement: "waveform"
        case .confirmation: "checkmark.seal.fill"
        case .unresolved: "exclamationmark.triangle.fill"
        case .caution: "exclamationmark.circle.fill"
        case .memo: "note.text"
        }
    }
}
/// The corner of a note that a relate line starts from - tapped explicitly (like choosing a wire's pin),
/// rather than always the note's center. Follows the note's bounds, so only the note-side end moves when
/// the note is dragged; the far end (the note's `anchor`) is a fixed canvas point that never moves.
enum NoteCorner: String, CaseIterable, Identifiable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
    var id: Self { self }
    func point(in bounds: CGRect) -> CGPoint {
        switch self {
        case .topLeading: CGPoint(x: bounds.minX, y: bounds.minY)
        case .topTrailing: CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeading: CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomTrailing: CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }
}
struct SymbolItem: Identifiable {
    var id = UUID(); var title: String; var kind: SymbolKind; var position: CGPoint; var rotation: Int; var size: CGSize
    var icon: String   // Stored (not derived from kind): the user can change a block's icon after placing it.
    var blockPins: [SymbolKind.BlockPin]   // Meaningful only when kind.isBlock; circuit symbols use kind.pinSpecs.
    init(title: String, kind: SymbolKind, position: CGPoint, icon: String? = nil) {
        self.title = title; self.kind = kind; self.position = position
        self.rotation = kind.defaultRotation; self.size = kind.frameSize
        self.icon = icon ?? kind.icon
        self.blockPins = SymbolKind.defaultBlockPins
    }
}
struct NoteItem: Identifiable {
    var id = UUID(); var type: NoteType = .modification; var title: String; var body: String; var position: CGPoint
    var complete = false; var anchor: CGPoint?; var relateCorner: NoteCorner = .topLeading; var size: CGSize = NoteSize.standard
    var icon: String
    init(type: NoteType = .modification, title: String, body: String, position: CGPoint, anchor: CGPoint? = nil, icon: String? = nil) {
        self.type = type; self.title = title; self.body = body; self.position = position; self.anchor = anchor
        self.icon = icon ?? type.icon
    }
}
/// A plain text label (5C): unlike a note, it has no type/icon/anchor/resize - just content and a position.
/// No pins, so it can never be wired.
struct TextItem: Identifiable {
    var id = UUID(); var body: String; var position: CGPoint
    init(body: String = "テキスト", position: CGPoint) { self.body = body; self.position = position }
}
struct WireItem: Identifiable { var id = UUID(); var start: CGPoint; var end: CGPoint; var points: [CGPoint] = []; var manual = false; var manualPoints: [CGPoint] = [] }

// Saved as-is in the file format (CanvasDocument): ids are kept, since groups refer to their members by id.
extension SymbolKind: Codable {}
extension GroupMember: Codable {}
extension GroupItem: Codable, Equatable {}
extension NoteType: Codable {}
extension NoteCorner: Codable {}
extension SymbolItem: Codable, Equatable {}
extension NoteItem: Codable, Equatable {}
extension TextItem: Codable, Equatable {}
extension WireItem: Codable, Equatable {}
