//
//  ContentView.swift
//  CircuitCanvas
//
//  Created by Toru Yamaguchi on 2026/09/20.
//

import SwiftUI
import UIKit

private enum ResizeCorner: String, CaseIterable, Identifiable {
    case tl, tr, bl, br
    var id: String { rawValue }
    var sx: CGFloat { self == .tl || self == .bl ? -1 : 1 }
    var sy: CGFloat { self == .tl || self == .tr ? -1 : 1 }
}
/// Resizing of experiment notes: 20pt steps, wide enough to read the body text at the minimum size.
private enum NoteSize {
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
private enum Tool { case select, symbol, note, text, wire, pan }
/// What the ✗ badge (edit mode, 4C) is about to delete, pending its confirmation alert.
private enum EditDeleteTarget: Identifiable {
    case symbol(UUID), note(UUID), text(UUID)
    var id: String { switch self { case .symbol(let id): "symbol-\(id)"; case .note(let id): "note-\(id)"; case .text(let id): "text-\(id)" } }
}
/// Which inspector text field (5D) is being edited live, on the canvas, with every other element dimmed and
/// unreachable. Only text-entry fields (name/title/body) - the picker fields (種別・アイコン) are unaffected,
/// per this task's own scope.
private enum LiveEditTarget: Equatable {
    case symbolTitle(UUID), noteTitle(UUID), noteBody(UUID), textBody(UUID)
}
private enum NoteType: String, CaseIterable, Identifiable {
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
/// Categorised SF Symbols for a note's icon: one per NoteType (6, memo included) plus a few generic ones,
/// for ~10 total - mirrors BlockIcon's grouping, reused by the same IconPickerView.
private enum NoteIcon {
    static let categories: [(name: String, icons: [String])] = [
        ("種別のアイコン", NoteType.allCases.map(\.icon)),
        ("その他", ["tag.fill", "flag.fill", "star.fill", "pin.fill"])
    ]
}
/// The corner of a note that a relate line starts from - tapped explicitly (like choosing a wire's pin),
/// rather than always the note's center. Follows the note's bounds, so only the note-side end moves when
/// the note is dragged; the far end (the note's `anchor`) is a fixed canvas point that never moves.
private enum NoteCorner: String, CaseIterable, Identifiable {
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
private struct SymbolItem: Identifiable {
    let id = UUID(); var title: String; var kind: SymbolKind; var position: CGPoint; var rotation: Int; var size: CGSize
    var icon: String   // Stored (not derived from kind): the user can change a block's icon after placing it.
    var blockPins: [SymbolKind.BlockPin]   // Meaningful only when kind.isBlock; circuit symbols use kind.pinSpecs.
    init(title: String, kind: SymbolKind, position: CGPoint, icon: String? = nil) {
        self.title = title; self.kind = kind; self.position = position
        self.rotation = kind.defaultRotation; self.size = kind.frameSize
        self.icon = icon ?? kind.icon
        self.blockPins = SymbolKind.defaultBlockPins
    }
}
private struct NoteItem: Identifiable {
    let id = UUID(); var type: NoteType = .modification; var title: String; var body: String; var position: CGPoint
    var complete = false; var anchor: CGPoint?; var relateCorner: NoteCorner = .topLeading; var size: CGSize = NoteSize.standard
    var icon: String
    init(type: NoteType = .modification, title: String, body: String, position: CGPoint, anchor: CGPoint? = nil, icon: String? = nil) {
        self.type = type; self.title = title; self.body = body; self.position = position; self.anchor = anchor
        self.icon = icon ?? type.icon
    }
}
/// A plain text label (5C): unlike a note, it has no type/icon/anchor/resize - just content and a position.
/// No pins, so it can never be wired.
private struct TextItem: Identifiable {
    let id = UUID(); var body: String; var position: CGPoint
    init(body: String = "テキスト", position: CGPoint) { self.body = body; self.position = position }
}
private struct WireItem: Identifiable { let id = UUID(); var start: CGPoint; var end: CGPoint; var points: [CGPoint] = []; var manual = false; var manualPoints: [CGPoint] = [] }
/// One Undo/Redo step (4D): the whole diagram's content, from just before one meaningful operation. Simpler
/// and safer than hooking every mutation individually into SwiftUI's UndoManager, at the cost of copying
/// three arrays per step - trivial at this diagram's scale, and capped (maxUndoSteps) regardless.
private struct CanvasSnapshot { var symbols: [SymbolItem]; var notes: [NoteItem]; var texts: [TextItem]; var wires: [WireItem] }

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var tool: Tool = .select
    @State private var selectedLibrary: SymbolKind = .block
    @State private var selectedCategory: SymbolCategory = .block
    @State private var selectedSymbol: UUID?
    @State private var selectedNote: UUID?
    @State private var selectedText: UUID?
    @State private var linkingNote: UUID?   // relate button pressed: waiting for a corner tap on this note
    @State private var pendingRelateFrom: (id: UUID, corner: NoteCorner)?   // corner tapped: waiting for the target tap
    @State private var pendingWireStart: CGPoint?
    @State private var dragOrigins: [UUID: CGPoint] = [:]
    @State private var noteDragOrigins: [UUID: CGPoint] = [:]
    @State private var textDragOrigins: [UUID: CGPoint] = [:]
    private struct SegmentDrag {
        let wireID: UUID
        let segment: Int
        let origin: [CGPoint]
    }
    private struct ResizeDrag { let id: UUID; let center: CGPoint; let size: CGSize }
    @State private var resizeDrag: ResizeDrag?
    @State private var noteResizeDrag: ResizeDrag?
    @State private var segmentDrag: SegmentDrag?
    /// True while any single-finger edit drag (symbol/note move, either resize, a wire segment) is already
    /// tracking a touch. Gates the two-finger pan overlay: a second finger joining an in-progress edit drag
    /// must not also start panning the canvas underneath it (Codex major, 5B round 2).
    private var isEditDragActive: Bool {
        !dragOrigins.isEmpty || !noteDragOrigins.isEmpty || !textDragOrigins.isEmpty || resizeDrag != nil || noteResizeDrag != nil || segmentDrag != nil
    }
    /// Edit mode has its own exclusive UI; live-editing a field on the canvas (5D) does too - every other
    /// toolbar action and library tile is unreachable during either.
    private var toolbarDisabled: Bool { editMode || liveEdit != nil }
    /// Which of the two mutually-exclusive ways of panning (5B: pan-tool one-finger drag, or a two-finger
    /// drag anywhere) currently owns canvasOffset/canvasPanOrigin. Only one may update them at a time -
    /// without this, both ending independently (each setting canvasPanOrigin = canvasOffset) while the other
    /// is still tracking a touch would double-apply translation and make the canvas jump (Codex major, 5B
    /// round 3). Every single-finger edit drag (move/resize/segment) also refuses to start or continue while
    /// this is non-nil, for the same reason in the other direction.
    private enum PanSource { case singleFinger, twoFinger }
    @State private var activePanSource: PanSource?
    @State private var isPanningCanvas = false
    @State private var canvasOffset = CGSize.zero
    @State private var canvasPanOrigin = CGSize.zero
    @State private var canvasScale: CGFloat = 1
    @State private var canvasScaleOrigin: CGFloat = 1
    @State private var viewportSize: CGSize = .zero   // kept up to date by `editor`'s GeometryReader, for the zoom menu
    @State private var twoFingerPanAttached = false   // see TwoFingerPanOverlay.onAttached
    @State private var showLibrary = false
    @State private var showInspector = false
    @State private var showSettings = false
    @State private var showResetConfirmation = false
    @State private var canvasName = "Circuit Canvas"
    @State private var canvasDescription = ""
    @State private var editMode = false
    @State private var pendingDelete: EditDeleteTarget?
    @State private var liveEdit: LiveEditTarget?
    @State private var undoStack: [CanvasSnapshot] = []
    @State private var redoStack: [CanvasSnapshot] = []
    @State private var undoRedoUnavailableReason: String?
    private let maxUndoSteps = 20
    // Batches every field edit made during one inspector visit (title, body, type, icon - all routed through
    // symbolBinding/noteBinding's setter, once per keystroke) into a single Undo step: pushed lazily, on the
    // first actual edit, not merely on opening the sheet to look.
    @State private var inspectorSessionPushed = false
    @State private var symbols: [SymbolItem] = [
        // All four kinds folded into the single generic block; the icon is kept explicit so the look does not change.
        .init(title: "24 V → 5 V", kind: .block, position: .init(x: 120, y: 160), icon: "bolt.fill"),
        .init(title: "Main MCU", kind: .block, position: .init(x: 370, y: 250), icon: "cpu"),
        .init(title: "CAN", kind: .block, position: .init(x: 620, y: 250), icon: "arrow.left.and.right"),
        .init(title: "Temperature", kind: .block, position: .init(x: 120, y: 390), icon: "sensor.tag.radiowaves.forward")
    ]
    @State private var notes: [NoteItem] = [.init(title: "R12を変更", body: "10 kΩへ変更して波形を再測定", position: .init(x: 430, y: 80), anchor: .init(x: 370, y: 190))]
    @State private var texts: [TextItem] = []
    @State private var wires: [WireItem] = [
        .init(start: .init(x: 165, y: 160), end: .init(x: 325, y: 250)),
        .init(start: .init(x: 415, y: 250), end: .init(x: 575, y: 250)),
        .init(start: .init(x: 165, y: 390), end: .init(x: 325, y: 250))
    ]

