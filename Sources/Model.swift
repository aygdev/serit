import AppKit
import SwiftUI

struct RGB: Equatable {
    var r: Double, g: Double, b: Double

    static let black = RGB(r: 0, g: 0, b: 0)

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    init(_ r: Int, _ g: Int, _ b: Int) { self.init(r: Double(r) / 255, g: Double(g) / 255, b: Double(b) / 255) }

    static func hsv(_ h: Double, _ s: Double, _ v: Double) -> RGB {
        let h = (h.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let i = Int(h), f = h - Double(i)
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch i {
        case 0: return RGB(r: v, g: t, b: p)
        case 1: return RGB(r: q, g: v, b: p)
        case 2: return RGB(r: p, g: v, b: t)
        case 3: return RGB(r: p, g: q, b: v)
        case 4: return RGB(r: t, g: p, b: v)
        default: return RGB(r: v, g: p, b: q)
        }
    }

    func mix(_ o: RGB, _ t: Double) -> RGB {
        RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    func distance(_ o: RGB) -> Double { max(abs(r - o.r), abs(g - o.g), abs(b - o.b)) }

    /// Şeride giden bayt. Hafif gama: LED'in parlaklığı göze doğrusal gelmiyor, gamasız ara renkler soluk duruyor.
    var ledBytes: (UInt8, UInt8, UInt8) {
        func c(_ x: Double) -> UInt8 { UInt8((pow(min(max(x, 0), 1), 1.8) * 255).rounded()) }
        return (c(r), c(g), c(b))
    }

    var color: Color { Color(red: r, green: g, blue: b) }
    var nsColor: NSColor { NSColor(red: r, green: g, blue: b, alpha: 1) }
}

/// Döngüsel palet örnekleme, renkler arası yumuşak (smoothstep) geçişle.
func sample(_ colors: [RGB], _ x: Double) -> RGB {
    let n = Double(colors.count)
    let p = ((x.truncatingRemainder(dividingBy: 1)) + 1).truncatingRemainder(dividingBy: 1) * n
    let i = Int(p) % colors.count, f = p - floor(p)
    return colors[i].mix(colors[(i + 1) % colors.count], f * f * (3 - 2 * f))
}

/// Efekt sekmesindeki kartlar: şeridin kendi (çipte dönen, akıcı) modlarından seçilenler.
/// color(t) sadece paneldeki önizleme içindir, şeride gitmez.
enum EffectKind: String, CaseIterable, Identifiable {
    case gokkusagi, ates, gunbatimi, okyanus, neon, bahar, su, dalga, kuyruk, kosu, sihir, parti

    var id: String { rawValue }

    /// Çipteki mod numarası (APK modes_group*_command).
    var mode: Int {
        switch self {
        case .gokkusagi: 199
        case .ates: 200
        case .gunbatimi: 201
        case .okyanus: 202
        case .bahar: 203
        case .neon: 204
        case .su: 39
        case .dalga: 83
        case .kuyruk: 23
        case .kosu: 103
        case .sihir: 1
        case .parti: 196
        }
    }

    static func forMode(_ m: Int) -> EffectKind? { allCases.first { $0.mode == m } }

    var title: String {
        switch self {
        case .gokkusagi: "Gökkuşağı"
        case .ates: "Ateş"
        case .gunbatimi: "Gün batımı"
        case .okyanus: "Okyanus"
        case .neon: "Neon"
        case .bahar: "Bahar"
        case .su: "Su"
        case .dalga: "Dalga"
        case .kuyruk: "Kuyruklu yıldız"
        case .kosu: "Koşu"
        case .sihir: "Sihir"
        case .parti: "Parti"
        }
    }

    var subtitle: String {
        switch self {
        case .gokkusagi: "Yumuşak 7 renk"
        case .ates: "Kırmızı ↔ sarı"
        case .gunbatimi: "Kırmızı ↔ mor"
        case .okyanus: "Yeşil ↔ turkuaz"
        case .neon: "Mavi ↔ mor"
        case .bahar: "Yeşil ↔ sarı"
        case .su: "Akan renkler"
        case .dalga: "7 renk dalga"
        case .kuyruk: "Kayan ışık"
        case .kosu: "Koşan noktalar"
        case .sihir: "Sihirli ileri"
        case .parti: "7 renk flaş"
        }
    }

    var symbol: String {
        switch self {
        case .gokkusagi: "rainbow"
        case .ates: "flame.fill"
        case .gunbatimi: "sun.horizon.fill"
        case .okyanus: "water.waves"
        case .neon: "bolt.fill"
        case .bahar: "leaf.fill"
        case .su: "drop.fill"
        case .dalga: "wave.3.right"
        case .kuyruk: "sparkle"
        case .kosu: "figure.run"
        case .sihir: "wand.and.stars"
        case .parti: "party.popper.fill"
        }
    }

    /// Önizleme rengi; t saniye (hızla ölçeklenmiş).
    func color(_ t: Double) -> RGB {
        func swing(_ a: RGB, _ b: RGB, _ period: Double) -> RGB { a.mix(b, 0.5 - 0.5 * cos(t * 2 * .pi / period)) }
        switch self {
        case .gokkusagi: return .hsv(t / 10, 1, 1)
        case .ates: return swing(RGB(255, 0, 0), RGB(255, 210, 0), 4)
        case .gunbatimi: return swing(RGB(255, 0, 0), RGB(170, 0, 255), 4)
        case .okyanus: return swing(RGB(0, 255, 60), RGB(0, 230, 255), 4)
        case .neon: return swing(RGB(0, 60, 255), RGB(200, 0, 255), 4)
        case .bahar: return swing(RGB(40, 255, 0), RGB(255, 230, 0), 4)
        case .su: return sample([RGB(0, 120, 255), RGB(0, 255, 200), RGB(120, 0, 255)], t / 5)
        case .dalga: return .hsv(t / 4, 1, 0.55 + 0.45 * abs(sin(t * 2)))
        case .kuyruk: return .hsv(t / 6, 1, 0.3 + 0.7 * pow(1 - (t * 0.8).truncatingRemainder(dividingBy: 1), 2))
        case .kosu: return .hsv(floor(t * 1.5) / 7, 1, 1)
        case .sihir: return sample([RGB(255, 0, 120), RGB(0, 180, 255), RGB(255, 200, 0)], t / 3)
        case .parti: return .hsv(floor(t * 4) / 7, 1, (t * 4).truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.1)
        }
    }
}

struct Preset: Identifiable {
    let id: Int
    let h: Double, s: Double
    var rgb: RGB { .hsv(h, s, 1) }

    static let all: [Preset] = [
        Preset(id: 0, h: 0.0, s: 1), Preset(id: 1, h: 0.07, s: 1), Preset(id: 2, h: 0.12, s: 1),
        Preset(id: 3, h: 0.33, s: 1), Preset(id: 4, h: 0.48, s: 1), Preset(id: 5, h: 0.62, s: 1),
        Preset(id: 6, h: 0.76, s: 1), Preset(id: 7, h: 0.9, s: 0.85), Preset(id: 8, h: 0.08, s: 0.35),
    ]
}
