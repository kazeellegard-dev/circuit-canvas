//
//  Coachmark.swift
//  CircuitCanvas
//
//  First-launch onboarding (3D): speech-bubble coachmarks that point at the real on-screen elements.
//

import SwiftUI
import UIKit

/// The elements a coachmark can point at. Each reports its own global frame (see reportsCoachmarkFrame)
/// wherever it is laid out, so the bubbles follow rotation, split view and toolbar changes.
enum CoachmarkTarget: Hashable {
    case library, wireTool, symbolTool, noteTool, canvas, inspectorButton, zoomIndicator
}

enum OnboardingStep: Int, CaseIterable {
    case library, tools, canvas, inspector, zoom

    var targets: [CoachmarkTarget] {
        switch self {
        case .library: [.library]
        case .tools: [.wireTool, .symbolTool, .noteTool]
        case .canvas: [.canvas]
        case .inspector: [.inspectorButton]
        case .zoom: [.zoomIndicator]
        }
    }
    var title: String {
        switch self {
        case .library: "ライブラリ"
        case .tools: "追加と配線"
        case .canvas: "キャンバス"
        case .inspector: "確認（インスペクタ）"
        case .zoom: "拡大・縮小と移動"
        }
    }
    var message: String {
        switch self {
        case .library: "ここからシンボルを選んで、キャンバスに置けます。カテゴリを切り替えると、ほかの記号も選べます。"
        case .tools: "「＋シンボル」でシンボルを、「＋メモ」で付箋を置けます。「配線」では、ピンを順にタップしてつなぎます。"
        case .canvas: "置いたシンボルをタップして選ぶと、回転ボタンや、大きさを変えるハンドルが出ます。"
        case .inspector: "選んだ項目の名称の変更や、接続の確認・削除は、ここから行います。"
        case .zoom: "ピンチで拡大・縮小、2本指のドラッグでキャンバスを移動できます（「キャンバス移動」を選ぶと1本指でも動かせます）。倍率の表示をタップすると、スライダーで倍率を変えられます。"
        }
    }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
}

/// Toolbar buttons are turned into UIKit bar items, so a SwiftUI geometry modifier on them never reports
/// their real on-screen frame, and their views carry no accessibility label until accessibility is active.
/// They are found instead by the SF Symbol their image view shows, and measured in window coordinates
/// (= the overlay's, which ignores safe areas). If nothing matches (a future UIKit change, or an item that
/// overflowed into a menu on a narrow screen), the overlay falls back to a centered bubble with no hole.
enum CoachmarkToolbarLocator {
    /// The symbols each target's button uses, including the name UIKit substitutes for it on display
    /// (seen on iPadOS 26: note.text.badge.plus is drawn as text.pad.header.badge.plus).
    static func symbolNames(for target: CoachmarkTarget) -> [String] {
        switch target {
        case .wireTool: ["point.3.connected.trianglepath.dotted"]
        case .symbolTool: ["plus.square.on.square"]
        case .noteTool: ["note.text.badge.plus", "text.pad.header.badge.plus"]
        case .inspectorButton: ["slider.horizontal.3"]
        default: []
        }
    }
    @MainActor static func frame(for target: CoachmarkTarget) -> CGRect? {
        let names = symbolNames(for: target)
        guard !names.isEmpty else { return nil }
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first,
              let navigationBar = firstView(ofType: UINavigationBar.self, in: window),
              let imageView = imageView(showingAnyOf: names, in: navigationBar) else { return nil }
        // The whole bar button (the tappable pill around the glyph), not just the glyph itself.
        var button: UIView = imageView
        while let parent = button.superview, parent.bounds.width <= 60, parent.bounds.height <= 60 { button = parent }
        return button.convert(button.bounds, to: nil)
    }
    @MainActor private static func firstView<T: UIView>(ofType type: T.Type, in view: UIView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews { if let found = firstView(ofType: type, in: subview) { return found } }
        return nil
    }
    @MainActor private static func imageView(showingAnyOf names: [String], in view: UIView) -> UIImageView? {
        if let imageView = view as? UIImageView, !imageView.isHidden, imageView.window != nil,
           let description = imageView.image?.description,
           names.contains(where: { description.contains("symbol(system: \($0))") }) { return imageView }
        for subview in view.subviews where !subview.isHidden {
            if let found = imageView(showingAnyOf: names, in: subview) { return found }
        }
        return nil
    }
}

extension View {
    /// Records this view's global frame under `target`, for the coachmark overlay to point at.
    func reportsCoachmarkFrame(_ target: CoachmarkTarget, into frames: Binding<[CoachmarkTarget: CGRect]>) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frames.wrappedValue[target] = $0 }
    }
}

/// Where a bubble goes relative to its (overlay-local) target: below it when there is room, otherwise
/// above, otherwise centered on top of it (a target as large as the canvas leaves room on neither side).
enum CoachmarkLayout {
    static let bubbleWidth: CGFloat = 340
    static let estimatedBubbleHeight: CGFloat = 210
    static let margin: CGFloat = 16

    enum Vertical: Equatable { case below(top: CGFloat), above(bottomInset: CGFloat), center }

    static func vertical(for target: CGRect?, in size: CGSize) -> Vertical {
        guard let target else { return .center }
        let needed = estimatedBubbleHeight + margin
        if size.height - target.maxY >= needed { return .below(top: target.maxY) }
        if target.minY >= needed { return .above(bottomInset: size.height - target.minY) }
        return .center
    }

    static func width(in size: CGSize) -> CGFloat { min(bubbleWidth, size.width - 2*margin) }

    /// The bubble's left edge: centered under the target, but kept fully on screen.
    static func leading(for target: CGRect?, in size: CGSize) -> CGFloat {
        let width = width(in: size)
        guard let target else { return (size.width - width)/2 }
        return min(max(target.midX - width/2, margin), size.width - margin - width)
    }
}

struct CoachmarkBubble: View {
    enum Arrow { case up, down, none }
    let step: OnboardingStep
    let arrow: Arrow
    let arrowX: CGFloat   // the arrow tip's x, relative to the bubble's own leading edge
    let width: CGFloat
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if arrow == .up { arrowView(pointingUp: true) }
            VStack(alignment: .leading, spacing: 10) {
                Text("\(step.rawValue + 1) / \(OnboardingStep.allCases.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("coachmark-progress")
                Text(step.title).font(.headline)
                    .accessibilityIdentifier("coachmark-title")
                Text(step.message).font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("スキップ", action: onSkip)
                        .accessibilityIdentifier("coachmark-skip")
                    Spacer()
                    Button(step.next == nil ? "完了" : "次へ", action: onNext)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("coachmark-next")
                }
                .padding(.top, 4)
            }
            .padding(16)
            .frame(width: width, alignment: .leading)
            // White in light mode, a lifted dark gray in dark mode (plain systemBackground is pure black there,
            // indistinguishable from the dimmed canvas); the accent border keeps the edge clear in both.
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor, lineWidth: 2))
            if arrow == .down { arrowView(pointingUp: false) }
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachmark")
    }

    private func arrowView(pointingUp: Bool) -> some View {
        CoachmarkArrow(pointingUp: pointingUp)
            .fill(Color.accentColor)
            .frame(width: 20, height: 11)
            .padding(.leading, min(max(arrowX - 10, 14), width - 34))
            .frame(width: width, alignment: .leading)
    }
}

private struct CoachmarkArrow: Shape {
    let pointingUp: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointingUp {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}