    private var compact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        NavigationStack {
            Group {
                VStack(spacing: 0) {
                    editor
                    Divider()
                    libraryView.frame(height: 132)
                }
            }
            .navigationTitle(canvasName)
            .onAppear {
                reroute()
                // Test-only hook (Codex review, 4E round 3): XCUITest's synthetic pinch cannot reliably reach
                // a non-preset scale in this harness, so a UI test that must start from one (e.g. to check
                // the zoom menu against a "candidate外" value, per this task's acceptance criterion 3) sets
                // this launch environment variable instead. Absent in every normal launch, so it changes
                // nothing outside a test that deliberately opts in.
                if let raw = ProcessInfo.processInfo.environment["UITEST_INITIAL_ZOOM"], let value = Double(raw) {
                    canvasScale = value; canvasScaleOrigin = value
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Left enabled during edit mode on purpose: undoing an accidental delete is exactly the
                    // safety net this exists for, and it would defeat the point to grey it out right then.
                    Button("元に戻す", systemImage: "arrow.uturn.backward") {
                        if undoStack.isEmpty { undoRedoUnavailableReason = "取り消す操作がありません" } else { performUndo() }
                    }
                    .disabled(undoStack.isEmpty)
                    .accessibilityIdentifier("undo-button")
                    Button("やり直す", systemImage: "arrow.uturn.forward") {
                        if redoStack.isEmpty { undoRedoUnavailableReason = "やり直す操作がありません" } else { performRedo() }
                    }
                    .disabled(redoStack.isEmpty)
                    .accessibilityIdentifier("redo-button")
                    Button("選択", systemImage: "cursorarrow") { tool = .select; linkingNote = nil; pendingRelateFrom = nil }
                        .disabled(toolbarDisabled)
                    Button("配線", systemImage: "point.3.connected.trianglepath.dotted") { tool = .wire; pendingWireStart = nil; selectedSymbol = nil; selectedNote = nil; selectedText = nil; linkingNote = nil; pendingRelateFrom = nil }
                        .disabled(toolbarDisabled)
                    // Jumps the library to whichever category the selected symbol is in, so it is visible
                    // (and its highlight legible) instead of leaving whatever tab happened to be open before.
                    Button("＋シンボル", systemImage: "plus.square.on.square") { tool = .symbol; selectedCategory = selectedLibrary.category }
                        .disabled(toolbarDisabled)
                    Button("＋メモ", systemImage: "note.text.badge.plus") { tool = .note }
                        .disabled(toolbarDisabled)
                    // A dedicated pan tool (2026-09-29 feedback): one-finger drag on empty canvas otherwise
                    // does nothing (see canvasPanGesture) - too easy to nudge the canvas by accident while
                    // trying to grab a wire lead. Two fingers can always pan regardless of tool (below).
                    Button(tool == .pan ? "キャンバス移動中" : "キャンバス移動", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
                        tool = .pan; selectedSymbol = nil; selectedNote = nil; selectedText = nil; linkingNote = nil; pendingRelateFrom = nil; pendingWireStart = nil
                    }
                    .tint(tool == .pan ? .accentColor : nil)
                    .disabled(toolbarDisabled)
                    .accessibilityIdentifier("pan-mode-toggle")
                    // The edit-mode toggle sits just left of "確認", per feedback on the toolbar's reading
                    // order; its icon was changed from a trash can (which read oddly alongside the other
                    // plain, uncoloured toolbar glyphs) to an eraser, which is red only while active.
                    Button(editMode ? "編集中" : "編集", systemImage: editMode ? "eraser.fill" : "eraser") {
                        editMode.toggle()
                        // Edit mode has its own, exclusive UI (the ✗ badges); leave no other mode's state
                        // dangling underneath it, in either direction.
                        tool = .select
                        selectedSymbol = nil; selectedNote = nil; selectedText = nil
                        linkingNote = nil; pendingRelateFrom = nil; pendingWireStart = nil
                    }
                    .tint(editMode ? .red : nil)
                    .accessibilityIdentifier("edit-mode-toggle")
                    Button("確認", systemImage: "slider.horizontal.3") { inspectorSessionPushed = false; showInspector = true }
                        .disabled(toolbarDisabled)
                    Button("設定", systemImage: "gearshape") { showSettings = true }
                        .disabled(toolbarDisabled)
                }
            }
            .sheet(isPresented: $showInspector) { NavigationStack { inspector.navigationTitle("インスペクタ") } }
            .sheet(isPresented: $showSettings) { NavigationStack { settings.navigationTitle("設定") } }
            .alert("削除しますか？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("キャンセル", role: .cancel) { pendingDelete = nil }
                Button("削除", role: .destructive) {
                    switch pendingDelete {
                    case .symbol(let id): removeSymbol(id)
                    case .note(let id): removeNote(id)
                    case .text(let id): removeText(id)
                    case .none: break
                    }
                    pendingDelete = nil
                }
            }
            .alert("できません", isPresented: Binding(get: { undoRedoUnavailableReason != nil }, set: { if !$0 { undoRedoUnavailableReason = nil } })) {
                Button("OK", role: .cancel) { undoRedoUnavailableReason = nil }
            } message: {
                Text(undoRedoUnavailableReason ?? "")
            }
        }
    }

    private var settings: some View {
        Form {
            Section("キャンバス") {
                TextField("名称", text: $canvasName)
                    .accessibilityIdentifier("settings-canvas-name")
            }
            Section("説明") {
                TextField("説明（任意）", text: $canvasDescription, axis: .vertical)
                    .accessibilityIdentifier("settings-canvas-description")
            }
            // Kept in its own section, at the very bottom, away from the harmless fields above - an
            // irreversible action deserves some distance from an accidental tap.
            Section {
                Button("キャンバスをリセット", systemImage: "trash", role: .destructive) {
                    showResetConfirmation = true
                }
                .accessibilityIdentifier("settings-reset-canvas")
            } footer: {
                Text("シンボル・配線・付箋を全て削除します。元に戻せません。")
            }
        }
        .formStyle(.grouped)
        // .alert rather than .confirmationDialog: on iPad the latter presents as a popover that, per
        // platform convention, omits its own Cancel row (tapping outside dismisses it instead) - not what
        // this irreversible action should rely on. An alert always shows both buttons explicitly.
        .alert("キャンバスをリセット", isPresented: $showResetConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("リセット", role: .destructive) { resetCanvas() }
        } message: {
            Text("本当にリセットしますか？元に戻せません。")
        }
    }

