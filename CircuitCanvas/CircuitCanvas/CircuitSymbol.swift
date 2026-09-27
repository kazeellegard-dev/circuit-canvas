import SwiftUI

enum SymbolCategory: String, CaseIterable, Identifiable {
    case power = "電源", passive = "受動部品", semiconductor = "半導体", logic = "ロジック"
    case protection = "スイッチ・保護", load = "負荷・その他", relayConnector = "リレー・コネクタ", block = "ブロック"
    var id: Self { self }
}

/// Shared corner-drag resize math for anything sized in fixed steps within a min/max range (block-diagram
/// symbols, experiment notes): snapping the size, moving the opposite corner, and the resize handle's hit square.
enum ResizableGeometry {
    /// `base` scaled up so it stays constant on screen as the canvas zooms below 100 %: at `scale` 0.5 it doubles,
    /// at 1.0 or above it is unchanged (buttons and handles never shrink further when zoomed *in*).
    static func screenConstant(_ base: CGFloat, scale: CGFloat) -> CGFloat { base * max(1, 1 / scale) }
    static func snapped(_ proposed: CGSize, step: CGFloat, minimum: CGSize, maximum: CGSize) -> CGSize {
        func snap(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
            min(max(low + step * ((value - low) / step).rounded(), low), high)
        }
        return CGSize(width: snap(proposed.width, minimum.width, maximum.width),
                      height: snap(proposed.height, minimum.height, maximum.height))
    }
    /// Drag a corner (`sx`, `sy` = -1 left/top, +1 right/bottom) by `translation`; the opposite corner stays put.
    static func resized(center: CGPoint, size: CGSize, sx: CGFloat, sy: CGFloat, translation: CGSize,
                        step: CGFloat, minimum: CGSize, maximum: CGSize) -> (center: CGPoint, size: CGSize) {
        let next = snapped(CGSize(width: size.width + sx * translation.width, height: size.height + sy * translation.height),
                           step: step, minimum: minimum, maximum: maximum)
        return (CGPoint(x: center.x + sx * (next.width - size.width) / 2, y: center.y + sy * (next.height - size.height) / 2), next)
    }
    /// Hit square of a corner handle, diagonally outside the corner so it ends at the top/bottom edge - clear of the
    /// 28pt pin squares - and stays 32pt on screen: below 100 % zoom the logical square grows by 1/scale.
    static func handleRect(body: CGRect, sx: CGFloat, sy: CGFloat, scale: CGFloat) -> CGRect {
        let k = max(1, 1 / scale)
        let center = CGPoint(x: (sx < 0 ? body.minX : body.maxX) + sx * 12 * k, y: (sy < 0 ? body.minY : body.maxY) + sy * 16 * k)
        return CGRect(x: center.x - 16 * k, y: center.y - 16 * k, width: 32 * k, height: 32 * k)
    }
}
/// Curated SF Symbols the user can pick for a block, grouped for the icon picker. Anyone editing this: keep the
/// symbol names valid SF Symbols (the picker renders them with Image(systemName:)).
enum BlockIcon {
    static let categories: [(name: String, icons: [String])] = [
        ("基板・部品", ["cpu","memorychip","antenna.radiowaves.left.and.right","wifi","network",
                    "sensor.tag.radiowaves.forward","bolt.fill","bolt.batteryblock","speaker.wave.2.fill"]),
        ("通信・接続", ["arrow.left.and.right","arrow.triangle.branch","point.3.connected.trianglepath.dotted","cable.connector"]),
        ("筐体・機構", ["shippingbox","cube","gearshape.fill","fan.fill","thermometer"]),
        ("表示・操作", ["display","switch.2","slider.horizontal.3","lightbulb.fill"]),
        ("汎用図形", ["square.dashed","circle.dashed","triangle","hexagon","diamond"])
    ]
    static let all: [String] = categories.flatMap(\.icons)
}
/// Resizing of block-diagram symbols: the height is a multiple of 30pt (one left/right pin slot per 30pt,
/// so a pin can always be added without overflowing) and the width moves in 30pt steps.
enum BlockSize {
    static let step: CGFloat = 30
    static let minimum = CGSize(width:90,height:30)
    static let maximum = CGSize(width:300,height:180)
    static let standard = CGSize(width:90,height:30)
    static func snapped(_ proposed: CGSize) -> CGSize { ResizableGeometry.snapped(proposed, step:step, minimum:minimum, maximum:maximum) }
    static func handleRect(body: CGRect, sx: CGFloat, sy: CGFloat, scale: CGFloat) -> CGRect {
        ResizableGeometry.handleRect(body:body, sx:sx, sy:sy, scale:scale)
    }
    static func resized(center: CGPoint, size: CGSize, sx: CGFloat, sy: CGFloat, translation: CGSize) -> (center: CGPoint, size: CGSize) {
        ResizableGeometry.resized(center:center, size:size, sx:sx, sy:sy, translation:translation, step:step, minimum:minimum, maximum:maximum)
    }
}

