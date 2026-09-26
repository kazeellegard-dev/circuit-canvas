import SwiftUI

enum SymbolCategory: String, CaseIterable, Identifiable {
    case power = "電源", passive = "受動部品", semiconductor = "半導体"
    case protection = "スイッチ・保護", load = "負荷・その他", block = "ブロック"
    var id: Self { self }
}

enum SymbolKind: String, CaseIterable, Identifiable {
    case dc = "直流電源", battery = "電池", ac = "交流電源", vcc = "VCC", ground = "GND"
    case resistor = "抵抗", variableResistor = "可変抵抗", capacitor = "コンデンサ"
    case polarizedCapacitor = "電解コンデンサ", inductor = "コイル"
    case diode = "ダイオード", led = "LED", zener = "ツェナーダイオード", photodiode = "フォトダイオード"
    case switchOpen = "スイッチ", pushButton = "押しボタン", fuse = "ヒューズ"
    case lamp = "ランプ", motor = "モーター", speaker = "スピーカー", crystal = "水晶振動子"
    case voltmeter = "電圧計", ammeter = "電流計"
    case converter = "DC/DC", mcu = "MCU", can = "CAN", sensor = "センサー", block = "汎用ブロック"
    var id: Self { self }
    var category: SymbolCategory {
        switch self {
        case .dc, .battery, .ac, .vcc, .ground: .power
        case .resistor, .variableResistor, .capacitor, .polarizedCapacitor, .inductor: .passive
        case .diode, .led, .zener, .photodiode: .semiconductor
        case .switchOpen, .pushButton, .fuse: .protection
        case .lamp, .motor, .speaker, .crystal, .voltmeter, .ammeter: .load
        default: .block
        }
    }
    var isBlock: Bool { category == .block }
    var pinCount: Int { self == .ground || self == .vcc ? 1 : 2 }
    var defaultRotation: Int { self == .vcc ? 270 : category == .power ? 90 : 0 }
    func pins(at position: CGPoint, rotation: Int? = nil) -> [CGPoint] {
        let angle = isBlock ? 0 : (rotation ?? defaultRotation)
        let radius: CGFloat = isBlock ? 75 : 50
        return (0..<pinCount).map { index in
            let d = index == 0 ? -radius : radius
            switch angle {
            case 90: return CGPoint(x: position.x, y: position.y+d)
            case 180: return CGPoint(x: position.x-d, y: position.y)
            case 270: return CGPoint(x: position.x, y: position.y-d)
            default: return CGPoint(x: position.x+d, y: position.y)
            }
        }
    }
    func body(at position: CGPoint, rotation: Int) -> CGRect {
        let vertical = !isBlock && rotation % 180 != 0
        let size = isBlock ? CGSize(width:150,height:64) :
            CGSize(width:vertical ? 50 : 100,height:vertical ? 100 : 50)
        return CGRect(x:position.x-size.width/2,y:position.y-size.height/2,width:size.width,height:size.height)
    }
    func direction(for pin: Int, rotation: Int) -> WireRouting.Direction {
        WireRouting.Direction(rawValue: ((isBlock ? 0 : rotation/90) + pin*2) % 4)!
    }
    var letter: String? {
        switch self { case .motor: "M"; case .voltmeter: "V"; case .ammeter: "A"; default: nil }
    }
    var icon: String {
        switch self {
        case .converter: "bolt.fill"
        case .mcu: "cpu"
        case .can: "arrow.left.and.right"
        case .sensor: "sensor.tag.radiowaves.forward"
        default: "square.dashed"
        }
    }
}

/// Vector construction space: 100 × 50 with the terminal axis at y=25.
/// The body is a 50 × 50 square at x=25...75; the leads reach the pins at x=0 / x=100.
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
        func arrow(_ a: CGPoint, _ b: CGPoint) {
            line([(a.x,a.y),(b.x,b.y)])
            let angle = atan2(b.y-a.y,b.x-a.x)
            line([(b.x-4*cos(angle-0.5),b.y-4*sin(angle-0.5)),(b.x,b.y),
                  (b.x-4*cos(angle+0.5),b.y-4*sin(angle+0.5))])
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
        default: break
        }
        line([(0,25),(leftEnd,25)])
        if kind.pinCount == 2 { line([(rightEnd,25),(100,25)]) }
        return p.applying(CGAffineTransform(scaleX: rect.width/100, y: rect.height/50)
            .concatenating(CGAffineTransform(translationX: rect.minX,y: rect.minY)))
    }
}

/// Text is drawn separately so the internal letter and polarity marks stay upright.
struct CircuitGlyph: View {
    let kind: SymbolKind
    let rotation: Int
    private func marker(_ text: String, _ dx: CGFloat, _ dy: CGFloat) -> some View {
        let radians = Double(rotation) * .pi / 180
        return Text(text).font(.system(size:10,weight:.bold))
            .offset(x:dx*cos(radians)-dy*sin(radians), y:dx*sin(radians)+dy*cos(radians))
    }
    var body: some View {
        ZStack {
            CircuitSymbolShape(kind: kind).stroke(.primary, lineWidth: 2)
                .frame(width:100,height:50)
                .rotationEffect(.degrees(Double(rotation)))
            switch kind {
            case .polarizedCapacitor: marker("+",-15,-15)
            case .dc: marker("+",-17,-14); marker("−",17,-12)
            case .battery: marker("+",-25,-14); marker("−",25,-12)
            default: EmptyView()
            }
            if let letter = kind.letter { Text(letter).font(.system(size:16,weight:.medium)) }
        }
        .frame(width:rotation % 180 == 0 ? 100 : 50,height:rotation % 180 == 0 ? 50 : 100)
    }
}
