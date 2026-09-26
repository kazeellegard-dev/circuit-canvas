//
//  ContentView.swift
//  CircuitCanvas
//
//  Created by Toru Yamaguchi on 2026/09/20.
//

import SwiftUI

private enum Tool { case select, symbol, note, wire }
private enum NoteType: String, CaseIterable, Identifiable { case modification = "改造", measurement = "測定", confirmation = "確認", unresolved = "未解決", caution = "注意"; var id: Self { self } }
private struct SymbolItem: Identifiable { let id = UUID(); var title: String; var kind: SymbolKind; var position: CGPoint; var icon: String { kind.icon } }
private struct NoteItem: Identifiable { let id = UUID(); var type: NoteType = .modification; var title: String; var body: String; var position: CGPoint; var complete = false; var anchor: CGPoint? }
private struct WireItem: Identifiable { let id = UUID(); var start: CGPoint; var end: CGPoint; var points: [CGPoint] = []; var manual = false; var manualPoints: [CGPoint] = [] }

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var tool: Tool = .select
    @State private var selectedLibrary: SymbolKind = .block
    @State private var selectedCategory: SymbolCategory = .block
    @State private var selectedSymbol: UUID?
    @State private var selectedNote: UUID?
    @State private var linkingNote: UUID?
    @State private var pendingWireStart: CGPoint?
    @State private var dragOrigins: [UUID: CGPoint] = [:]
    @State private var noteDragOrigins: [UUID: CGPoint] = [:]
    private struct SegmentDrag {
        let wireID: UUID
        let segment: Int
        let origin: [CGPoint]
    }
    @State private var segmentDrag: SegmentDrag?
    @State private var isPanningCanvas = false
    @State private var canvasOffset = CGSize.zero
    @State private var canvasPanOrigin = CGSize.zero
    @State private var canvasScale: CGFloat = 1
    @State private var canvasScaleOrigin: CGFloat = 1
    @State private var showLibrary = false
    @State private var showInspector = false
    @State private var symbols: [SymbolItem] = [
        .init(title: "24 V → 5 V", kind: .converter, position: .init(x: 120, y: 160)),
        .init(title: "Main MCU", kind: .mcu, position: .init(x: 370, y: 250)),
        .init(title: "CAN", kind: .can, position: .init(x: 620, y: 250)),
        .init(title: "Temperature", kind: .sensor, position: .init(x: 120, y: 390))
    ]
    @State private var notes: [NoteItem] = [.init(title: "R12を変更", body: "10 kΩへ変更して波形を再測定", position: .init(x: 430, y: 80), anchor: .init(x: 370, y: 190))]
    @State private var wires: [WireItem] = [
        .init(start: .init(x: 195, y: 160), end: .init(x: 295, y: 250)),
        .init(start: .init(x: 445, y: 250), end: .init(x: 545, y: 250)),
        .init(start: .init(x: 195, y: 390), end: .init(x: 295, y: 250))
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
            .navigationTitle("Circuit Canvas")
            .onAppear { reroute() }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("選択", systemImage: "cursorarrow") { tool = .select; linkingNote = nil }
                    Button("配線", systemImage: "point.3.connected.trianglepath.dotted") { tool = .wire; pendingWireStart = nil; selectedSymbol = nil; selectedNote = nil }
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
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(SymbolCategory.allCases) { category in
                        Button(category.rawValue) { selectedCategory = category }
                            .font(.caption)
                            .padding(8)
                            .background(selectedCategory == category ? Color.accentColor.opacity(0.15) : .clear, in: Capsule())
                            .accessibilityIdentifier("library-category-\(category.rawValue)")
                            .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                    }
                }.padding(.horizontal, 12)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SymbolKind.allCases.filter { $0.category == selectedCategory }) { kind in
                        Button { selectedLibrary = kind; tool = .symbol } label: {
                            VStack(spacing: 5) {
                                if kind.isBlock {
                                    Image(systemName: kind.icon).font(.title3).frame(height: 32)
                                } else {
                                    CircuitSymbolShape(kind: kind).stroke(lineWidth: 1.5).frame(width: 75, height: 32)
                                }
                                Text(kind.rawValue).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(width: 92, height: 72)
                            .foregroundStyle(selectedLibrary == kind ? Color.accentColor : Color.primary)
                            .background(selectedLibrary == kind ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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
                    .contentShape(Rectangle())
                    .gesture(canvasPanGesture(in: proxy.size))
                    .simultaneousGesture(canvasTapGesture)
                    .accessibilityIdentifier("circuit-canvas")
                    .accessibilityValue("scale=\(Int(canvasScale * 100)), offsetX=\(Int(canvasOffset.width)), offsetY=\(Int(canvasOffset.height))")
                canvasContent
                    .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
                    .scaleEffect(canvasScale, anchor: .topLeading)
                    .offset(canvasOffset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .coordinateSpace(name: "editorViewport")
            .simultaneousGesture(canvasZoomGesture)
            .clipped()
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    if linkingNote != nil { hint("arrowshape.turn.up.right", "関連付けたい位置をタップ") }
                    else if tool == .note { hint("note.text.badge.plus", "キャンバスをタップして付箋を配置") }
                    else if tool == .symbol { hint("plus.square.on.square", "\(selectedLibrary.rawValue)を配置") }
                    else if tool == .wire { hint("point.3.connected.trianglepath.dotted", pendingWireStart == nil ? "始点のピンをタップ" : "終点のピンをタップ（直交で自動配線）") }
                }.padding(16).allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                zoomIndicator
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
    }

    private var zoomIndicator: some View {
        Label("倍率 \(Int(canvasScale * 100))%", systemImage: "arrow.up.left.and.arrow.down.right")
            .font(.caption.weight(.medium))
            .padding(8)
            .background(.thinMaterial, in: Capsule())
    }

    private var canvasSize: CGSize { .init(width: 2_400, height: 1_800) }

    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
                Grid().allowsHitTesting(false)
                Canvas { context, _ in
                    for note in notes { if let anchor = note.anchor { var path = Path(); path.move(to: note.position); path.addLine(to: anchor); context.stroke(path, with: .color(.secondary), style: .init(lineWidth: 1, dash: [4, 4])) } }
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
                ForEach(symbols) { symbol in
                    SymbolCard(
                        symbol: symbol,
                        isConnected: isConnected(symbol),
                        selected: selectedSymbol == symbol.id,
                        wireStartPinIndex: pendingWirePinIndex(for: symbol),
                        selectPin: { index in
                            guard tool == .wire else { return }
                            selectWirePin(pins(for: symbol)[index])
                        }
                    )
                        .position(symbol.position)
                        .onTapGesture {
                            guard tool == .select else { return }
                            selectedSymbol = symbol.id
                            selectedNote = nil
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in move(symbolID: symbol.id, by: value.translation) }
                                .onEnded { _ in dragOrigins[symbol.id] = nil }
                        )
                }
                ForEach($notes) { $note in
                    NoteCard(
                        note: $note,
                        selected: selectedNote == note.id,
                        select: {
                            guard tool == .select else { return }
                            selectedNote = note.id
                            selectedSymbol = nil
                        }
                    )
                        .position(note.position)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in move(noteID: note.id, by: value.translation) }
                                .onEnded { _ in noteDragOrigins[note.id] = nil }
                        )
                        .contextMenu { Button(note.complete ? "未完了に戻す" : "完了にする", systemImage: note.complete ? "arrow.uturn.backward" : "checkmark") { note.complete.toggle() }; Button("関連付け", systemImage: "arrowshape.turn.up.right") { linkingNote = note.id } }
                }

            }
    }

    private var canvasTapGesture: some Gesture {
        SpatialTapGesture(coordinateSpace: .named("editorViewport")).onEnded { tap in
                let point = canvasPoint(from: tap.location)
                if let id = linkingNote { setAnchor(id, point); linkingNote = nil }
                else if tool == .wire, let pin = nearestPin(to: point) {
                    selectWirePin(pin)
                }
                else if tool == .note { notes.append(.init(title: "新しいメモ", body: "内容を入力", position: point)); selectedNote = notes.last?.id; tool = .select }
                else if tool == .symbol { symbols.append(.init(title: selectedLibrary.rawValue, kind: selectedLibrary, position: point)); tool = .select; reroute() }
                else { selectedNote = nil; selectedSymbol = nil }
            }
    }

    private var inspector: some View {
        Form {
            if let id = selectedSymbol, let symbol = symbolBinding(for: id) {
                Section("シンボル") {
                    Text(symbol.wrappedValue.title)
                    TextField("名称", text: symbol.title)
                    LabeledContent("接続", value: isConnected(symbol.wrappedValue) ? "接続あり" : "未接続")
                        .accessibilityIdentifier("symbol-connection-status")
                        .accessibilityValue(isConnected(symbol.wrappedValue) ? "接続あり" : "未接続")
                    Button("シンボルを削除", role: .destructive) {
                        removeSymbol(id)
                    }
                }
            } else if let id = selectedNote, let note = noteBinding(for: id) {
                Section("実験メモ") {
                    Picker("種別", selection: note.type) { ForEach(NoteType.allCases) { Text($0.rawValue).tag($0) } }
                    TextField("タイトル", text: note.title)
                    TextField("本文", text: note.body, axis: .vertical)
                    Toggle("完了", isOn: note.complete)
                    Button("関連付けを開始", systemImage: "arrowshape.turn.up.right") { linkingNote = id }
                    Button("メモを削除", role: .destructive) {
                        removeNote(id)
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
                Section("操作") { Text("＋メモを押して任意位置に付箋を置けます。付箋を長押しして「関連付け」を選ぶと、引出し線を追加できます。") }
            }
        }.formStyle(.grouped)
    }

    private func setAnchor(_ id: UUID, _ point: CGPoint) { guard let i = notes.firstIndex(where: { $0.id == id }) else { return }; notes[i].anchor = point }
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
            if !alreadyExists { wires.append(.init(start: start, end: pin)); reroute() }
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
            set: { updated in guard let index = symbols.firstIndex(where: { $0.id == id }) else { return }; symbols[index] = updated }
        )
    }
    private func noteBinding(for id: UUID) -> Binding<NoteItem>? {
        guard let initial = notes.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { notes.first(where: { $0.id == id }) ?? initial },
            set: { updated in guard let index = notes.firstIndex(where: { $0.id == id }) else { return }; notes[index] = updated }
        )
    }
    private func removeSymbol(_ id: UUID) {
        guard let symbol = symbols.first(where: { $0.id == id }) else { return }
        let symbolPins = pins(for: symbol)
        wires.removeAll { wire in
            symbolPins.contains { pin in wire.start.distance(to: pin) < 1 || wire.end.distance(to: pin) < 1 }
        }
        selectedSymbol = nil
        symbols.removeAll { $0.id == id }; reroute()
    }
    private func removeNote(_ id: UUID) {
        selectedNote = nil
        linkingNote = nil
        notes.removeAll { $0.id == id }
    }
    private func canvasPanGesture(in viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("editorViewport"))
            .onChanged { value in
                // Very short transparent targets can deliver the touch to this
                // background. Resolve once at touch-down and retain that choice.
                if segmentDrag == nil && !isPanningCanvas {
                    beginSegmentDrag(at: value.startLocation, translation: value.translation)
                    isPanningCanvas = segmentDrag == nil
                }
                if segmentDrag != nil {
                    updateSegmentDrag(translation: value.translation)
                    return
                }
                canvasOffset = boundedCanvasOffset(
                    CGSize(width: canvasPanOrigin.width + value.translation.width, height: canvasPanOrigin.height + value.translation.height),
                    in: viewportSize
                )
            }
            .onEnded { _ in
                canvasPanOrigin = canvasOffset
                segmentDrag = nil
                isPanningCanvas = false
            }
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
        reroute()
    }
    private func move(noteID: UUID, by translation: CGSize) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        let origin = noteDragOrigins[noteID] ?? notes[index].position
        noteDragOrigins[noteID] = origin
        notes[index].position = CGPoint(x: origin.x + translation.width, y: origin.y + translation.height)
    }
    private func pins(for symbol: SymbolItem) -> [CGPoint] { symbol.kind.pins(at: symbol.position) }
    private func nearestPin(to point: CGPoint) -> CGPoint? { let pin = symbols.flatMap(pins).min { $0.distance(to: point) < $1.distance(to: point) }; guard let pin, pin.distance(to: point) < 70 else { return nil }; return pin }
    private func isConnected(_ symbol: SymbolItem) -> Bool { pins(for: symbol).contains { pin in wires.contains { $0.start.distance(to: pin) < 1 || $0.end.distance(to: pin) < 1 } } }

    private func hint(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.footnote.weight(.medium)).padding(10)
            .background(.thinMaterial, in: Capsule()).accessibilityIdentifier("operation-hint")
    }
    private var bodies: [CGRect] { symbols.map { CGRect(x: $0.position.x-75, y: $0.position.y-32, width: 150, height: 64) } }
    private func reroute() {
        var occupied = wires.filter(\.manual).map { WireRouting.reattach($0.manualPoints, start: $0.start, end: $0.end) }
        for i in wires.indices {
            if wires[i].manual { wires[i].points = WireRouting.reattach(wires[i].manualPoints, start: wires[i].start, end: wires[i].end) }
            else {
                wires[i].points = WireRouting.route(.init(start: wires[i].start, end: wires[i].end), bodies: bodies, occupied: occupied)
                occupied.append(wires[i].points)
            }
        }
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
            .allowsHitTesting(tool == .select)
    }
    private func beginSegmentDrag(at viewportPoint: CGPoint, translation: CGSize) {
        guard tool == .select, segmentDrag == nil,
              let hit = WireRouting.nearestInteriorSegment(
                to: canvasPoint(from: viewportPoint), paths: wires.map(\.points), maximumDistance: 8, translation: translation
              ) else { return }
        segmentDrag = SegmentDrag(wireID: wires[hit.wire].id,
                                  segment: hit.segment, origin: wires[hit.wire].points)
    }

    private func updateSegmentDrag(translation: CGSize) {
        guard let drag = segmentDrag,
              let i = wires.firstIndex(where: { $0.id == drag.wireID }) else { return }
        let horizontal = drag.origin[drag.segment].y == drag.origin[drag.segment+1].y
        let delta = (horizontal ? translation.height : translation.width) / canvasScale
        wires[i].points = WireRouting.moved(drag.origin, segment: drag.segment, delta: delta, bodies: bodies)
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
    let selectPin: (Int) -> Void
    var body: some View {
        ZStack {
            Group {
                if symbol.kind.isBlock {
                    VStack(spacing: 6) {
                        Image(systemName: symbol.icon).foregroundStyle(.secondary)
                        Text(symbol.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    }
                } else {
                    ZStack(alignment: .bottom) {
                        CircuitSymbolShape(kind: symbol.kind).stroke(.primary, lineWidth: 2)
                        Text(symbol.title).font(.system(size: 10)).lineLimit(1)
                            .padding(.horizontal, 8)
                    }.frame(width: 150, height: 64)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(symbol.title) シンボル、\(isConnected ? "接続あり" : "未接続")")
            .accessibilityIdentifier("symbol-\(symbol.title)")
            .accessibilityValue("kind=\(symbol.kind.rawValue), style=\(symbol.kind.isBlock ? "block" : "circuit")")

            pin(0).offset(x: -75)
            if symbol.kind.pinCount == 2 { pin(1).offset(x: 75) }
        }
        .frame(width: 150, height: 64)
        .background {
            if symbol.kind.isBlock { RoundedRectangle(cornerRadius: 8).fill(.background) }
        }
        .contentShape(Rectangle())
        .overlay {
            if symbol.kind.isBlock || selected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.accentColor.opacity(symbol.kind.isBlock ? 1 : 0.5) : .primary,
                            lineWidth: symbol.kind.isBlock ? (selected ? 3 : 2) : 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private func pin(_ index: Int) -> some View {
        Button { selectPin(index) } label: {
            Circle()
                .fill(wireStartPinIndex == index ? Color.accentColor : .clear)
                .stroke(isConnected ? .green : .orange, lineWidth: 2)
                .frame(width: 10, height: 10)
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(index == 0 ? "左ピン" : "右ピン")
        .accessibilityIdentifier("symbol-\(symbol.title)-pin-\(index)")
        .accessibilityValue("\(symbol.position.x + (index == 0 ? -75 : 75)),\(symbol.position.y)")
        .accessibilityAddTraits(wireStartPinIndex == index ? .isSelected : [])
    }
}

private struct NoteCard: View {
    @Binding var note: NoteItem
    let selected: Bool
    let select: () -> Void
    var body: some View { VStack(alignment: .leading, spacing: 6) { HStack { Image(systemName: note.complete ? "checkmark.circle.fill" : "wrench.and.screwdriver"); Text(note.type.rawValue); Spacer() }.font(.caption.weight(.medium)); Text(note.title).font(.subheadline.weight(.semibold)); Text(note.body).font(.caption).lineLimit(3) }.foregroundStyle(note.complete ? .secondary : .primary).padding(12).frame(width: 170, alignment: .leading).background(note.complete ? Color.gray.opacity(0.16) : Color.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 3)).opacity(note.complete ? 0.68 : 1).contentShape(RoundedRectangle(cornerRadius: 10)).onTapGesture(perform: select).accessibilityElement(children: .combine).accessibilityIdentifier("experiment-note-\(note.title)").accessibilityValue("x=\(Int(note.position.x)), y=\(Int(note.position.y))") }
}

private struct Grid: View { var body: some View { Canvas { context, size in var path = Path(); for x in stride(from: 0, through: size.width, by: 24) { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)) }; for y in stride(from: 0, through: size.height, by: 24) { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y)) }; context.stroke(path, with: .color(.secondary.opacity(0.12)), lineWidth: 1) } } }

private extension CGPoint { func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) } }
