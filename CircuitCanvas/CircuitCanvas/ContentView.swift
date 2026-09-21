//
//  ContentView.swift
//  CircuitCanvas
//
//  Created by Toru Yamaguchi on 2026/09/20.
//

import SwiftUI

private enum Tool { case select, symbol, note, wire }
private enum NoteType: String, CaseIterable, Identifiable { case modification = "改造", measurement = "測定", confirmation = "確認", unresolved = "未解決", caution = "注意"; var id: Self { self } }
private struct SymbolItem: Identifiable { let id = UUID(); var title: String; var icon: String; var position: CGPoint }
private struct NoteItem: Identifiable { let id = UUID(); var type: NoteType = .modification; var title: String; var body: String; var position: CGPoint; var complete = false; var anchor: CGPoint? }
private struct WireItem: Identifiable { let id = UUID(); var start: CGPoint; var end: CGPoint }

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var tool: Tool = .select
    @State private var selectedLibrary = "汎用ブロック"
    @State private var selectedNote: UUID?
    @State private var linkingNote: UUID?
    @State private var pendingWireStart: CGPoint?
    @State private var dragOrigins: [UUID: CGPoint] = [:]
    @State private var noteDragOrigins: [UUID: CGPoint] = [:]
    @State private var canvasOffset = CGSize.zero
    @State private var canvasPanOrigin = CGSize.zero
    @State private var canvasScale: CGFloat = 1
    @State private var canvasScaleOrigin: CGFloat = 1
    @State private var showLibrary = false
    @State private var showInspector = false
    @State private var symbols: [SymbolItem] = [
        .init(title: "24 V → 5 V", icon: "bolt.fill", position: .init(x: 120, y: 160)),
        .init(title: "Main MCU", icon: "cpu", position: .init(x: 370, y: 250)),
        .init(title: "CAN", icon: "arrow.left.and.right", position: .init(x: 620, y: 250)),
        .init(title: "Temperature", icon: "sensor.tag.radiowaves.forward", position: .init(x: 120, y: 390))
    ]
    @State private var notes: [NoteItem] = [.init(title: "R12を変更", body: "10 kΩへ変更して波形を再測定", position: .init(x: 430, y: 80), anchor: .init(x: 370, y: 190))]
    @State private var wires: [WireItem] = [
        .init(start: .init(x: 195, y: 160), end: .init(x: 295, y: 250)),
        .init(start: .init(x: 445, y: 250), end: .init(x: 545, y: 250)),
        .init(start: .init(x: 195, y: 390), end: .init(x: 295, y: 275))
    ]

    private let library = ["DC/DC", "MCU", "CAN", "抵抗", "GND", "センサー", "汎用ブロック"]
    private var compact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        NavigationStack {
            Group {
                VStack(spacing: 0) {
                    editor
                    Divider()
                    libraryView.frame(height: 104)
                }
            }
            .navigationTitle("Circuit Canvas")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("選択", systemImage: "cursorarrow") { tool = .select; linkingNote = nil }
                    Button("配線", systemImage: "point.3.connected.trianglepath.dotted") { tool = .wire; pendingWireStart = nil }
                    Button("＋シンボル", systemImage: "plus.square.on.square") { tool = .symbol }
                    Button("＋メモ", systemImage: "note.text.badge.plus") { tool = .note }
                    Button("\(Int(canvasScale * 100))%", systemImage: "arrow.up.left.and.arrow.down.right") { resetCanvasViewport() }
                    Button("確認", systemImage: "slider.horizontal.3") { showInspector = true }
                }
            }
            .sheet(isPresented: $showInspector) { NavigationStack { inspector.navigationTitle("インスペクタ") } }
        }
    }

    private var libraryView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(library, id: \.self) { name in
                    Button { selectedLibrary = name; tool = .symbol } label: {
                        VStack(spacing: 5) {
                            Image(systemName: icon(for: name)).font(.title3).frame(height: 26)
                            Text(name).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(width: 62, height: 72)
                        .foregroundStyle(selectedLibrary == name ? Color.accentColor : Color.primary)
                        .background(selectedLibrary == name ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(name)を配置")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private var editor: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(canvasPanGesture(in: proxy.size))
                    .simultaneousGesture(canvasTapGesture)
                    .accessibilityIdentifier("circuit-canvas")
                    .accessibilityValue("scale=\(Int(canvasScale * 100)), offsetX=\(Int(canvasOffset.width)), offsetY=\(Int(canvasOffset.height))")
                canvasContent
                    .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
                    .scaleEffect(canvasScale, anchor: .topLeading)
                    .offset(canvasOffset)
                VStack {
                    HStack {
                        Label("\(Int(canvasScale * 100))%", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.medium))
                            .padding(8)
                            .background(.thinMaterial, in: Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)
                .allowsHitTesting(false)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .coordinateSpace(name: "editorViewport")
            .simultaneousGesture(canvasZoomGesture)
            .clipped()
        }
    }

    private var canvasSize: CGSize { .init(width: 2_400, height: 1_800) }

    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
                Grid().allowsHitTesting(false)
                Canvas { context, _ in
                    for note in notes { if let anchor = note.anchor { var path = Path(); path.move(to: note.position); path.addLine(to: anchor); context.stroke(path, with: .color(.secondary), style: .init(lineWidth: 1, dash: [4, 4])) } }
                    for wire in wires {
                        var path = Path(); path.move(to: wire.start)
                        let middleX = (wire.start.x + wire.end.x) / 2
                        path.addLine(to: .init(x: middleX, y: wire.start.y)); path.addLine(to: .init(x: middleX, y: wire.end.y)); path.addLine(to: wire.end)
                        context.stroke(path, with: .color(.primary), lineWidth: 2)
                    }
                }.allowsHitTesting(false)
                ForEach(symbols) { symbol in
                    SymbolCard(symbol: symbol, isConnected: isConnected(symbol))
                        .position(symbol.position)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in move(symbolID: symbol.id, by: value.translation) }
                                .onEnded { _ in dragOrigins[symbol.id] = nil }
                        )
                }
                ForEach($notes) { $note in
                    NoteCard(
                        note: $note,
                        selected: selectedNote == note.id,
                        select: { selectedNote = note.id }
                    )
                        .position(note.position)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in move(noteID: note.id, by: value.translation) }
                                .onEnded { _ in noteDragOrigins[note.id] = nil }
                        )
                        .contextMenu { Button(note.complete ? "未完了に戻す" : "完了にする", systemImage: note.complete ? "arrow.uturn.backward" : "checkmark") { note.complete.toggle() }; Button("関連付け", systemImage: "arrowshape.turn.up.right") { linkingNote = note.id } }
                }
                if tool == .note { hint("note.text.badge.plus", "キャンバスをタップして付箋を配置") }
                if tool == .symbol { hint("plus.square.on.square", "\(selectedLibrary)を配置") }
                if tool == .wire { hint("point.3.connected.trianglepath.dotted", pendingWireStart == nil ? "始点のピンをタップ" : "終点のピンをタップ（直交で自動配線）") }
                if linkingNote != nil { hint("arrowshape.turn.up.right", "関連付けたい位置をタップ") }
            }
    }

    private var canvasTapGesture: some Gesture {
        SpatialTapGesture(coordinateSpace: .named("editorViewport")).onEnded { tap in
                let point = canvasPoint(from: tap.location)
                if let id = linkingNote { setAnchor(id, point); linkingNote = nil }
                else if tool == .wire, let pin = nearestPin(to: point) {
                    if let start = pendingWireStart { wires.append(.init(start: start, end: pin)); pendingWireStart = nil; tool = .select }
                    else { pendingWireStart = pin }
                }
                else if tool == .note { notes.append(.init(title: "新しいメモ", body: "内容を入力", position: point)); selectedNote = notes.last?.id; tool = .select }
                else if tool == .symbol { symbols.append(.init(title: selectedLibrary, icon: icon(for: selectedLibrary), position: point)); tool = .select }
                else { selectedNote = nil }
            }
    }

    private var inspector: some View {
        Form {
            if let id = selectedNote, let index = notes.firstIndex(where: { $0.id == id }) {
                Section("実験メモ") {
                    Picker("種別", selection: $notes[index].type) { ForEach(NoteType.allCases) { Text($0.rawValue).tag($0) } }
                    TextField("タイトル", text: $notes[index].title)
                    TextField("本文", text: $notes[index].body, axis: .vertical)
                    Toggle("完了", isOn: $notes[index].complete)
                    Button("関連付けを開始", systemImage: "arrowshape.turn.up.right") { linkingNote = id }
                }
            } else {
                Section("図面") { LabeledContent("シンボル", value: "\(symbols.count)"); LabeledContent("未完了メモ", value: "\(notes.filter { !$0.complete }.count)") }
                Section("配線チェック") {
                    LabeledContent("接続済み配線", value: "\(wires.count)")
                    ForEach(symbols) { symbol in Label(isConnected(symbol) ? "\(symbol.title) — 接続あり" : "\(symbol.title) — 未接続", systemImage: isConnected(symbol) ? "checkmark.circle.fill" : "exclamationmark.circle") .foregroundStyle(isConnected(symbol) ? .green : .orange) }
                }
                Section("操作") { Text("＋メモを押して任意位置に付箋を置けます。付箋を長押しして「関連付け」を選ぶと、引出し線を追加できます。") }
            }
        }.formStyle(.grouped)
    }

    private func setAnchor(_ id: UUID, _ point: CGPoint) { guard let i = notes.firstIndex(where: { $0.id == id }) else { return }; notes[i].anchor = point }
    private func canvasPanGesture(in viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("editorViewport"))
            .onChanged { value in
                canvasOffset = boundedCanvasOffset(
                    CGSize(width: canvasPanOrigin.width + value.translation.width, height: canvasPanOrigin.height + value.translation.height),
                    in: viewportSize
                )
            }
            .onEnded { _ in canvasPanOrigin = canvasOffset }
    }
    private var canvasZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in canvasScale = min(max(canvasScaleOrigin * value, 0.5), 2.5) }
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
    private func resetCanvasViewport() { canvasOffset = .zero; canvasPanOrigin = .zero; canvasScale = 1; canvasScaleOrigin = 1 }
    private func move(symbolID: UUID, by translation: CGSize) {
        guard let index = symbols.firstIndex(where: { $0.id == symbolID }) else { return }
        let origin = dragOrigins[symbolID] ?? symbols[index].position
        dragOrigins[symbolID] = origin
        let oldPosition = symbols[index].position
        let newPosition = CGPoint(x: origin.x + translation.width, y: origin.y + translation.height)
        let oldPins = pins(for: symbols[index])
        symbols[index].position = newPosition
        let newPins = pins(for: symbols[index])
        for wireIndex in wires.indices {
            for pinIndex in oldPins.indices {
                if wires[wireIndex].start.distance(to: oldPins[pinIndex]) < 1 { wires[wireIndex].start = newPins[pinIndex] }
                if wires[wireIndex].end.distance(to: oldPins[pinIndex]) < 1 { wires[wireIndex].end = newPins[pinIndex] }
            }
        }
        _ = oldPosition
    }
    private func move(noteID: UUID, by translation: CGSize) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        let origin = noteDragOrigins[noteID] ?? notes[index].position
        noteDragOrigins[noteID] = origin
        notes[index].position = CGPoint(x: origin.x + translation.width, y: origin.y + translation.height)
    }
    private func pins(for symbol: SymbolItem) -> [CGPoint] { [.init(x: symbol.position.x - 75, y: symbol.position.y), .init(x: symbol.position.x + 75, y: symbol.position.y)] }
    private func nearestPin(to point: CGPoint) -> CGPoint? { let pin = symbols.flatMap(pins).min { $0.distance(to: point) < $1.distance(to: point) }; guard let pin, pin.distance(to: point) < 70 else { return nil }; return pin }
    private func isConnected(_ symbol: SymbolItem) -> Bool { pins(for: symbol).contains { pin in wires.contains { $0.start.distance(to: pin) < 1 || $0.end.distance(to: pin) < 1 } } }
    private func icon(for name: String) -> String { ["DC/DC": "bolt.fill", "MCU": "cpu", "CAN": "arrow.left.and.right", "抵抗": "minus", "GND": "arrow.down.to.line", "センサー": "sensor.tag.radiowaves.forward", "汎用ブロック": "square.dashed"][name] ?? "square.dashed" }
    private func hint(_ icon: String, _ text: String) -> some View { VStack { Label(text, systemImage: icon).font(.footnote.weight(.medium)).padding(10).background(.thinMaterial, in: Capsule()); Spacer() }.padding().allowsHitTesting(false) }
}