    private var libraryView: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(SymbolCategory.allCases) { category in
                        // A solid fill (not a faint tint) so the selected category is unambiguous at a
                        // glance, per feedback that the previous highlight was too light to notice.
                        Button(category.rawValue) { selectedCategory = category }
                            .font(.caption.weight(selectedCategory == category ? .semibold : .regular))
                            .foregroundStyle(selectedCategory == category ? Color.white : Color.primary)
                            .padding(8)
                            .background(selectedCategory == category ? Color.accentColor : Color.clear, in: Capsule())
                            .accessibilityIdentifier("library-category-\(category.rawValue)")
                            .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                    }
                }.padding(.horizontal, 12)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // "テキスト" is not a SymbolKind - it is its own tool (5C), so this tab shows one
                    // placeable tile instead of the usual kind grid.
                    if selectedCategory == .text {
                        Button { tool = .text } label: {
                            VStack(spacing: 5) {
                                Image(systemName: "textformat").font(.title3).frame(height: 32)
                                Text("テキスト").font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(width: 92, height: 72)
                            .foregroundStyle(tool == .text ? Color.accentColor : Color.primary)
                            .background(tool == .text ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(tool == .text ? Color.accentColor : Color.clear, lineWidth: 2))
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(toolbarDisabled)
                        .accessibilityLabel("テキストを配置")
                        .accessibilityIdentifier("library-テキスト")
                    }
                    ForEach(SymbolKind.allCases.filter { $0.category == selectedCategory }) { kind in
                        Button { selectedLibrary = kind; tool = .symbol } label: {
                            VStack(spacing: 5) {
                                if kind.isBlock {
                                    Image(systemName: kind.icon).font(.title3).frame(height: 32)
                                } else {
                                    CircuitGlyph(kind:kind, rotation:kind.defaultRotation).scaleEffect(kind.libraryScale).frame(width:70,height:50)
                                }
                                Text(kind.rawValue).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(width: 92, height: 72)
                            .foregroundStyle(selectedLibrary == kind ? Color.accentColor : Color.primary)
                            // A stronger fill plus a visible border - the previous 0.12-opacity tint alone
                            // read as barely-there next to the unselected items (feedback, 2026-09-29).
                            .background(selectedLibrary == kind ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedLibrary == kind ? Color.accentColor : Color.clear, lineWidth: 2))
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(toolbarDisabled)
                        .accessibilityLabel("\(kind.rawValue)を配置")
                        .accessibilityIdentifier("library-\(kind.rawValue)")
                    }
                }.padding(.horizontal, 12).padding(.vertical, 8)
            }.id(selectedCategory)
        }.background(.bar)
    }

    private var editor: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.clear
                    // Distinguishes "outside the canvas" from the canvas itself (which Grid, below, fills
                    // opaquely) - addressing feedback that the valid drawing area was not visible at all.
                    .background(Color(.systemGray4))
                    .contentShape(Rectangle())
                    .gesture(canvasPanGesture(in: proxy.size))
                    .simultaneousGesture(canvasTapGesture)
                    .accessibilityIdentifier("circuit-canvas")
                    .accessibilityValue("scale=\(Int(canvasScale * 100)), offsetX=\(Int(canvasOffset.width)), offsetY=\(Int(canvasOffset.height))")
                canvasContent
                    .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
                    .scaleEffect(canvasScale, anchor: .topLeading)
                    .offset(canvasOffset)
                if pendingRelateFrom != nil {
                    // While waiting for the relate target tap, any point on the canvas must resolve to
                    // setAnchor - even one over a note/symbol card, which would otherwise consume the tap
                    // with its own selection gesture first (Codex major, 4A round 1).
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(canvasTapGesture)
                        .accessibilityIdentifier("relate-target-capture")
                }
                // Two fingers can always pan, regardless of tool (5B) - scoped to this frame (see
                // TwoFingerPanOverlay's own documentation for why it must not simply overlay the canvas).
                TwoFingerPanOverlay(
                    onBegan: {
                        guard activePanSource == nil else { return }
                        activePanSource = .twoFinger
                        canvasPanOrigin = canvasOffset
                    },
                    onChanged: { translation in
                        guard activePanSource == .twoFinger else { return }
                        canvasOffset = boundedCanvasOffset(
                            CGSize(width: canvasPanOrigin.width + translation.width, height: canvasPanOrigin.height + translation.height),
                            in: proxy.size
                        )
                    },
                    onEnded: {
                        guard activePanSource == .twoFinger else { return }
                        canvasPanOrigin = canvasOffset
                        activePanSource = nil
                    },
                    isEditDragActive: { isEditDragActive || activePanSource == .singleFinger || liveEdit != nil },
                    onAttached: { twoFingerPanAttached = true }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                // Live-editing (5D) lives in viewport space, not canvas space: the edited item can sit
                // anywhere on the (much larger, pannable/zoomable) canvas, including right at its edge, and
                // a card centered exactly on its canvas position could then land partly off-screen - clamped
                // here to always stay fully reachable and tappable regardless of where the item is.
                if let target = liveEdit, let binding = liveEditBinding(for: target), let canvasPosition = liveEditPosition(for: target) {
                    Rectangle().fill(Color.black.opacity(0.45))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {}
                        .accessibilityIdentifier("live-edit-scrim")
                    liveEditCard(text: binding, multiline: liveEditIsMultiline(target))
                        .position(liveEditViewportPosition(for: target, canvasPosition: canvasPosition, viewportSize: proxy.size))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .coordinateSpace(name: "editorViewport")
            .simultaneousGesture(canvasZoomGesture)
            .clipped()
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    if editMode {
                        Label("編集モード（削除できます）", systemImage: "trash.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.red, in: Capsule())
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("edit-mode-badge")
                    }
                    if linkingNote != nil { hint("arrowshape.turn.up.right", "関連付ける角をタップ") }
                    else if pendingRelateFrom != nil { hint("arrowshape.turn.up.right", "関連付けたい位置をタップ") }
                    else if tool == .note { hint("note.text.badge.plus", "キャンバスをタップして付箋を配置") }
                    else if tool == .symbol { hint("plus.square.on.square", "\(selectedLibrary.rawValue)を配置") }
                    else if tool == .text { hint("textformat", "キャンバスをタップしてテキストを配置") }
                    else if tool == .wire { hint("point.3.connected.trianglepath.dotted", pendingWireStart == nil ? "始点のピンをタップ" : "終点のピンをタップ（直交で自動配線）") }
                    else if tool == .pan { hint("arrow.up.and.down.and.arrow.left.and.right", "ドラッグしてキャンバスを移動") }
                }.padding(16).allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                zoomIndicator
                    .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                // Exposes exactly the state setZoom(_:) itself uses, so a test can verify the viewport's
                // center canvas point precisely (not just via the Int-rounded scale in -value above) and
                // confirm it survives a zoom-menu selection even when already panned near boundedCanvasOffset's
                // edge margin (Codex major, 4E round 1).
                Text("viewportSize").font(.system(size:1)).opacity(0.01)
                    .accessibilityIdentifier("viewport-size")
                    .accessibilityValue("\(Int(viewportSize.width)),\(Int(viewportSize.height))")
                    .allowsHitTesting(false)
                Text("zoomScaleExact").font(.system(size:1)).opacity(0.01)
                    .accessibilityIdentifier("zoom-scale-exact")
                    .accessibilityValue(String(format:"%.6f",canvasScale))
                    .allowsHitTesting(false)
                // The Int-truncated offsetX/offsetY in -value (above the canvas itself) lose up to 1pt, which
                // a low zoom-out (e.g. 25%) turns into several pt of canvas-coordinate error - too coarse for
                // checking the viewport center precisely.
                Text("canvasOffsetExact").font(.system(size:1)).opacity(0.01)
                    .accessibilityIdentifier("canvas-offset-exact")
                    .accessibilityValue(String(format:"%.3f,%.3f",canvasOffset.width,canvasOffset.height))
                    .allowsHitTesting(false)
                // Whether the two-finger pan recognizer actually attached to a window - the structural half
                // of 5B a UI test can confirm; XCUITest has no public API to synthesize a genuine two-finger
                // pan itself (only tap and pinch have dedicated methods).
                Text("twoFingerPanAttached").font(.system(size:1)).opacity(0.01)
                    .accessibilityIdentifier("two-finger-pan-attached")
                    .accessibilityValue(twoFingerPanAttached ? "true" : "false")
                    .allowsHitTesting(false)
            }
            .onAppear { viewportSize = proxy.size }
            .onChange(of: proxy.size) { _, newValue in viewportSize = newValue }
        }
    }

    /// The on-canvas "倍率 n%" label doubles as the zoom menu's trigger (the toolbar used to carry a
    /// separate icon button for this; removed once there were enough toolbar icons that it started to feel
    /// crowded - tapping the existing, always-visible label is one fewer icon to make room for).
    private var zoomIndicator: some View {
        Menu {
            ForEach([25,50,100,150,200], id: \.self) { percent in
                Button("\(percent)%") { setZoom(CGFloat(percent)/100) }
                    .accessibilityIdentifier("zoom-\(percent)")
            }
        } label: {
            Label("倍率 \(Int(canvasScale * 100))%", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.caption.weight(.medium))
                .padding(8)
                .background(.thinMaterial, in: Capsule())
        }
        .disabled(toolbarDisabled)
        .accessibilityIdentifier("zoom-menu")
    }

    private var canvasSize: CGSize { .init(width: 2_400, height: 1_800) }

    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
                Grid().allowsHitTesting(false)
                Canvas { context, _ in
                    for note in notes {
                        if let anchor = note.anchor {
                            let bounds = CGRect(x: note.position.x-note.size.width/2, y: note.position.y-note.size.height/2, width: note.size.width, height: note.size.height)
                            var path = Path(); path.move(to: note.relateCorner.point(in: bounds)); path.addLine(to: anchor)
                            context.stroke(path, with: .color(.secondary), style: .init(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                    for (index, wire) in wires.enumerated() {
                        let hops = wireHops(index)
                        context.stroke(wirePath(wire.points, hops: hops), with: .color(.primary), lineWidth: 2)
                        // Near corners a semicircle cannot fit: show a small hollow crossing marker.
                        for hop in hops where hop.radius == 0 {
                            let rect = CGRect(x: hop.point.x-3, y: hop.point.y-3, width: 6, height: 6)
                            context.stroke(Path(ellipseIn: rect), with: .color(.primary), lineWidth: 1)
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityChildren {
                    ForEach(Array(wires.enumerated()), id: \.element.id) { index, wire in
                        Text("配線 \(index + 1)")
                            .accessibilityIdentifier("wire-\(index)")
                            .accessibilityValue("\(wire.start.x),\(wire.start.y),\(wire.end.x),\(wire.end.y)")
                        Text("配線経路 \(index + 1)")
                            .accessibilityIdentifier("wire-\(index)-points")
                            .accessibilityValue(pointValue(wire.points))
                        Text("配線交差 \(index + 1)")
                            .accessibilityIdentifier("wire-\(index)-hops")
                            .accessibilityValue(pointValue(wireHops(index).map(\.point)))
                    }
                }
                Path { path in
                    for point in WireRouting.junctions(wires.map(\.points)) {
                        path.addEllipse(in: CGRect(x:point.x-5,y:point.y-5,width:10,height:10))
                    }
                }
                .fill(.primary)
                .allowsHitTesting(false)
                .accessibilityRepresentation {
                    Text("配線分岐")
                        .accessibilityIdentifier("canvas-junctions")
                        .accessibilityValue(pointValue(WireRouting.junctions(wires.map(\.points))))
                }
                ForEach(Array(wires.enumerated()), id: \.element.id) { index, wire in
                    ForEach(interiorSegments(wire.points), id: \.self) { segment in
                        segmentTarget(wire: wire, index: index, segment: segment)
                    }
                }
                if editMode {
                    // Every segment (not just the interior ones segmentTarget covers for dragging) is
                    // tappable to delete, per this task: "任意の配線をタップすることで削除可能".
                    ForEach(Array(wires.enumerated()), id: \.element.id) { index, wire in
                        ForEach(0..<max(0, wire.points.count-1), id: \.self) { segment in
                            editModeWireDeleteTarget(wire: wire, index: index, segment: segment)
                        }
                    }
                }
                ForEach(symbols) { symbol in
                    SymbolCard(
                        symbol: symbol,
                        isConnected: isConnected(symbol),
                        selected: selectedSymbol == symbol.id,
                        wireStartPinIndex: pendingWirePinIndex(for: symbol),
                        select: {
                            guard tool == .select, !editMode, liveEdit == nil else { return }
                            selectedSymbol = symbol.id
                            selectedNote = nil; selectedText = nil
                        },
                        selectPin: { index in
                            guard tool == .wire, !editMode, liveEdit == nil else { return }
                            selectWirePin(pins(for: symbol)[index])
                        }
                    )
                        .position(symbol.position)
                        .onTapGesture {
                            guard tool == .select, !editMode, liveEdit == nil else { return }
                            selectedSymbol = symbol.id
                            selectedNote = nil; selectedText = nil
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .named("editorViewport"))
                                .onChanged { value in
                                    guard !editMode, liveEdit == nil else { return }
                                    move(symbolID: symbol.id, by: CGSize(width:value.translation.width/canvasScale,height:value.translation.height/canvasScale))
                                }
                                .onEnded { _ in dragOrigins[symbol.id] = nil }
                        )
                    if editMode {
                        let bounds = symbol.kind.body(at:symbol.position,rotation:symbol.rotation,size:symbol.size)
                        let side = ResizableGeometry.screenConstant(28, scale: canvasScale)
                        Button { pendingDelete = .symbol(symbol.id) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: side*0.75))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .red)
                                .frame(width: side, height: side)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .position(x: bounds.maxX, y: bounds.minY)
                        .accessibilityLabel("シンボルを削除")
                        .accessibilityIdentifier("symbol-\(symbol.title)-edit-delete")
                    }
                }
                if let id = selectedSymbol, let symbol = symbols.first(where: { $0.id == id }), !symbol.kind.isBlock {
                    let bounds = symbol.kind.body(at:symbol.position,rotation:symbol.rotation,size:symbol.size)
                    // Stays >= 32pt on screen at any zoom, like the resize handles.
                    let side = ResizableGeometry.screenConstant(32, scale: canvasScale)
                    let arm = ResizableGeometry.screenConstant(24, scale: canvasScale)
                    Button { rotateSymbol(id) } label: {
                        Image(systemName:"arrow.clockwise")
                            .frame(width:side,height:side)
                            .background(.regularMaterial,in:Circle())
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x:bounds.maxX+arm,y:bounds.minY-arm)
                    .accessibilityLabel("回転")
                    .accessibilityIdentifier("symbol-\(symbol.title)-rotate")
                }
                if let id = selectedSymbol, let symbol = symbols.first(where: { $0.id == id }), symbol.kind.isBlock {
                    let bounds = symbol.kind.body(at:symbol.position,rotation:0,size:symbol.size)
                    let k = max(1, 1 / canvasScale)
                    ForEach(ResizeCorner.allCases) { corner in
                        let hit = BlockSize.handleRect(body: bounds, sx: corner.sx, sy: corner.sy, scale: canvasScale)
                        Color.clear.frame(width:hit.width,height:hit.height)
                            .overlay { Circle().fill(Color.accentColor).frame(width:10*k,height:10*k)
                                .offset(x:-corner.sx*6*k,y:-corner.sy*10*k) }   // drawn 6pt outside the corner
                            .contentShape(Rectangle())
                            .position(x:hit.midX, y:hit.midY)
                            .accessibilityElement().accessibilityLabel("大きさを変更")
                            .accessibilityIdentifier("symbol-\(symbol.title)-resize-\(corner.rawValue)")
                            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("editorViewport"))
                                .onChanged { value in resize(symbolID: id, corner: corner, translation: CGSize(width:value.translation.width/canvasScale,height:value.translation.height/canvasScale)) }
                                .onEnded { _ in resizeDrag = nil })
                    }
                    // "+" on every row this block's height allows that does not have a pin yet (3C).
                    let taken = Set(symbol.blockPins)
                    let open = SymbolKind.blockPinSlots(height: symbol.size.height).filter { !taken.contains($0) }
                    // Fixed in canvas units, like the pins and the 30pt row pitch themselves - not screen-constant.
                    // Growing this at low zoom (as the resize handles do) would make it bigger than the 30pt gap
                    // between rows, guaranteeing overlap with a neighbouring pin; staying fixed keeps it scaling
                    // together with the grid it sits on, so if it clears its neighbours at 100% it clears them at
                    // every zoom. Its own on-screen size (26pt) is therefore short of the usual 32pt minimum on this
                    // one control - a deliberate trade-off, not an oversight (see the block-pin-add task notes).
                    let plusSide: CGFloat = 26
                    ForEach(Array(open.enumerated()), id: \.offset) { _, slot in
                        let y = bounds.minY + 15 + CGFloat(slot.slot) * 30
                        // Offset outward from the pin column so the target is visually distinct from where the
                        // pin itself will land, per Codex review.
                        let x = slot.side == .left ? bounds.minX - plusSide/2 - 2 : bounds.maxX + plusSide/2 + 2
                        Button { addBlockPin(symbolID: id, pin: slot) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: plusSide*0.6))
                                .background(Circle().fill(.background))
                                .frame(width: plusSide, height: plusSide)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: x, y: y)
                        .accessibilityLabel("ピンを追加")
                        .accessibilityIdentifier("symbol-\(symbol.title)-add-pin-\(slot.side == .left ? "left" : "right")-\(slot.slot)")
                    }
                }
                ForEach($notes) { $note in
                    NoteCard(
                        note: $note,
                        selected: selectedNote == note.id,
                        select: {
                            guard tool == .select, !editMode, liveEdit == nil else { return }
                            selectedNote = note.id
                            selectedSymbol = nil; selectedText = nil
                        }
                    )
                        .position(note.position)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .named("editorViewport"))
                                .onChanged { value in
                                    guard !editMode, liveEdit == nil else { return }
                                    move(noteID: note.id, by: CGSize(width:value.translation.width/canvasScale,height:value.translation.height/canvasScale))
                                }
                                .onEnded { _ in noteDragOrigins[note.id] = nil }
                        )
                        .contextMenu {
                            // None of this while in edit mode: it would set selectedNote/linkingNote behind
                            // the back of the guard on NoteCard's own tap, showing the relate-corner picker
                            // right alongside the ✗ badges (Codex minor, 4C round 1).
                            if !editMode {
                                Button(note.complete ? "未完了に戻す" : "完了にする", systemImage: note.complete ? "arrow.uturn.backward" : "checkmark") { note.complete.toggle() }
                                Button("関連付け", systemImage: "arrowshape.turn.up.right") { selectedNote = note.id; selectedSymbol = nil; selectedText = nil; linkingNote = note.id }
                            }
                        }
                    if editMode {
                        let bounds = CGRect(x:note.position.x-note.size.width/2,y:note.position.y-note.size.height/2,width:note.size.width,height:note.size.height)
                        let side = ResizableGeometry.screenConstant(28, scale: canvasScale)
                        Button { pendingDelete = .note(note.id) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: side*0.75))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .red)
                                .frame(width: side, height: side)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .position(x: bounds.maxX, y: bounds.minY)
                        .accessibilityLabel("付箋を削除")
                        .accessibilityIdentifier("experiment-note-\(note.title)-edit-delete")
                    }
                }
                if let id = selectedNote, let note = notes.first(where: { $0.id == id }) {
                    let bounds = CGRect(x:note.position.x-note.size.width/2,y:note.position.y-note.size.height/2,width:note.size.width,height:note.size.height)
                    if linkingNote == id {
                        // Relate mode, step 1: pick which corner the line starts from (like tapping a wire's
                        // starting pin). Replaces the resize handles/relate button for this note until picked.
                        let pickSide = ResizableGeometry.screenConstant(32, scale: canvasScale)
                        ForEach(NoteCorner.allCases) { corner in
                            let point = corner.point(in: bounds)
                            Button { pendingRelateFrom = (id, corner); linkingNote = nil } label: {
                                Image(systemName: "smallcircle.filled.circle")
                                    .frame(width: pickSide, height: pickSide)
                                    .background(.regularMaterial, in: Circle())
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .position(point)
                            .accessibilityLabel("この角から関連付け")
                            .accessibilityIdentifier("experiment-note-\(note.title)-relate-corner-\(corner.rawValue)")
                        }
                    } else {
                        let k = max(1, 1 / canvasScale)
                        ForEach(ResizeCorner.allCases) { corner in
                            let hit = NoteSize.handleRect(body: bounds, sx: corner.sx, sy: corner.sy, scale: canvasScale)
                            Color.clear.frame(width:hit.width,height:hit.height)
                                .overlay { Circle().fill(Color.accentColor).frame(width:10*k,height:10*k)
                                    .offset(x:-corner.sx*6*k,y:-corner.sy*10*k) }
                                .contentShape(Rectangle())
                                .position(x:hit.midX, y:hit.midY)
                                .accessibilityElement().accessibilityLabel("大きさを変更")
                                .accessibilityIdentifier("experiment-note-\(note.title)-resize-\(corner.rawValue)")
                                .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("editorViewport"))
                                    .onChanged { value in resizeNote(noteID: id, corner: corner, translation: CGSize(width:value.translation.width/canvasScale,height:value.translation.height/canvasScale)) }
                                    .onEnded { _ in noteResizeDrag = nil })
                        }
                        // Same idea as the circuit-symbol rotate button: an action, next to the selected item, that
                        // needs no trip through the inspector sheet (which would then block tapping the canvas below it).
                        let relateSide = ResizableGeometry.screenConstant(32, scale: canvasScale)
                        let relateArm = ResizableGeometry.screenConstant(24, scale: canvasScale)
                        Button { linkingNote = id } label: {
                            Image(systemName:"arrowshape.turn.up.right")
                                .frame(width:relateSide,height:relateSide)
                                .background(.regularMaterial,in:Circle())
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x:bounds.midX,y:bounds.minY-relateArm)
                        .accessibilityLabel("付箋を関連付け")
                        .accessibilityIdentifier("experiment-note-\(note.title)-relate")
                        // A shortcut straight to the inspector for this note, next to relate - so editing
                        // its content does not need a trip through "確認" first (feedback, 2026-09-29).
                        Button { inspectorSessionPushed = false; showInspector = true } label: {
                            Image(systemName:"square.and.pencil")
                                .frame(width:relateSide,height:relateSide)
                                .background(.regularMaterial,in:Circle())
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x:bounds.midX+relateSide+6,y:bounds.minY-relateArm)
                        .accessibilityLabel("付箋を編集")
                        .accessibilityIdentifier("experiment-note-\(note.title)-edit")
                    }
                }
                ForEach($texts) { $text in
                    TextCard(
                        text: $text,
                        selected: selectedText == text.id,
                        editMode: editMode,
                        scale: canvasScale,
                        select: {
                            guard tool == .select, !editMode, liveEdit == nil else { return }
                            selectedText = text.id
                            selectedSymbol = nil; selectedNote = nil
                        },
                        delete: { pendingDelete = .text(text.id) }
                    )
                        .position(text.position)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .named("editorViewport"))
                                .onChanged { value in
                                    guard !editMode, liveEdit == nil else { return }
                                    move(textID: text.id, by: CGSize(width:value.translation.width/canvasScale,height:value.translation.height/canvasScale))
                                }
                                .onEnded { _ in textDragOrigins[text.id] = nil }
                        )
                }

            }
    }
    private func liveEditCard(text: Binding<String>, multiline: Bool) -> some View {
        VStack(spacing: 8) {
            if multiline {
                TextEditor(text: text)
                    .frame(width: 260, height: 140)
                    .padding(4)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityIdentifier("live-edit-field")
            } else {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .accessibilityIdentifier("live-edit-field")
                    .onSubmit { commitLiveEdit() }
            }
            Button("完了") { commitLiveEdit() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("live-edit-done")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 2))
    }

    private var canvasTapGesture: some Gesture {
        SpatialTapGesture(coordinateSpace: .named("editorViewport")).onEnded { tap in
                guard liveEdit == nil else { return }
                let point = canvasPoint(from: tap.location)
                if let pending = pendingRelateFrom { setAnchor(pending.id, point, corner: pending.corner); pendingRelateFrom = nil }
                // A background tap while waiting for the corner pick cancels relate mode explicitly, rather
                // than falling through to deselect and leaving linkingNote (and its hint) dangling (Codex
                // minor, 4A round 1).
                else if linkingNote != nil { linkingNote = nil }
                else if editMode { selectedNote = nil; selectedSymbol = nil; selectedText = nil }
                else if tool == .wire, let pin = nearestPin(to: point) {
                    selectWirePin(pin)
                }
                else if tool == .note { pushUndo(); notes.append(.init(type: .memo, title: "新しいメモ", body: "内容を入力", position: point)); selectedNote = notes.last?.id; selectedSymbol = nil; selectedText = nil; tool = .select }
                else if tool == .symbol { pushUndo(); symbols.append(.init(title: selectedLibrary.rawValue, kind: selectedLibrary, position: point)); selectedSymbol = nil; selectedNote = nil; selectedText = nil; tool = .select; reroute() }
                else if tool == .text { pushUndo(); texts.append(.init(position: point)); selectedText = texts.last?.id; selectedSymbol = nil; selectedNote = nil; tool = .select }
                else { selectedNote = nil; selectedSymbol = nil; selectedText = nil }
            }
    }

    private var inspector: some View {
        Form {
            if let id = selectedSymbol, let symbol = symbolBinding(for: id) {
                Section("シンボル") {
                    // Tapping this, rather than editing inline, closes the sheet and edits it live on the
                    // canvas instead (5D) - so the rename can be checked against the diagram's actual look
                    // while typing, not only after returning here.
                    Button { beginLiveEdit(.symbolTitle(id)) } label: {
                        LabeledContent("名称") { Text(symbol.wrappedValue.title) }
                    }
                    .accessibilityIdentifier("inspector-symbol-title")
                    LabeledContent("接続", value: isConnected(symbol.wrappedValue) ? "接続あり" : "未接続")
                        .accessibilityIdentifier("symbol-connection-status")
                        .accessibilityValue(isConnected(symbol.wrappedValue) ? "接続あり" : "未接続")
                    if symbol.wrappedValue.kind.isBlock {
                        NavigationLink { IconPickerView(icon: symbol.icon, categories: BlockIcon.categories) } label: {
                            LabeledContent("アイコン") { Image(systemName: symbol.wrappedValue.icon) }
                        }
                        .accessibilityIdentifier("inspector-icon-picker")
                        LabeledContent("大きさ", value: "\(Int(symbol.wrappedValue.size.width)) × \(Int(symbol.wrappedValue.size.height))")
                        Button("元の大きさに戻す", systemImage:"arrow.counterclockwise") {
                            if let i = symbols.firstIndex(where: { $0.id == id }) {
                                pushUndo(); inspectorSessionPushed = false
                                // Same top-left corner, standard size (but never shorter than an added pin needs).
                                let body = symbols[i].kind.body(at:symbols[i].position,rotation:0,size:symbols[i].size)
                                let standard = CGSize(width: BlockSize.standard.width, height: max(BlockSize.standard.height, BlockSize.minimumHeight(for: symbols[i].blockPins)))
                                applyBlockGeometry(i, center: CGPoint(x:body.minX+standard.width/2,y:body.minY+standard.height/2), size: standard)
                            }
                        }
                        .accessibilityIdentifier("inspector-reset-size")
                    }
                    Button("シンボルを削除", role: .destructive) {
                        removeSymbol(id)
                    }
                }
            } else if let id = selectedNote, let note = noteBinding(for: id) {
                Section("付箋") {
                    Picker("種別", selection: note.type) { ForEach(NoteType.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("note-type-picker")
                    NavigationLink { IconPickerView(icon: note.icon, categories: NoteIcon.categories) } label: {
                        LabeledContent("アイコン") { Image(systemName: note.wrappedValue.icon) }
                    }
                    .accessibilityIdentifier("inspector-note-icon-picker")
                    // Both, like the symbol name above, are edited live on the canvas (5D) rather than
                    // inline here - title and body alike can affect the note's on-canvas size/wrap, which is
                    // exactly what this is meant to let the user watch while typing.
                    Button { beginLiveEdit(.noteTitle(id)) } label: {
                        LabeledContent("タイトル") { Text(note.wrappedValue.title) }
                    }
                    .accessibilityIdentifier("inspector-note-title")
                    Button { beginLiveEdit(.noteBody(id)) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本文")
                            Text(note.wrappedValue.body).foregroundStyle(.secondary).lineLimit(3)
                        }
                    }
                    .accessibilityIdentifier("note-body-editor")
                    Toggle("完了", isOn: note.complete)
                    Button("付箋を削除", role: .destructive) {
                        removeNote(id)
                    }
                }
            } else if let id = selectedText, let text = textBinding(for: id) {
                Section("テキスト") {
                    // No title/type/icon, unlike a note (5C's own scope) - just the content itself, edited
                    // live on the canvas (5D) like a note's title/body.
                    Button { beginLiveEdit(.textBody(id)) } label: {
                        Text(text.wrappedValue.body).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("text-body-editor")
                    Button("テキストを削除", role: .destructive) {
                        removeText(id)
                    }
                }
            } else {
                Section("図面") { LabeledContent("シンボル", value: "\(symbols.count)"); LabeledContent("未完了メモ", value: "\(notes.filter { !$0.complete }.count)") }
                Section("配線チェック") {
                    LabeledContent("接続済み配線", value: "\(wires.count)")
                        .accessibilityIdentifier("wire-count")
                        .accessibilityValue("\(wires.count)")
                    ForEach(symbols) { symbol in Label(isConnected(symbol) ? "\(symbol.title) — 接続あり" : "\(symbol.title) — 未接続", systemImage: isConnected(symbol) ? "checkmark.circle.fill" : "exclamationmark.circle") .foregroundStyle(isConnected(symbol) ? .green : .orange) }
                }
                Section("操作") { Text("＋メモを押して任意位置に付箋を置けます。付箋を選ぶと、そばのボタンで、関連付けや大きさの変更ができます。") }
            }
        }.formStyle(.grouped)
    }

    private func setAnchor(_ id: UUID, _ point: CGPoint, corner: NoteCorner) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        notes[i].anchor = point; notes[i].relateCorner = corner
    }
    // MARK: Live editing on the canvas (5D)
    /// Leaves inspectorSessionPushed untouched: the live-edit round trip (dismiss the sheet, type, come back)
    /// must not itself start or end an Undo batch - that is still governed purely by whichever discrete
    /// action last touched inspectorSessionPushed (a picker change, "確認" opening the sheet, etc.), exactly
    /// as before this feature existed.
    private func beginLiveEdit(_ target: LiveEditTarget) {
        liveEdit = target
        showInspector = false
    }
    private func commitLiveEdit() {
        liveEdit = nil
        showInspector = true
    }
    /// The exact same bindings the inspector itself used to bind its now-removed TextField/TextEditor to -
    /// reusing them (rather than a separate scratch buffer copied back on commit) is what makes the canvas's
    /// own card update character-by-character as the user types, not just on commit.
    private func liveEditBinding(for target: LiveEditTarget) -> Binding<String>? {
        switch target {
        case .symbolTitle(let id): symbolBinding(for: id)?.title
        case .noteTitle(let id): noteBinding(for: id)?.title
        case .noteBody(let id): noteBinding(for: id)?.body
        case .textBody(let id): textBinding(for: id)?.body
        }
    }
    private func liveEditPosition(for target: LiveEditTarget) -> CGPoint? {
        switch target {
        case .symbolTitle(let id): symbols.first(where: { $0.id == id })?.position
        case .noteTitle(let id), .noteBody(let id): notes.first(where: { $0.id == id })?.position
        case .textBody(let id): texts.first(where: { $0.id == id })?.position
        }
    }
    private func liveEditIsMultiline(_ target: LiveEditTarget) -> Bool {
        switch target { case .noteBody, .textBody: true; case .symbolTitle, .noteTitle: false }
    }
    /// The card's approximate footprint (see liveEditCard) - only needed to keep it fully inside the
    /// viewport; does not need to track the card's real layout exactly, just closely enough that nothing
    /// gets clipped or pushed out of reach.
    private func liveEditCardSize(_ target: LiveEditTarget) -> CGSize {
        liveEditIsMultiline(target) ? CGSize(width: 284, height: 220) : CGSize(width: 244, height: 110)
    }
    private func liveEditViewportPosition(for target: LiveEditTarget, canvasPosition: CGPoint, viewportSize: CGSize) -> CGPoint {
        let screenPoint = CGPoint(x: canvasPosition.x * canvasScale + canvasOffset.width, y: canvasPosition.y * canvasScale + canvasOffset.height)
        let size = liveEditCardSize(target)
        let margin: CGFloat = 8
        let halfW = size.width / 2, halfH = size.height / 2
        let x = min(max(screenPoint.x, halfW + margin), max(halfW + margin, viewportSize.width - halfW - margin))
        let y = min(max(screenPoint.y, halfH + margin), max(halfH + margin, viewportSize.height - halfH - margin))
        return CGPoint(x: x, y: y)
    }
    private func selectWirePin(_ pin: CGPoint) {
        if let start = pendingWireStart {
            guard start.distance(to: pin) >= 1 else { return }
            guard !symbols.contains(where: { symbol in
                let endpoints = pins(for: symbol)
                return endpoints.contains(start) && endpoints.contains(pin)
            }) else { return }
            let alreadyExists = wires.contains { wire in
                (wire.start.distance(to: start) < 1 && wire.end.distance(to: pin) < 1) ||
                (wire.start.distance(to: pin) < 1 && wire.end.distance(to: start) < 1)
            }
            if !alreadyExists { pushUndo(); wires.append(.init(start: start, end: pin)); reroute() }
            pendingWireStart = nil
            tool = .select
        } else {
            pendingWireStart = pin
        }
    }
    private func pendingWirePinIndex(for symbol: SymbolItem) -> Int? {
        guard let start = pendingWireStart else { return nil }
        return pins(for: symbol).firstIndex { $0.distance(to: start) < 1 }
    }
    private func symbolBinding(for id: UUID) -> Binding<SymbolItem>? {
        guard let initial = symbols.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { symbols.first(where: { $0.id == id }) ?? initial },
            set: { updated in
                guard let index = symbols.firstIndex(where: { $0.id == id }) else { return }
                // The icon picker is its own confirm action (Codex major, 4D round 1: mixing it into the
                // same batch as a surrounding title edit made one Undo revert both at once) - not part of
                // the same batch as continuous title typing. Ends that batch too, so typing again afterward
                // starts a fresh one.
                if symbols[index].icon != updated.icon {
                    pushUndo(); inspectorSessionPushed = false
                } else if !inspectorSessionPushed {
                    pushUndo(); inspectorSessionPushed = true
                }
                symbols[index] = updated
            }
        )
    }
    private func noteBinding(for id: UUID) -> Binding<NoteItem>? {
        guard let initial = notes.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { notes.first(where: { $0.id == id }) ?? initial },
            set: { updated in
                guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
                let previous = notes[index]
                // 種別・アイコン・完了 are each their own confirm action, not part of a surrounding title/body
                // typing batch (Codex major, 4D round 1 - same reasoning as the block icon picker above).
                if previous.type != updated.type || previous.icon != updated.icon || previous.complete != updated.complete {
                    pushUndo(); inspectorSessionPushed = false
                } else if !inspectorSessionPushed {
                    pushUndo(); inspectorSessionPushed = true
                }
                notes[index] = updated
            }
        )
    }
    private func textBinding(for id: UUID) -> Binding<TextItem>? {
        guard let initial = texts.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { texts.first(where: { $0.id == id }) ?? initial },
            set: { updated in
                guard let index = texts.firstIndex(where: { $0.id == id }) else { return }
                if !inspectorSessionPushed { pushUndo(); inspectorSessionPushed = true }
                texts[index] = updated
            }
        )
    }
    private func rotateSymbol(_ id: UUID) {
        guard let i = symbols.firstIndex(where: { $0.id == id }), !symbols[i].kind.isBlock else { return }
        pushUndo()
        let old = pins(for:symbols[i])
        symbols[i].rotation = (symbols[i].rotation + 90) % 360
        let new = pins(for:symbols[i])
        for j in wires.indices {
            if let point = SymbolKind.remapped(wires[j].start, from: old, to: new) { wires[j].start = point; wires[j].manual = false }
            if let point = SymbolKind.remapped(wires[j].end, from: old, to: new) { wires[j].end = point; wires[j].manual = false }
        }
        if let pin = pendingWireStart, let point = SymbolKind.remapped(pin, from: old, to: new) { pendingWireStart = point }
        reroute()
    }
    private func resizeNote(noteID: UUID, corner: ResizeCorner, translation: CGSize) {
        guard activePanSource == nil, let i = notes.firstIndex(where: { $0.id == noteID }) else { return }
        if noteResizeDrag?.id != noteID { pushUndo() }
        let origin = noteResizeDrag?.id == noteID ? noteResizeDrag! : ResizeDrag(id: noteID, center: notes[i].position, size: notes[i].size)
        noteResizeDrag = origin
        let result = NoteSize.resized(center: origin.center, size: origin.size, sx: corner.sx, sy: corner.sy, translation: translation)
        notes[i].position = result.center; notes[i].size = result.size
    }
    /// Adding a pin never needs a reroute: it starts with no wire attached.
    private func addBlockPin(symbolID: UUID, pin: SymbolKind.BlockPin) {
        guard let i = symbols.firstIndex(where: { $0.id == symbolID }), symbols[i].kind.isBlock,
              !symbols[i].blockPins.contains(pin) else { return }
        pushUndo()
        symbols[i].blockPins.append(pin)
    }
    private func resize(symbolID: UUID, corner: ResizeCorner, translation: CGSize) {
        guard activePanSource == nil, let i = symbols.firstIndex(where: { $0.id == symbolID }), symbols[i].kind.isBlock else { return }
        if resizeDrag?.id != symbolID { pushUndo() }
        let origin = resizeDrag?.id == symbolID ? resizeDrag! : ResizeDrag(id: symbolID, center: symbols[i].position, size: symbols[i].size)
        resizeDrag = origin
        let minimum = CGSize(width: BlockSize.minimum.width, height: BlockSize.minimumHeight(for: symbols[i].blockPins))
        let result = ResizableGeometry.resized(center: origin.center, size: origin.size, sx: corner.sx, sy: corner.sy,
                                               translation: translation, step: BlockSize.step, minimum: minimum, maximum: BlockSize.maximum)
        applyBlockGeometry(i, center: result.center, size: result.size)
    }
    /// Moves the block's pins and carries the attached wire ends along. Like moving a symbol, manually placed
    /// segments are kept (reattached to the moved ends); nothing happens when the geometry did not change.
    private func applyBlockGeometry(_ i: Int, center: CGPoint, size: CGSize) {
        guard center != symbols[i].position || size != symbols[i].size else { return }
        let old = pins(for: symbols[i])
        symbols[i].position = center; symbols[i].size = size
        let new = pins(for: symbols[i])
        for j in wires.indices {
            if let point = SymbolKind.remapped(wires[j].start, from: old, to: new) { wires[j].start = point }
            if let point = SymbolKind.remapped(wires[j].end, from: old, to: new) { wires[j].end = point }
        }
        if let pin = pendingWireStart, let point = SymbolKind.remapped(pin, from: old, to: new) { pendingWireStart = point }
        reroute()
    }
    private func removeSymbol(_ id: UUID) {
        guard let symbol = symbols.first(where: { $0.id == id }) else { return }
        pushUndo(); inspectorSessionPushed = false
        let symbolPins = pins(for: symbol)
        wires.removeAll { wire in
            symbolPins.contains { pin in wire.start.distance(to: pin) < 1 || wire.end.distance(to: pin) < 1 }
        }
        selectedSymbol = nil
        symbols.removeAll { $0.id == id }; reroute()
    }
    private func removeNote(_ id: UUID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        pushUndo(); inspectorSessionPushed = false
        selectedNote = nil
        linkingNote = nil
        if pendingRelateFrom?.id == id { pendingRelateFrom = nil }
        notes.removeAll { $0.id == id }
    }
    private func removeText(_ id: UUID) {
        guard texts.contains(where: { $0.id == id }) else { return }
        pushUndo(); inspectorSessionPushed = false
        selectedText = nil
        texts.removeAll { $0.id == id }
    }
    /// Settings' "キャンバスをリセット" (only reachable after its own confirmation dialog): clears the
    /// diagram back to blank, and any state that referred to what was on it.
    private func resetCanvas() {
        pushUndo()
        symbols = []; notes = []; texts = []; wires = []
        selectedSymbol = nil; selectedNote = nil; selectedText = nil; linkingNote = nil; pendingRelateFrom = nil; pendingWireStart = nil
        tool = .select
        reroute()
        centerViewportOnCanvas()
    }
    /// Shows the canvas's own center, not its top-left corner - easier to start drawing in any direction
    /// (feedback, 2026-09-29). Only called on reset, not on every launch: the seed diagram sits in the
    /// canvas's upper-left quadrant, and dozens of existing UI tests assume it is on screen at launch
    /// (scale=1, offset=0) - centering there would scroll it out of view and need a much larger rewrite. A
    /// freshly reset (blank) canvas has nothing at risk of scrolling away, so centering only then gets the
    /// requested "easy to start drawing" feel without that cost.
    private func centerViewportOnCanvas() {
        guard viewportSize != .zero else { return }
        let canvasCenter = CGPoint(x: canvasSize.width/2, y: canvasSize.height/2)
        canvasOffset = CGSize(width: viewportSize.width/2 - canvasCenter.x*canvasScale, height: viewportSize.height/2 - canvasCenter.y*canvasScale)
        canvasPanOrigin = canvasOffset
    }
    // MARK: Undo / Redo (4D)
    /// Call right before a meaningful, undoable change (see this task's list: add/move/resize/rotate/
    /// pin-add/delete/rename/type/icon). A drag pushes once, at its first onChanged, not on every delta.
    private func pushUndo() {
        undoStack.append(CanvasSnapshot(symbols: symbols, notes: notes, texts: texts, wires: wires))
        if undoStack.count > maxUndoSteps { undoStack.removeFirst() }
        redoStack.removeAll()
    }
    private func performUndo() {
        guard let previous = undoStack.popLast() else { undoRedoUnavailableReason = "取り消す操作がありません"; return }
        redoStack.append(CanvasSnapshot(symbols: symbols, notes: notes, texts: texts, wires: wires))
        restore(previous)
    }
    private func performRedo() {
        guard let next = redoStack.popLast() else { undoRedoUnavailableReason = "やり直す操作がありません"; return }
        undoStack.append(CanvasSnapshot(symbols: symbols, notes: notes, texts: texts, wires: wires))
        restore(next)
    }
    /// Snapshots already hold each wire's exact prior `.points`, so this does not reroute() - replanning
    /// could legitimately land on a different route than the one actually being restored.
    private func restore(_ snapshot: CanvasSnapshot) {
        symbols = snapshot.symbols; notes = snapshot.notes; texts = snapshot.texts; wires = snapshot.wires
        selectedSymbol = nil; selectedNote = nil; selectedText = nil
        linkingNote = nil; pendingRelateFrom = nil; pendingWireStart = nil
        dragOrigins = [:]; noteDragOrigins = [:]; textDragOrigins = [:]; resizeDrag = nil; noteResizeDrag = nil; segmentDrag = nil
    }
    /// One-finger drag on empty canvas. Per feedback (2026-09-29): grabbing a wire lead too close to the
    /// background used to pan the canvas instead far too easily. One finger now only ever does two things -
    /// drag a wire segment (unchanged, still tool == .select only), or pan while the dedicated "キャンバス移
    /// 動" tool is active - never an incidental pan from any other tool. Two fingers can always pan, via the
    /// separate TwoFingerPanOverlay below, regardless of tool.
    private func canvasPanGesture(in viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("editorViewport"))
            .onChanged { value in
                // Nothing on the canvas responds to a touch while a field is being live-edited (5D) - the
                // scrim above it already blocks most of these, but a touch that starts outside canvasSize
                // (in the "outside the canvas" margin) reaches this gesture directly, without the scrim.
                guard liveEdit == nil else { return }
                // Very short transparent targets can deliver the touch to this
                // background. Resolve once at touch-down and retain that choice.
                if segmentDrag == nil && !isPanningCanvas {
                    beginSegmentDrag(at: value.startLocation, translation: value.translation)
                    isPanningCanvas = segmentDrag == nil && tool == .pan && activePanSource == nil
                    if isPanningCanvas { activePanSource = .singleFinger }
                }
                if segmentDrag != nil {
                    updateSegmentDrag(translation: value.translation)
                    return
                }
                guard tool == .pan, activePanSource == .singleFinger else { return }
                canvasOffset = boundedCanvasOffset(
                    CGSize(width: canvasPanOrigin.width + value.translation.width, height: canvasPanOrigin.height + value.translation.height),
                    in: viewportSize
                )
            }
            .onEnded { _ in
                if activePanSource == .singleFinger { canvasPanOrigin = canvasOffset; activePanSource = nil }
                segmentDrag = nil
                isPanningCanvas = false
            }
    }
    private var canvasZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in guard liveEdit == nil else { return }; canvasScale = min(max(canvasScaleOrigin * value, 0.5), 2.5) }
            .onEnded { _ in canvasScaleOrigin = canvasScale }
    }
    private func canvasPoint(from point: CGPoint) -> CGPoint { .init(x: (point.x - canvasOffset.width) / canvasScale, y: (point.y - canvasOffset.height) / canvasScale) }
    private func boundedCanvasOffset(_ proposed: CGSize, in viewportSize: CGSize) -> CGSize {
        let minimumVisible: CGFloat = 200
        let scaledWidth = canvasSize.width * canvasScale
        let scaledHeight = canvasSize.height * canvasScale
        return CGSize(
            width: min(max(proposed.width, minimumVisible - scaledWidth), viewportSize.width - minimumVisible),
            height: min(max(proposed.height, minimumVisible - scaledHeight), viewportSize.height - minimumVisible)
        )
    }
    /// Applies one of the zoom menu's fixed percentages, keeping whatever canvas point is currently at the
    /// center of the visible viewport centered there (rather than resetting pan, or anchoring on the
    /// canvas's own top-left as the old single reset button did). Deliberately not run through
    /// boundedCanvasOffset: that keeps a 200pt margin of canvas on screen at all times, which would move the
    /// center whenever the current pan is already using part of that margin (Codex major, 4E round 1) - here
    /// the user picked an exact percentage, so preserving the center takes priority over that safety margin.
    private func setZoom(_ scale: CGFloat) {
        guard viewportSize != .zero else { canvasScale = scale; canvasScaleOrigin = scale; return }
        canvasOffset = CanvasZoom.offset(oldOffset: canvasOffset, oldScale: canvasScale, newScale: scale, viewportSize: viewportSize)
        canvasScale = scale; canvasScaleOrigin = scale
        canvasPanOrigin = canvasOffset
    }
    private func move(symbolID: UUID, by translation: CGSize) {
        guard activePanSource == nil, let index = symbols.firstIndex(where: { $0.id == symbolID }) else { return }
        if dragOrigins[symbolID] == nil { pushUndo() }
        let origin = dragOrigins[symbolID] ?? symbols[index].position
        dragOrigins[symbolID] = origin
        let oldPosition = symbols[index].position
        let newPosition = CGPoint(x: origin.x + translation.width, y: origin.y + translation.height)
        let oldPins = pins(for: symbols[index])
        symbols[index].position = newPosition
        let newPins = pins(for: symbols[index])
        for wireIndex in wires.indices {
            if let point = SymbolKind.remapped(wires[wireIndex].start, from: oldPins, to: newPins) { wires[wireIndex].start = point }
            if let point = SymbolKind.remapped(wires[wireIndex].end, from: oldPins, to: newPins) { wires[wireIndex].end = point }
        }
        _ = oldPosition
        reroute()
    }
    private func move(noteID: UUID, by translation: CGSize) {
        guard activePanSource == nil, let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        if noteDragOrigins[noteID] == nil { pushUndo() }
        let origin = noteDragOrigins[noteID] ?? notes[index].position
        noteDragOrigins[noteID] = origin
        notes[index].position = CGPoint(x: origin.x + translation.width, y: origin.y + translation.height)
    }
    private func move(textID: UUID, by translation: CGSize) {
        guard activePanSource == nil, let index = texts.firstIndex(where: { $0.id == textID }) else { return }
        if textDragOrigins[textID] == nil { pushUndo() }
        let origin = textDragOrigins[textID] ?? texts[index].position
        textDragOrigins[textID] = origin
        texts[index].position = CGPoint(x: origin.x + translation.width, y: origin.y + translation.height)
    }
    private func pins(for symbol: SymbolItem) -> [CGPoint] { symbol.kind.pins(at: symbol.position, rotation:symbol.rotation, size:symbol.size, blockPins:symbol.blockPins) }
    private func nearestPin(to point: CGPoint) -> CGPoint? { let pin = symbols.flatMap(pins).min { $0.distance(to: point) < $1.distance(to: point) }; guard let pin, pin.distance(to: point) < 70 else { return nil }; return pin }
    private func isConnected(_ symbol: SymbolItem) -> Bool { pins(for: symbol).contains { pin in wires.contains { $0.start.distance(to: pin) < 1 || $0.end.distance(to: pin) < 1 } } }

    private func hint(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.footnote.weight(.medium)).padding(10)
            .background(.thinMaterial, in: Capsule()).accessibilityIdentifier("operation-hint")
    }
    private var bodies: [CGRect] { symbols.map { $0.kind.body(at:$0.position, rotation:$0.rotation, size:$0.size) } }
    /// Circuit symbols are small, so they get a compact clear margin; blocks keep the default.
    private var routingMargins: [CGFloat?] { symbols.map { $0.kind.isBlock ? nil : WireRouting.symbolLead } }
    private func direction(at pin: CGPoint) -> WireRouting.Direction? {
        for symbol in symbols where !symbol.kind.isBlock {
            if let index = pins(for:symbol).firstIndex(of:pin) {
                return symbol.kind.direction(for:index,rotation:symbol.rotation,blockPins:symbol.blockPins)
            }
        }
        return nil
    }
    /// Shortest run a dragged segment may leave next to a pin: circuit symbols keep their 15pt lead, block pins at
    /// least 8pt. A trunk pushed right onto the pin would leave a wire running along the block's edge that
    /// can no longer be pulled back out.
    private func terminalLead(at pin: CGPoint) -> CGFloat {
        if direction(at: pin) != nil { return WireRouting.symbolLead }
        return symbols.contains { pins(for: $0).contains { $0.distance(to: pin) < 1 } } ? 8 : 0
    }
    private func reroute() {
        let planned = WireRouting.reroute(wires.map {
            WireRouting.Wire(start: $0.start, end: $0.end, startDirection: direction(at:$0.start), endDirection: direction(at:$0.end),
                             manual: $0.manual, manualPoints: $0.manualPoints, points: $0.points)
        }, bodies: bodies, margins: routingMargins)
        for i in wires.indices { wires[i].points = planned[i] }
    }
    private func pointValue(_ points: [CGPoint]) -> String { points.map { "\($0.x),\($0.y)" }.joined(separator: ";") }
    private func interiorSegments(_ points: [CGPoint]) -> [Int] { points.count > 3 ? Array(1..<(points.count-2)) : [] }
    private func wireHops(_ index: Int) -> [WireRouting.Crossing] {
        WireRouting.crossings(wires[index].points, others: wires.enumerated().filter { $0.offset != index }.map { $0.element.points })
    }
    private func segmentTarget(wire: WireItem, index: Int, segment: Int) -> some View {
        let a = wire.points[segment], b = wire.points[segment+1]
        let horizontal = a.y == b.y
        // Reduce target overlap at corners. Touch delivery can still favor a
        // neighbor, so the gesture resolves the nearest visible segment below.
        let length = horizontal ? abs(a.x-b.x) : abs(a.y-b.y)
        let targetLength = max(1, length - min(16, length / 2))
        return Color.clear
            .frame(width: horizontal ? targetLength : 16, height: horizontal ? 16 : targetLength)
            .contentShape(Rectangle())
            .position(x: (a.x+b.x)/2, y: (a.y+b.y)/2)
            .accessibilityElement().accessibilityLabel("配線の線分")
            .accessibilityIdentifier("wire-\(index)-segment-\(segment)")
            .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("editorViewport"))
                .onChanged { value in
                    guard tool == .select else { return }
                    beginSegmentDrag(at: value.startLocation, translation: value.translation)
                    updateSegmentDrag(translation: value.translation)
                }
                .onEnded { _ in segmentDrag = nil })
            .allowsHitTesting(tool == .select && !editMode)
    }
    /// Edit mode (4C): tapping any segment deletes just that straight piece, no confirmation. Covers every
    /// segment (not only the interior ones segmentTarget's drag handles are limited to).
    private func editModeWireDeleteTarget(wire: WireItem, index: Int, segment: Int) -> some View {
        let a = wire.points[segment], b = wire.points[segment+1]
        let horizontal = a.y == b.y
        let length = horizontal ? abs(a.x-b.x) : abs(a.y-b.y)
        return Color.clear
            .frame(width: horizontal ? max(1,length) : 20, height: horizontal ? 20 : max(1,length))
            .contentShape(Rectangle())
            .position(x: (a.x+b.x)/2, y: (a.y+b.y)/2)
            .onTapGesture { deleteWireSegment(wireID: wire.id, segment: segment) }
            .accessibilityElement()
            .accessibilityLabel("配線を削除")
            .accessibilityIdentifier("edit-delete-wire-\(index)-segment-\(segment)")
    }
    /// Removes just the tapped straight piece; the remainder on each side becomes its own wire (or vanishes
    /// if that side had nothing left). Deliberately not rerouted: what is left over is not always anchored
    /// to a pin any more, so the routing engine cannot be trusted to make sense of it - a leftover dangling
    /// wire is expected here, per this task ("どこにも繋がっていない配線が残る可能性がある...後で対応").
    private func deleteWireSegment(wireID: UUID, segment: Int) {
        guard let i = wires.firstIndex(where: { $0.id == wireID }), segment >= 0, segment+1 < wires[i].points.count else { return }
        pushUndo()
        let (front, back) = WireRouting.split(wires[i].points, at: segment)
        wires.remove(at: i)
        if let front { wires.append(WireItem(start: front.first!, end: front.last!, points: front, manual: true, manualPoints: front)) }
        if let back { wires.append(WireItem(start: back.first!, end: back.last!, points: back, manual: true, manualPoints: back)) }
    }
    private func beginSegmentDrag(at viewportPoint: CGPoint, translation: CGSize) {
        guard tool == .select, !editMode, segmentDrag == nil, activePanSource == nil,
              let hit = WireRouting.nearestInteriorSegment(
                to: canvasPoint(from: viewportPoint), paths: wires.map(\.points), maximumDistance: 8, translation: translation
              ) else { return }
        pushUndo()
        segmentDrag = SegmentDrag(wireID: wires[hit.wire].id,
                                  segment: hit.segment, origin: wires[hit.wire].points)
    }

    private func updateSegmentDrag(translation: CGSize) {
        guard let drag = segmentDrag,
              let i = wires.firstIndex(where: { $0.id == drag.wireID }) else { return }
        let horizontal = drag.origin[drag.segment].y == drag.origin[drag.segment+1].y
        let delta = (horizontal ? translation.height : translation.width) / canvasScale
        wires[i].points = WireRouting.moved(drag.origin, segment: drag.segment, delta: delta, bodies: bodies, minimumTerminalLead: max(terminalLead(at:wires[i].start), terminalLead(at:wires[i].end)))
        wires[i].manual = true
        wires[i].manualPoints = wires[i].points
    }

    private func wirePath(_ points: [CGPoint], hops: [WireRouting.Crossing]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for (index, pair) in WireRouting.segments(points).enumerated() {
            let (a,b) = pair
            let direction: CGFloat = b.y > a.y ? 1 : -1
            let crossings = hops.filter { $0.segment == index && $0.radius > 0 }.sorted { direction * $0.point.y < direction * $1.point.y }
            for hop in crossings {
                let p = hop.point, r = hop.radius
                path.addLine(to: CGPoint(x:p.x,y:p.y-direction*r))
                path.addArc(center: p, radius: r, startAngle: .degrees(direction > 0 ? -90 : 90), endAngle: .degrees(direction > 0 ? 90 : -90), clockwise: direction < 0)
            }
            path.addLine(to:b)
        }
        return path
    }
}