enum SymbolKind: String, CaseIterable, Identifiable {
    case dc = "直流電源", battery = "電池", ac = "交流電源", vcc = "VCC", ground = "GND"
    case resistor = "抵抗", variableResistor = "可変抵抗", capacitor = "コンデンサ"
    case polarizedCapacitor = "電解コンデンサ", inductor = "コイル"
    case diode = "ダイオード", led = "LED", zener = "ツェナーダイオード", photodiode = "フォトダイオード"
    case switchOpen = "スイッチ", pushButton = "押しボタン", fuse = "ヒューズ"
    case lamp = "ランプ", motor = "モーター", speaker = "スピーカー", crystal = "水晶振動子"
    case voltmeter = "電圧計", ammeter = "電流計"
    case npn = "NPNトランジスタ", pnp = "PNPトランジスタ", nmos = "NチャネルMOSFET", pmos = "PチャネルMOSFET", opAmp = "オペアンプ"
    case andGate = "ANDゲート", orGate = "ORゲート", nandGate = "NANDゲート", norGate = "NORゲート", xorGate = "XORゲート", notGate = "NOTゲート"
    case relay = "リレー", connector = "コネクタ"
    case block = "汎用ブロック"
    var id: Self { self }
    var category: SymbolCategory {
        switch self {
        case .dc, .battery, .ac, .vcc, .ground: .power
        case .resistor, .variableResistor, .capacitor, .polarizedCapacitor, .inductor: .passive
        case .diode, .led, .zener, .photodiode, .npn, .pnp, .nmos, .pmos, .opAmp: .semiconductor
        case .andGate, .orGate, .nandGate, .norGate, .xorGate, .notGate: .logic
        case .relay, .connector: .relayConnector
        case .switchOpen, .pushButton, .fuse: .protection
        case .lamp, .motor, .speaker, .crystal, .voltmeter, .ammeter: .load
        default: .block
        }
    }
    var isBlock: Bool { category == .block }
    /// Terminal layout in the unrotated frame (origin at the symbol centre, y down).
    /// `direction` is the outward direction of the lead before rotation.
    struct Pin { let name: String; let offset: CGPoint; let direction: WireRouting.Direction }
    private static func pin(_ name: String, _ x: CGFloat, _ y: CGFloat, _ direction: WireRouting.Direction) -> Pin {
        Pin(name: name, offset: CGPoint(x: x, y: y), direction: direction)
    }
    var pinSpecs: [Pin] {
        switch self {
        case .block:
            [Self.pin("左ピン",-45,0,.left), Self.pin("右ピン",45,0,.right)]
        case .ground, .vcc:
            [Self.pin("左ピン",-30,0,.left)]
        case .npn, .pnp:
            [Self.pin("B（ベース）",-30,0,.left), Self.pin("C（コレクタ）",15,-30,.up), Self.pin("E（エミッタ）",15,30,.down)]
        case .nmos, .pmos:
            [Self.pin("G（ゲート）",-30,0,.left), Self.pin("D（ドレイン）",15,-30,.up), Self.pin("S（ソース）",15,30,.down)]
        case .opAmp:
            [Self.pin("IN+（非反転入力）",-30,-15,.left), Self.pin("IN−（反転入力）",-30,15,.left), Self.pin("OUT（出力）",30,0,.right)]
        case .andGate, .orGate, .nandGate, .norGate, .xorGate:
            [Self.pin("IN1（入力1）",-30,-15,.left), Self.pin("IN2（入力2）",-30,15,.left), Self.pin("OUT（出力）",30,0,.right)]
        case .notGate:
            [Self.pin("IN（入力）",-30,0,.left), Self.pin("OUT（出力）",30,0,.right)]
        case .relay:
            [Self.pin("コイルA",-15,-30,.up), Self.pin("コイルB",-15,30,.down), Self.pin("COM（共通）",15,-30,.up), Self.pin("NO（常開）",15,30,.down)]
        case .connector:
            [Self.pin("P1",-30,-45,.left), Self.pin("P2",-30,-15,.left), Self.pin("P3",-30,15,.left), Self.pin("P4",-30,45,.left)]
        default:
            [Self.pin("左ピン",-30,0,.left), Self.pin("右ピン",30,0,.right)]
        }
    }
    var pinCount: Int { pinSpecs.count }
    var defaultRotation: Int { self == .vcc ? 270 : category == .power ? 90 : 0 }
    /// Coordinate space the vector shape is drawn in (see `CircuitSymbolShape`).
    var designSize: CGSize {
        switch self {
        case .npn, .pnp, .nmos, .pmos, .opAmp, .andGate, .orGate, .nandGate, .norGate, .xorGate, .notGate, .relay:
            CGSize(width:100,height:100)
        case .connector: CGSize(width:100,height:200)
        case .block: CGSize(width:90,height:30)
        default: CGSize(width:100,height:50)
        }
    }
    /// Size of the unrotated body / vector frame. Wires keep out of this rectangle.
    /// Circuit symbols are the design space at 60 % (30 × 30 body, 15 pt leads); blocks are 90 × 30.
    var frameSize: CGSize {
        switch self {
        case .npn, .pnp, .nmos, .pmos, .opAmp, .andGate, .orGate, .nandGate, .norGate, .xorGate, .notGate, .relay:
            CGSize(width:60,height:60)
        case .connector: CGSize(width:60,height:120)
        case .block: CGSize(width:90,height:30)
        default: CGSize(width:60,height:30)
        }
    }
    /// Circuit symbols use the two-terminal vector axis (y=25 of a 100 × 50 design frame).
    var usesAxisLeads: Bool { designSize.height == 50 }
    /// Scale for the library icon so every frame fits in 70 × 50.
    var libraryScale: CGFloat {
        let vertical = defaultRotation % 180 != 0
        let width = vertical ? frameSize.height : frameSize.width
        let height = vertical ? frameSize.width : frameSize.height
        return min(1, 70 / width, 50 / height)
    }
    private func rotated(_ point: CGPoint, by angle: Int) -> CGPoint {
        switch angle {
        case 90: CGPoint(x: -point.y, y: point.x)
        case 180: CGPoint(x: -point.x, y: -point.y)
        case 270: CGPoint(x: point.y, y: -point.x)
        default: point
        }
    }
    /// Where a wire end goes when a symbol's pins move from `old` to `new`: the pin it sat on
    /// (matched once, against the *old* positions), or nil if it was not on any of them.
    /// Matching once matters: a new position may coincide with another old pin
    /// (e.g. a connector moved by exactly one pin pitch).
    static func remapped(_ point: CGPoint, from old: [CGPoint], to new: [CGPoint]) -> CGPoint? {
        guard let index = old.firstIndex(where: { hypot($0.x-point.x,$0.y-point.y) < 1 }) else { return nil }
        return new[index]
    }
    /// One of a block's pins: which edge, and which 30pt-tall row (0 = the top row). A block's own pin list is
    /// per-instance (SymbolItem.blockPins), not per-kind like `pinSpecs` - a block can grow pins one at a time.
    struct BlockPin: Hashable {
        enum Side { case left, right }
        var side: Side
        var slot: Int
        var direction: WireRouting.Direction { side == .left ? .left : .right }
    }
    /// The two pins every new block starts with: left and right, both in the top row.
    static let defaultBlockPins: [BlockPin] = [.init(side:.left,slot:0), .init(side:.right,slot:0)]
    /// Every (side, slot) a block of this height could hold a pin at - one slot per 30pt row, per edge.
    static func blockPinSlots(height: CGFloat) -> [BlockPin] {
        let rows = max(1, Int((height / 30).rounded()))
        return (0..<rows).flatMap { slot in [BlockPin(side:.left,slot:slot), BlockPin(side:.right,slot:slot)] }
    }
    private static func blockPinOffset(_ pin: BlockPin, size: CGSize) -> CGPoint {
        CGPoint(x: pin.side == .left ? -size.width/2 : size.width/2, y: -size.height/2 + 15 + CGFloat(pin.slot)*30)
    }
    /// Pin positions relative to the centre. `blockPins` is required for a block (defaults to the standard two,
    /// top row) and ignored for a circuit symbol, which always uses its fixed `pinSpecs`.
    private func offsets(rotation angle: Int, blockSize: CGSize?, blockPins: [BlockPin]?) -> [CGPoint] {
        if isBlock {
            let size = blockSize ?? frameSize
            return (blockPins ?? Self.defaultBlockPins).map { Self.blockPinOffset($0, size: size) }
        }
        return pinSpecs.map { rotated($0.offset,by:angle) }
    }
    func pins(at position: CGPoint, rotation: Int? = nil, size: CGSize? = nil, blockPins: [BlockPin]? = nil) -> [CGPoint] {
        let angle = isBlock ? 0 : (rotation ?? defaultRotation)
        return offsets(rotation:angle,blockSize:size,blockPins:blockPins).map { CGPoint(x: position.x + $0.x, y: position.y + $0.y) }
    }
    func body(at position: CGPoint, rotation: Int, size: CGSize? = nil) -> CGRect {
        let vertical = !isBlock && rotation % 180 != 0
        let frame = isBlock ? (size ?? frameSize) : frameSize
        let box = vertical ? CGSize(width: frame.height, height: frame.width) : frame
        return CGRect(x:position.x-box.width/2,y:position.y-box.height/2,width:box.width,height:box.height)
    }
    func direction(for pin: Int, rotation: Int, blockPins: [BlockPin]? = nil) -> WireRouting.Direction {
        if isBlock { return (blockPins ?? Self.defaultBlockPins)[pin].direction }
        return WireRouting.Direction(rawValue: (pinSpecs[pin].direction.rawValue + rotation/90) % 4)!
    }
    var letter: String? {
        switch self { case .motor: "M"; case .voltmeter: "V"; case .ammeter: "A"; default: nil }
    }
    /// Default icon for a newly placed generic block; the user can change it afterwards (SymbolItem.icon).
    var icon: String { "square.dashed" }
}