private struct SymbolCard: View {
    let symbol: SymbolItem
    let isConnected: Bool
    var body: some View { VStack(spacing: 6) { Image(systemName: symbol.icon).foregroundStyle(.secondary); Text(symbol.title).font(.subheadline.weight(.medium)).lineLimit(1) }.frame(width: 150, height: 64).background(.background, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary, lineWidth: 2)).overlay { HStack { Circle().stroke(isConnected ? .green : .orange, lineWidth: 2).frame(width: 10, height: 10); Spacer(); Circle().stroke(isConnected ? .green : .orange, lineWidth: 2).frame(width: 10, height: 10) } }.accessibilityLabel("\(symbol.title) シンボル、\(isConnected ? "接続あり" : "未接続")") }
}

private struct NoteCard: View {
    @Binding var note: NoteItem
    let selected: Bool
    let select: () -> Void
    var body: some View { VStack(alignment: .leading, spacing: 6) { HStack { Image(systemName: note.complete ? "checkmark.circle.fill" : "wrench.and.screwdriver"); Text(note.type.rawValue); Spacer() }.font(.caption.weight(.medium)); Text(note.title).font(.subheadline.weight(.semibold)); Text(note.body).font(.caption).lineLimit(3) }.foregroundStyle(note.complete ? .secondary : .primary).padding(12).frame(width: 170, alignment: .leading).background(note.complete ? Color.gray.opacity(0.16) : Color.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 3)).opacity(note.complete ? 0.68 : 1).contentShape(RoundedRectangle(cornerRadius: 10)).onTapGesture(perform: select).accessibilityElement(children: .combine).accessibilityIdentifier("experiment-note-\(note.title)").accessibilityValue("x=\(Int(note.position.x)), y=\(Int(note.position.y))") }
}

private struct Grid: View { var body: some View { Canvas { context, size in var path = Path(); for x in stride(from: 0, through: size.width, by: 24) { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)) }; for y in stride(from: 0, through: size.height, by: 24) { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y)) }; context.stroke(path, with: .color(.secondary.opacity(0.12)), lineWidth: 1) } } }

private extension CGPoint { func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) } }