private struct SymbolCard: View {
    let symbol: SymbolItem
    let isConnected: Bool
    let selected: Bool
    let wireStartPinIndex: Int?
    let select: () -> Void
    let selectPin: (Int) -> Void
    private var bounds: CGRect { symbol.kind.body(at:.zero, rotation:symbol.rotation, size:symbol.size) }
    private var offsets: [CGPoint] { symbol.kind.pins(at:.zero, rotation:symbol.rotation, size:symbol.size, blockPins:symbol.blockPins) }
    /// Small symbols still get a finger-sized (44 pt) select / drag target.
    private var hitSize: CGSize { CGSize(width:max(bounds.width,44), height:max(bounds.height,44)) }
    var body: some View {
        ZStack {
            if !symbol.kind.isBlock {
                Button(action:select) {
                    Color.clear.frame(width:hitSize.width,height:hitSize.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
            Group {
                if symbol.kind.isBlock {
                    // Icon and title share one row; the title shrinks to fit the block width.
                    HStack(spacing: 4) {
                        Image(systemName: symbol.icon).font(.system(size:12)).foregroundStyle(.secondary)
                        Text(symbol.title).font(.system(size:12,weight:.medium)).lineLimit(1).minimumScaleFactor(0.4)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: bounds.width, height: bounds.height)
                } else {
                    CircuitGlyph(kind:symbol.kind, rotation:symbol.rotation)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(symbol.title) シンボル、\(isConnected ? "接続あり" : "未接続")")
            .accessibilityIdentifier("symbol-\(symbol.title)")
            .accessibilityValue("kind=\(symbol.kind.rawValue), style=\(symbol.kind.isBlock ? "block" : "circuit")")

            ForEach(0..<(symbol.kind.isBlock ? symbol.blockPins.count : symbol.kind.pinCount), id: \.self) { index in
                pin(index).offset(x:offsets[index].x,y:offsets[index].y)
            }
            if symbol.kind.isBlock {
                Text("size").font(.system(size:1)).opacity(0.01)
                    .offset(x: bounds.width/2 - 6, y: bounds.height/2 - 3)   // off the centre so taps at the block's middle are unaffected
                    .accessibilityIdentifier("symbol-\(symbol.title)-size")
                    .accessibilityValue("\(Int(symbol.size.width)),\(Int(symbol.size.height))")
                    .allowsHitTesting(false)
                Text("icon").font(.system(size:1)).opacity(0.01)
                    .offset(x: bounds.width/2 - 3, y: bounds.height/2 - 6)
                    .accessibilityIdentifier("symbol-\(symbol.title)-icon")
                    .accessibilityValue(symbol.icon)
                    .allowsHitTesting(false)
            }
            if !symbol.kind.isBlock {
                Text("\(symbol.rotation)").font(.system(size:1)).opacity(0.01)
                    .accessibilityIdentifier("symbol-\(symbol.title)-rotation")
                    .accessibilityValue("\(symbol.rotation)")
                    .allowsHitTesting(false)

            }
        }
        .frame(width: hitSize.width, height: hitSize.height)
        .background {
            if symbol.kind.isBlock { RoundedRectangle(cornerRadius: 6).fill(.background).frame(width: bounds.width, height: bounds.height) }
        }
        .contentShape(Rectangle())
        .overlay {
            if !symbol.kind.isBlock { label }
        }
        .overlay {
            if symbol.kind.isBlock || selected {
                RoundedRectangle(cornerRadius: symbol.kind.isBlock ? 6 : 8)
                    .stroke(selected ? Color.accentColor.opacity(symbol.kind.isBlock ? 1 : 0.5) : .primary,
                            lineWidth: symbol.kind.isBlock ? (selected ? 3 : 2) : 1)
                    .frame(width: bounds.width, height: bounds.height)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Horizontal symbols: just below the body. Vertical symbols: to the right of it.
    /// Always upright, never part of the hit area. A zero-size frame anchors the text edge.
    @ViewBuilder private var label: some View {
        let text = Text(symbol.title).font(.system(size:10)).fixedSize()
        // Pins sitting on the edge the label hangs from (transistors, relays…) need extra room.
        let below = offsets.contains { abs($0.y - bounds.maxY) < 1 } ? 10 : 0
        let right = offsets.contains { abs($0.x - bounds.maxX) < 1 } ? 10 : 0
        if symbol.rotation % 180 == 0 {
            text.frame(height:0, alignment:.top)
                .offset(y:bounds.height/2 + 3 + CGFloat(below))
                .allowsHitTesting(false).accessibilityHidden(true)
        } else {
            text.frame(width:0, alignment:.leading)
                .offset(x:bounds.width/2 + 6 + CGFloat(right))
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private func pin(_ index: Int) -> some View {
        Button { selectPin(index) } label: {
            Circle()
                .fill(wireStartPinIndex == index ? Color.accentColor : .clear)
                .stroke(isConnected ? .green : .orange, lineWidth: 2)
                .frame(width: 8, height: 8)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol.kind.isBlock ? (symbol.blockPins[index].side == .left ? "左ピン" : "右ピン") : symbol.kind.pinSpecs[index].name)
        .accessibilityIdentifier("symbol-\(symbol.title)-pin-\(index)")
        .accessibilityValue("\(symbol.position.x + offsets[index].x),\(symbol.position.y + offsets[index].y)")
        .accessibilityAddTraits(wireStartPinIndex == index ? .isSelected : [])
    }
}

private struct NoteCard: View {
    @Binding var note: NoteItem
    let selected: Bool
    let select: () -> Void
    var body: some View {
        // `.topLeading` on the frame below anchors this (possibly shorter than the frame) stack at the top,
        // so there is no need for a trailing Spacer - which would only eat into the room the body text has.
        VStack(alignment: .leading, spacing: 4) {
            HStack { Image(systemName: note.complete ? "checkmark.circle.fill" : note.icon); Text(note.type.rawValue); Spacer() }.font(.caption.weight(.medium))
            Text(note.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            Text(note.body).font(.caption)
        }
        .foregroundStyle(note.complete ? .secondary : .primary)
        .padding(10)
        .frame(width: note.size.width, height: note.size.height, alignment: .topLeading)
        // The body can outgrow a note shrunk to its minimum; clip rather than spill onto the canvas.
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .background(note.complete ? Color.gray.opacity(0.16) : Color.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 3))
        .opacity(note.complete ? 0.68 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: select)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("experiment-note-\(note.title)")
        .accessibilityValue("x=\(Int(note.position.x)), y=\(Int(note.position.y))")
        .overlay(alignment: .topLeading) {
            Text("size").font(.system(size:1)).opacity(0.01)
                .accessibilityIdentifier("experiment-note-\(note.title)-size")
                .accessibilityValue("\(Int(note.size.width)),\(Int(note.size.height))")
                .allowsHitTesting(false)
            Text("anchor").font(.system(size:1)).opacity(0.01)
                .accessibilityIdentifier("experiment-note-\(note.title)-anchor")
                .accessibilityValue(note.anchor.map { "\(Int($0.x)),\(Int($0.y)),\(note.relateCorner.rawValue)" } ?? "")
                .allowsHitTesting(false)
            // The relate line's near end, using the exact same calculation as the Canvas drawing (the
            // shared NoteCorner.point(in:)) - lets tests confirm it actually follows a move/resize, not
            // just that the far end (anchor, above) stayed put (Codex minor, 4A round 1).
            Text("relateStart").font(.system(size:1)).opacity(0.01)
                .accessibilityIdentifier("experiment-note-\(note.title)-relate-start")
                .accessibilityValue(note.anchor == nil ? "" : {
                    let bounds = CGRect(x: note.position.x-note.size.width/2, y: note.position.y-note.size.height/2, width: note.size.width, height: note.size.height)
                    let point = note.relateCorner.point(in: bounds)
                    return "\(Int(point.x)),\(Int(point.y))"
                }())
                .allowsHitTesting(false)
            // Mirrors the block's `-icon` hidden text: Image(systemName:) is not reliably queryable once
            // nested inside a .accessibilityElement(children:) group.
            Text("icon").font(.system(size:1)).opacity(0.01)
                .accessibilityIdentifier("experiment-note-\(note.title)-icon")
                .accessibilityValue(note.icon)
                .allowsHitTesting(false)
        }
    }
}

/// A plain text label on the canvas (5C) - no title/type/icon/anchor/resize, unlike NoteCard; just its own
/// content is both what it shows and (mirroring how SymbolCard/NoteCard use their own title) what its
/// accessibility identifier is built from.
private struct TextCard: View {
    @Binding var text: TextItem
    let selected: Bool
    let editMode: Bool
    let scale: CGFloat
    let select: () -> Void
    let delete: () -> Void
    var body: some View {
        Text(text.body)
            .font(.body)
            .padding(6)
            .background(selected ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture(perform: select)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("text-\(text.body)")
            .accessibilityValue("x=\(Int(text.position.x)), y=\(Int(text.position.y))")
            .overlay(alignment: .topTrailing) {
                if editMode {
                    let side = ResizableGeometry.screenConstant(28, scale: scale)
                    Button(action: delete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: side*0.75))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .frame(width: side, height: side)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: side/2, y: -side/2)
                    .accessibilityLabel("テキストを削除")
                    .accessibilityIdentifier("text-\(text.body)-edit-delete")
                }
            }
    }
}

/// Draws the grid, and - since it is exactly canvasSize, unlike the (larger, pannable) viewport behind it -
/// also an opaque fill and border for the canvas's own bounds, so where "the canvas" actually ends is
/// visible (feedback, 2026-09-29: "どこまでが有効な範囲かわかりません").
private struct Grid: View {
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(bounds), with: .color(Color(.systemBackground)))
            var path = Path()
            for x in stride(from: 0, through: size.width, by: 24) { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)) }
            for y in stride(from: 0, through: size.height, by: 24) { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y)) }
            context.stroke(path, with: .color(.secondary.opacity(0.12)), lineWidth: 1)
            context.stroke(Path(bounds), with: .color(.accentColor.opacity(0.6)), lineWidth: 3)
        }
    }
}

/// A zero-size marker view, only used to reach its own `window` once attached (see WindowAttachingView
/// below) and as the coordinate space to test whether a gesture started over the canvas.
private final class WindowAttachingView: UIView {
    var onWindowAvailable: ((UIView) -> Void)?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { onWindowAvailable?(self) }
    }
}

/// Two-finger-only pan (5B), available regardless of the active tool, anywhere over the canvas. Built on
/// UIKit rather than a SwiftUI gesture: SwiftUI has no "exactly N fingers" drag gesture, and DragGesture
/// always tracks whichever finger touched down first.
///
/// The recognizer is attached to the *window*, not to this representable's own small view: UIKit only
/// delivers touches to the recognizers on the hit-tested view and its ancestors, not to unrelated sibling
/// views - a recognizer sitting on a sibling overlay never sees the first finger at all once a single-finger
/// touch has already been dispatched to a symbol/wire/background view elsewhere in the tree (Codex major,
/// 5B round 1: minimumNumberOfTouches=2 could never be satisfied that way). The window is a true ancestor of
/// every touch in the app, so both fingers reach it regardless of which view underneath was hit-tested.
/// `gestureRecognizerShouldBegin` then scopes it back down to only the canvas's own area, and
/// `cancelsTouchesInView = false` plus the simultaneous-recognition delegate keep every single-finger
/// gesture, and the canvas's own two-finger pinch-to-zoom, working exactly as before.
private struct TwoFingerPanOverlay: UIViewRepresentable {
    /// Fires once, when the recognizer actually transitions to .began - lets the caller claim the shared
    /// activePanSource before the first onChanged arrives (Codex major, 5B round 3: nothing previously
    /// stopped a single-finger edit drag from starting *during* an already-active two-finger pan, since
    /// isEditDragActive was only consulted at the two-finger gesture's own start).
    var onBegan: () -> Void = {}
    let onChanged: (CGSize) -> Void
    let onEnded: () -> Void
    /// Whether a single-finger edit drag (symbol/note move, either resize, a wire segment) is already
    /// tracking a touch - checked fresh at gesture-start time, not just once. A second finger joining one of
    /// those must not also start panning the canvas underneath it (Codex major, 5B round 2).
    let isEditDragActive: () -> Bool
    /// Fires once the recognizer has actually been added to a window. XCUITest has no public API to
    /// synthesize a genuine two-finger pan (only tap and pinch have dedicated methods), so this is the one
    /// part of the wiring a UI test can still confirm: that attachment itself succeeded, not left silently
    /// failing (Codex major, 5B round 1, was exactly a silent wiring failure of this kind).
    var onAttached: (() -> Void)? = nil