/// Vector construction space is the kind's `designSize`; the view scales it to `frameSize`.
/// Two-terminal symbols: 100 × 50 with the terminal axis at y=25; the body is a 50 × 50 square
/// at x=25...75 and the leads reach the pins at x=0 / x=100.
/// Multi-terminal symbols: 100 × 100 (connector 100 × 200); every pin lies on the frame edge.
struct CircuitSymbolShape: Shape {
    let kind: SymbolKind
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var leftEnd: CGFloat = 25, rightEnd: CGFloat = 75
        func line(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            p.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { p.addLine(to: CGPoint(x: point.0, y: point.1)) }
        }
        func bar(_ x: CGFloat, _ half: CGFloat) { line([(x,25-half),(x,25+half)]) }
        func circle() { p.addEllipse(in: CGRect(x:25,y:0,width:50,height:50)) }
        func arrow(_ a: CGPoint, _ b: CGPoint, head: CGFloat = 4) {
            line([(a.x,a.y),(b.x,b.y)])
            let angle = atan2(b.y-a.y,b.x-a.x)
            line([(b.x-head*cos(angle-0.5),b.y-head*sin(angle-0.5)),(b.x,b.y),
                  (b.x-head*cos(angle+0.5),b.y-head*sin(angle+0.5))])
        }
        func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) { p.addEllipse(in: CGRect(x:x-r,y:y-r,width:2*r,height:2*r)) }
        /// Logic gates share the input leads (x=0 → `inX`) and the output lead (`outX` → 100).
        func gate(inX: CGFloat, outX: CGFloat) {
            line([(0,25),(inX,25)]); line([(0,75),(inX,75)]); line([(outX,50),(100,50)])
        }
        func orBody(left: CGFloat, tip: CGFloat) {
            p.move(to: CGPoint(x:left,y:20))
            p.addQuadCurve(to: CGPoint(x:tip,y:50), control: CGPoint(x:tip-25,y:20))
            p.addQuadCurve(to: CGPoint(x:left,y:80), control: CGPoint(x:tip-25,y:80))
            p.addQuadCurve(to: CGPoint(x:left,y:20), control: CGPoint(x:left+20,y:50))
        }
        switch kind {
        case .dc:
            leftEnd = 42; rightEnd = 58; bar(42,18); bar(58,9)
        case .battery:
            leftEnd = 34; rightEnd = 66
            bar(34,18); bar(42,9); bar(58,18); bar(66,9); line([(42,25),(58,25)])
        case .ac:
            circle()
            p.move(to: CGPoint(x:36,y:25))
            p.addCurve(to: CGPoint(x:50,y:25), control1: CGPoint(x:40,y:11), control2: CGPoint(x:46,y:11))
            p.addCurve(to: CGPoint(x:64,y:25), control1: CGPoint(x:54,y:39), control2: CGPoint(x:60,y:39))
        case .vcc:
            leftEnd = 60; bar(60,16)
        case .ground:
            leftEnd = 35; bar(35,20); bar(47,13); bar(59,6)
        case .resistor, .variableResistor:
            line([(25,25),(31,11),(40,39),(50,11),(60,39),(69,11),(75,25)])
            if kind == .variableResistor { arrow(CGPoint(x:32,y:44),CGPoint(x:68,y:6)) }
        case .capacitor, .polarizedCapacitor:
            leftEnd = 43; rightEnd = 57; bar(43,15); bar(57,15)
        case .inductor:
            p.move(to: CGPoint(x:25,y:25))
            for i in 0..<4 {
                let x = 25 + CGFloat(i) * 12.5
                p.addCurve(to: CGPoint(x:x+12.5,y:25),control1: CGPoint(x:x,y:5),control2: CGPoint(x:x+12.5,y:5))
            }
        case .diode, .led, .zener, .photodiode:
            leftEnd = 30; rightEnd = 70
            line([(30,10),(30,40),(70,25),(30,10)])
            if kind == .zener { line([(76,40),(70,40),(70,10),(64,10)]) } else { bar(70,15) }
            if kind == .led || kind == .photodiode {
                for x: CGFloat in [44,54] {
                    let near = CGPoint(x:x,y:11), far = CGPoint(x:x+7,y:1)
                    arrow(kind == .led ? near : far, kind == .led ? far : near)
                }
            }
        case .switchOpen, .pushButton:
            p.addEllipse(in: CGRect(x:25,y:22,width:6,height:6))
            p.addEllipse(in: CGRect(x:69,y:22,width:6,height:6))
            if kind == .switchOpen { line([(30,24),(70,8)]) }
            else { line([(30,17),(70,17)]); line([(50,17),(50,7)]); line([(40,7),(60,7)]) }
        case .fuse:
            p.addRect(CGRect(x:25,y:17,width:50,height:16)); line([(25,25),(75,25)])
        case .lamp:
            circle(); line([(36,11),(64,39)]); line([(36,39),(64,11)])
        case .motor, .voltmeter, .ammeter:
            circle()
        case .speaker:
            p.addRect(CGRect(x:25,y:17,width:14,height:16))
            line([(39,17),(75,4),(75,46),(39,33)])
        case .crystal:
            bar(25,15); bar(75,15); p.addRect(CGRect(x:37,y:12,width:26,height:26))
        case .npn, .pnp:
            line([(0,50),(45,50)]); line([(45,30),(45,70)])
            p.addEllipse(in: CGRect(x:28,y:20,width:60,height:60))
            line([(75,0),(75,20),(45,38)])
            line([(75,100),(75,80),(45,62)])
            let base = CGPoint(x:48,y:64), tip = CGPoint(x:68,y:77)
            if kind == .npn { arrow(base, tip, head: 7) } else { arrow(tip, base, head: 7) }
        case .nmos, .pmos:
            line([(0,50),(35,50)]); line([(35,30),(35,70)])
            for range in [(28.0,40.0),(44.0,56.0),(60.0,72.0)] { line([(45,range.0),(45,range.1)]) }
            line([(75,0),(75,34),(45,34)]); line([(75,100),(75,66),(45,66)]); line([(75,66),(75,50)])
            if kind == .nmos { arrow(CGPoint(x:75,y:50), CGPoint(x:47,y:50), head: 6) }
            else { arrow(CGPoint(x:47,y:50), CGPoint(x:75,y:50), head: 6) }
        case .opAmp:
            line([(25,5),(25,95),(85,50),(25,5)])
            line([(0,25),(25,25)]); line([(0,75),(25,75)]); line([(85,50),(100,50)])
        case .andGate, .nandGate:
            let bubble = kind == .nandGate
            gate(inX: 30, outX: bubble ? 88 : 80)
            p.move(to: CGPoint(x:30,y:20)); p.addLine(to: CGPoint(x:50,y:20))
            p.addArc(center: CGPoint(x:50,y:50), radius: 30, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x:30,y:80)); p.closeSubpath()
            if bubble { dot(84,50,4) }
        case .orGate, .norGate, .xorGate:
            let bubble = kind == .norGate
            let left: CGFloat = kind == .xorGate ? 31 : 25
            gate(inX: left + 3, outX: bubble ? 88 : 85)
            orBody(left: left, tip: bubble ? 80 : 85)
            if bubble { dot(84,50,4) }
            if kind == .xorGate {
                p.move(to: CGPoint(x:19,y:20)); p.addQuadCurve(to: CGPoint(x:19,y:80), control: CGPoint(x:39,y:50))
                line([(0,25),(22,25)]); line([(0,75),(22,75)])
            }
        case .notGate:
            line([(25,25),(25,75),(75,50),(25,25)]); dot(79,50,4)
            line([(0,50),(25,50)]); line([(83,50),(100,50)])
        case .relay:
            p.addRect(CGRect(x:13,y:30,width:24,height:40))
            line([(25,0),(25,30)]); line([(25,70),(25,100)])
            line([(75,0),(75,28),(66,64)]); line([(75,100),(75,74)]); dot(75,71,3)
            line([(41,50),(47,50)]); line([(52,50),(58,50)])
        case .connector:
            p.addRect(CGRect(x:40,y:5,width:30,height:190))
            for y: CGFloat in [25,75,125,175] { line([(0,y),(40,y)]); dot(55,y,4) }
        default: break
        }
        if kind.usesAxisLeads {
            line([(0,25),(leftEnd,25)])
            if kind.pinCount == 2 { line([(rightEnd,25),(100,25)]) }
        }
        let frame = kind.designSize
        return p.applying(CGAffineTransform(scaleX: rect.width/frame.width, y: rect.height/frame.height)
            .concatenating(CGAffineTransform(translationX: rect.minX,y: rect.minY)))
    }
}

