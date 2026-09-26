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
    func pins(at position: CGPoint) -> [CGPoint] {
        (0..<pinCount).map { CGPoint(x: position.x + ($0 == 0 ? -75 : 75), y: position.y) }
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

/// Canonical 150 × 64 geometry; previews and canvas use the same vector paths.
/// The terminal axis is y=32. Text lives below it, without shifting the pins.
struct CircuitSymbolShape: Shape {
    let kind: SymbolKind
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func line(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            p.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { p.addLine(to: CGPoint(x: point.0, y: point.1)) }
        }
        func bar(_ x: CGFloat, _ half: CGFloat) { line([(x,32-half),(x,32+half)]) }
        func leads(_ left: CGFloat, _ right: CGFloat) { line([(0,32),(left,32)]); line([(right,32),(150,32)]) }
        func circle() { p.addEllipse(in: CGRect(x:55,y:12,width:40,height:40)); leads(55,95) }
        func plus(_ x: CGFloat, _ y: CGFloat) { line([(x-3,y),(x+3,y)]); line([(x,y-3),(x,y+3)]) }
        func arrow(_ a: CGPoint, _ b: CGPoint) {
            line([(a.x,a.y),(b.x,b.y)])
            let angle = atan2(b.y-a.y,b.x-a.x)
            line([(b.x-6*cos(angle-0.5),b.y-6*sin(angle-0.5)),(b.x,b.y),
                  (b.x-6*cos(angle+0.5),b.y-6*sin(angle+0.5))])
        }
        switch kind {
        case .dc:
            leads(69,81); bar(69,19); bar(81,10); plus(58,13); line([(88,13),(94,13)])
        case .battery:
            leads(57,93)
            for x: CGFloat in [57,81] { bar(x,19); bar(x+12,10) }
            line([(69,32),(81,32)]); plus(47,13); line([(100,13),(106,13)])
        case .ac:
            circle()
            p.move(to: CGPoint(x:61,y:32))
            p.addCurve(to: CGPoint(x:75,y:32), control1: CGPoint(x:65,y:16), control2: CGPoint(x:71,y:16))
            p.addCurve(to: CGPoint(x:89,y:32), control1: CGPoint(x:79,y:48), control2: CGPoint(x:85,y:48))
        case .vcc:
            line([(0,32),(88,32)]); bar(88,18)
        case .ground:
            line([(0,32),(70,32)]); bar(70,21); bar(80,14); bar(90,7)
        case .resistor, .variableResistor:
            leads(49,101)
            line([(49,32),(54,22),(62,42),(70,22),(78,42),(86,22),(94,42),(101,32)])
            if kind == .variableResistor { arrow(CGPoint(x:55,y:50),CGPoint(x:94,y:8)) }
        case .capacitor, .polarizedCapacitor:
            leads(69,81); bar(69,20); bar(81,20)
            if kind == .polarizedCapacitor { plus(58,12) }
        case .inductor:
            leads(47,103)
            p.move(to: CGPoint(x:47,y:32))
            for x: CGFloat in [47,61,75,89] {
                p.addCurve(to: CGPoint(x:x+14,y:32),control1: CGPoint(x:x,y:10),control2: CGPoint(x:x+14,y:10))
            }
        case .diode, .led, .zener, .photodiode:
            leads(59,87)
            line([(59,16),(87,32),(59,48),(59,16)])
            if kind == .zener { line([(81,12),(87,16),(87,48),(93,52)]) }
            else { bar(87,16) }
            if kind == .led || kind == .photodiode {
                for x: CGFloat in [81,94] {
                    let near = CGPoint(x:x,y:18), far = CGPoint(x:x+13,y:3)
                    arrow(kind == .led ? near : far, kind == .led ? far : near)
                }
            }
        case .switchOpen, .pushButton:
            leads(53,97)
            p.addEllipse(in: CGRect(x:50,y:29,width:6,height:6))
            p.addEllipse(in: CGRect(x:94,y:29,width:6,height:6))
            if kind == .switchOpen { line([(53,29),(92,12)]) }
            else { line([(53,22),(97,22)]); line([(75,22),(75,9)]); line([(65,9),(85,9)]) }
        case .fuse:
            leads(51,99); p.addRect(CGRect(x:51,y:24,width:48,height:16)); line([(51,32),(99,32)])
        case .lamp:
            circle(); line([(61,18),(89,46)]); line([(61,46),(89,18)])
        case .motor:
            circle(); line([(64,43),(64,22),(75,34),(86,22),(86,43)])
        case .voltmeter:
            circle(); line([(64,22),(75,43),(86,22)])
        case .ammeter:
            circle(); line([(64,43),(75,21),(86,43)]); line([(69,34),(81,34)])
        case .speaker:
            leads(53,97); p.addRect(CGRect(x:53,y:23,width:16,height:18))
            line([(69,23),(97,12),(97,52),(69,41)])
        case .crystal:
            leads(51,99); bar(51,18); bar(99,18); p.addRect(CGRect(x:61,y:15,width:28,height:34))
        default: break
        }
        return p.applying(CGAffineTransform(scaleX: rect.width/150, y: rect.height/64)
            .concatenating(CGAffineTransform(translationX: rect.minX,y: rect.minY)))
    }
}