    func makeUIView(context: Context) -> UIView {
        let view = WindowAttachingView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false   // never itself a hit-test target; only a scope/anchor
        view.onWindowAvailable = { [coordinator = context.coordinator] scopeView in
            coordinator.attachIfNeeded(scopeView: scopeView)
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        // Refreshed on every update, not just captured once at makeCoordinator time: onChanged closes over
        // this render's viewportSize (for boundedCanvasOffset), which can change (rotation, split view) -
        // Codex minor, 5B round 2.
        context.coordinator.onBegan = onBegan
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.isEditDragActive = isEditDragActive
        if let scopeView = uiView.window != nil ? uiView : nil {
            context.coordinator.attachIfNeeded(scopeView: scopeView)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(onBegan: onBegan, onChanged: onChanged, onEnded: onEnded, isEditDragActive: isEditDragActive, onAttached: onAttached) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onBegan: () -> Void
        var onChanged: (CGSize) -> Void
        var onEnded: () -> Void
        var isEditDragActive: () -> Bool
        let onAttached: (() -> Void)?
        private weak var scopeView: UIView?
        private var didAttach = false
        init(onBegan: @escaping () -> Void, onChanged: @escaping (CGSize) -> Void, onEnded: @escaping () -> Void, isEditDragActive: @escaping () -> Bool, onAttached: (() -> Void)?) {
            self.onBegan = onBegan; self.onChanged = onChanged; self.onEnded = onEnded; self.isEditDragActive = isEditDragActive; self.onAttached = onAttached
        }
        func attachIfNeeded(scopeView: UIView) {
            self.scopeView = scopeView
            guard !didAttach, let window = scopeView.window else { return }
            didAttach = true
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.minimumNumberOfTouches = 2
            recognizer.maximumNumberOfTouches = 2
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            window.addGestureRecognizer(recognizer)
            onAttached?()
        }
        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let window = recognizer.view else { return }
            switch recognizer.state {
            case .began:
                onBegan()
            case .changed:
                let t = recognizer.translation(in: window)
                onChanged(CGSize(width: t.x, height: t.y))
            case .ended, .cancelled, .failed:
                onEnded()
            default: break
            }
        }
        // Only a gesture that actually starts over the canvas's own area, and not while a single-finger edit
        // drag is already under way there, should pan it - the recognizer itself is window-wide so it can
        // see both fingers regardless of which view was hit-tested.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let scopeView, !isEditDragActive() else { return false }
            let point = gestureRecognizer.location(in: scopeView)
            return scopeView.bounds.contains(point)
        }
        // Lets this coexist with every single-finger gesture already tracking a touch it also observes, and
        // with the canvas's own pinch-to-zoom (also two-finger), rather than one stealing the gesture from
        // the other. (isEditDragActive, above, is what actually keeps an edit drag and a pan from both
        // mutating the diagram at once - this delegate method only governs simultaneous *recognition*.)
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}

/// Categorised SF Symbols grid for choosing an icon (BlockIcon.categories for a block, NoteIcon.categories
/// for a note); pushed from the inspector.
private struct IconPickerView: View {
    @Binding var icon: String
    let categories: [(name: String, icons: [String])]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(categories, id: \.name) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.name).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
                            ForEach(category.icons, id: \.self) { name in
                                Button { icon = name; dismiss() } label: {
                                    Image(systemName: name)
                                        .font(.title2)
                                        .frame(width: 48, height: 48)
                                        .background(icon == name ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(icon == name ? Color.accentColor : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(name)
                                .accessibilityIdentifier("icon-picker-\(name)")
                                .accessibilityAddTraits(icon == name ? .isSelected : [])
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("アイコンを選択")
    }
}

private extension CGPoint { func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) } }