/// Text is drawn separately so the internal letter and polarity marks stay upright.
struct CircuitGlyph: View {
    let kind: SymbolKind
    let rotation: Int
    private func marker(_ text: String, _ dx: CGFloat, _ dy: CGFloat) -> some View {
        let radians = Double(rotation) * .pi / 180
        let x = dx * 0.6, y = dy * 0.6
        return Text(text).font(.system(size:7,weight:.bold))
            .offset(x:x*cos(radians)-y*sin(radians), y:x*sin(radians)+y*cos(radians))
    }
    var body: some View {
        ZStack {
            CircuitSymbolShape(kind: kind).stroke(.primary, lineWidth: 1.5)
                .frame(width:kind.frameSize.width,height:kind.frameSize.height)
                .rotationEffect(.degrees(Double(rotation)))
            switch kind {
            case .polarizedCapacitor: marker("+",-15,-15)
            case .dc: marker("+",-17,-14); marker("−",17,-12)
            case .battery: marker("+",-25,-14); marker("−",25,-12)
            case .opAmp: marker("+",-15,-25); marker("−",-15,25)
            default: EmptyView()
            }
            if let letter = kind.letter { Text(letter).font(.system(size:10,weight:.medium)) }
        }
        .frame(width:rotation % 180 == 0 ? kind.frameSize.width : kind.frameSize.height,
               height:rotation % 180 == 0 ? kind.frameSize.height : kind.frameSize.width)
    }
}
