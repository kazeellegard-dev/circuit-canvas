//
//  Export.swift
//  CircuitCanvas
//
//  PDF/PNG export: what area is exported, how it is rendered, and the export sheet itself.
//

import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF", png = "PNG"
    var id: Self { self }
    var contentType: UTType { self == .pdf ? .pdf : .png }
    var fileExtension: String { self == .pdf ? "pdf" : "png" }
}

enum ExportLayout {
    /// Blank space kept around the drawing.
    static let margin: CGFloat = 32

    /// The area to export: everything drawn plus a margin, kept within the canvas and rounded to whole
    /// points. nil when nothing is drawn. Points (wire bends, a note's anchor) are passed as zero-size rects.
    static func bounds(of rects: [CGRect], in canvas: CGRect) -> CGRect? {
        let drawn = rects.filter { !$0.isNull && !$0.isInfinite }
        guard let first = drawn.first else { return nil }
        let union = drawn.dropFirst().reduce(first) { $0.union($1) }
        let area = union.insetBy(dx: -margin, dy: -margin).intersection(canvas).integral
        return area.isNull || area.isEmpty ? nil : area
    }

    /// What a symbol paints on the canvas, in canvas coordinates: its body with room for the pins' rings,
    /// and its name, which for a circuit symbol hangs outside the body (SymbolKind.labelRect).
    static func symbolRects(_ symbol: SymbolItem) -> [CGRect] {
        let body = symbol.kind.body(at: symbol.position, rotation: symbol.rotation, size: symbol.size).insetBy(dx: -8, dy: -8)
        guard let label = symbol.kind.labelRect(title: symbol.title, rotation: symbol.rotation, size: symbol.size, blockPins: symbol.blockPins)
        else { return [body] }
        // A little slack for font rendering differences.
        return [body, label.offsetBy(dx: symbol.position.x, dy: symbol.position.y).insetBy(dx: -4, dy: -4)]
    }

    /// A file name without the characters Files and Finder refuse.
    static func fileName(for name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Circuit Canvas" : cleaned
    }
}

enum ExportRenderer {
    /// PNG at 2x (sharp on Retina screens and in print), PDF as one page exactly the size of `size`, in points.
    @MainActor static func data(for content: some View, size: CGSize, format: ExportFormat) -> Data? {
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        switch format {
        case .png:
            renderer.scale = 2
            return renderer.uiImage?.pngData()
        case .pdf:
            let data = NSMutableData()
            guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
            var rendered = false
            renderer.render { renderedSize, draw in
                var box = CGRect(origin: .zero, size: renderedSize)
                guard let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
                pdf.closePDF()
                rendered = true
            }
            return rendered ? data as Data : nil
        }
    }

    @MainActor static func preview(for content: some View, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1
        return renderer.uiImage
    }

    /// What the written file actually contains, read back from its bytes: pages and size (points for PDF,
    /// pixels for PNG). Shown in the sheet, and checked by the UI tests.
    static func summary(of data: Data, format: ExportFormat) -> (pages: Int, size: CGSize)? {
        switch format {
        case .png:
            guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
            return (1, CGSize(width: cgImage.width, height: cgImage.height))
        case .pdf:
            guard let provider = CGDataProvider(data: data as CFData), let pdf = CGPDFDocument(provider),
                  let page = pdf.page(at: 1) else { return nil }
            return (pdf.numberOfPages, page.getBoxRect(.mediaBox).size)
        }
    }
}

/// The value fileExporter writes for "ファイルに保存".
struct ExportFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf, .png]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// The diagram, ready to render: the view (already cropped to the exported area) and its size in points.
struct ExportDrawing {
    var content: AnyView
    var size: CGSize
}

struct ExportSheet: View {
    let name: String
    let hasNotes: Bool
    let draw: @MainActor (_ includeNotes: Bool) -> ExportDrawing?

    private struct Output {
        var data: Data
        var url: URL
        var preview: UIImage?
        var pages: Int
        var size: CGSize
    }
    private struct Options: Equatable { var format: ExportFormat; var includeNotes: Bool }

    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .pdf
    @State private var includeNotes = true
    @State private var output: Output?
    @State private var generated = false
    @State private var showFileExporter = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("形式") {
                    Picker("形式", selection: $format) {
                        ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("export-format")
                }
                Section {
                    Toggle("実験メモを含める", isOn: $includeNotes)
                        .disabled(!hasNotes)
                        .accessibilityIdentifier("export-include-notes")
                } footer: {
                    Text("オフにすると、実験メモと、メモの関連付けの線を除いて書き出します。")
                }
                Section {
                    if let output {
                        ShareLink(item: output.url) { Label("共有…", systemImage: "square.and.arrow.up") }
                            .accessibilityIdentifier("export-share")
                    }
                    Button("ファイルに保存…", systemImage: "folder") { showFileExporter = true }
                        .disabled(output == nil)
                        .accessibilityIdentifier("export-save-to-files")
                }
                Section("プレビュー") {
                    if let output {
                        if let preview = output.preview {
                            Image(uiImage: preview).resizable().scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 260)
                                .border(Color(.separator))
                                .accessibilityIdentifier("export-preview")
                        }
                        Text(format == .pdf
                             ? "\(output.pages) ページ・\(Int(output.size.width)) × \(Int(output.size.height)) pt"
                             : "\(Int(output.size.width)) × \(Int(output.size.height)) px")
                            .foregroundStyle(.secondary)
                    } else if generated {
                        Text("キャンバスに何も配置されていないため、書き出せません。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            // Outside the Form: a lazily built Form leaves off-screen rows out of the accessibility tree.
            .overlay(alignment: .bottomLeading) {
                Text("summary").font(.system(size: 1)).opacity(0.01)
                    .accessibilityIdentifier("export-summary")
                    .accessibilityValue(summaryValue)
                    .allowsHitTesting(false)
            }
            .navigationTitle("書き出し")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }.accessibilityIdentifier("export-close")
                }
            }
            .fileExporter(isPresented: $showFileExporter, document: output.map { ExportFileDocument(data: $0.data) },
                          contentType: format.contentType, defaultFilename: ExportLayout.fileName(for: name)) { result in
                if case .failure(let error) = result { errorMessage = "保存できませんでした。\n\(error.localizedDescription)" }
            }
            .alert("書き出し", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task(id: Options(format: format, includeNotes: includeNotes)) { generate() }
        }
    }

    private var summaryValue: String {
        guard let output else { return generated ? "empty" : "pending" }
        return "format=\(format.fileExtension);pages=\(output.pages);width=\(Int(output.size.width));height=\(Int(output.size.height));bytes=\(output.data.count)"
    }

    /// Re-rendered whenever an option changes, so the preview, the shared file and the saved file always match.
    private func generate() {
        defer { generated = true }
        let notes = hasNotes && includeNotes
        guard let drawing = draw(notes),
              let data = ExportRenderer.data(for: drawing.content, size: drawing.size, format: format),
              let summary = ExportRenderer.summary(of: data, format: format) else { output = nil; return }
        // A named file (not raw data) for the share sheet, so the recipient gets "<name>.pdf", not "data".
        let directory = FileManager.default.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory)
        let url = directory.appending(path: "\(ExportLayout.fileName(for: name)).\(format.fileExtension)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = "書き出せませんでした。\n\(error.localizedDescription)"
            output = nil
            return
        }
        output = Output(data: data, url: url, preview: ExportRenderer.preview(for: drawing.content, size: drawing.size),
                        pages: summary.pages, size: summary.size)
    }
}
