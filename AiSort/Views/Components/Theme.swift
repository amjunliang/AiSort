import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var title: LocalizedStringKey {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

nonisolated let ink = Color("Ink")
/// Brand color, reserved for the app logo.
let tealFill = Color("TealFill")
let appBackground = Color("AppBackground")
let appSurface = Color("AppSurface")
let warningText = Color("WarningText")
private let palette: [UInt32] = [0x217D75, 0xE07A4D, 0x5E78B5, 0xBA9445, 0x9C6691, 0x599CA8, 0xA87A63, 0x8A995C]

extension Font {
    static var appBody: Font { .system(size: 14) }
    static var appSubheadline: Font { .system(size: 15) }
    static var appCaption: Font { .system(size: 14) }
    static var appCaption2: Font { .system(size: 14) }
}

private struct RGB {
    var r: Double, g: Double, b: Double

    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    var color: Color { Color(red: r, green: g, blue: b) }

    /// WCAG relative luminance.
    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    func mixed(with other: RGB, by t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    /// Smallest mix toward `target` that brings luminance into the requested range.
    func adjusted(toward target: RGB, until satisfied: (Double) -> Bool, limit: Double) -> RGB {
        var t = 0.0
        var result = self
        while !satisfied(result.luminance), t < limit {
            t += 0.02
            result = mixed(with: target, by: t)
        }
        return result
    }
}

/// Hand-tuned tones for the most common vendors so they stay recognizable,
/// clearly distinct from each other and readable on both backgrounds.
private let tunedCreatorColors: [String: (light: UInt32, dark: UInt32)] = [
    "anthropic": (0xC15F3C, 0xE8946F),
    "google": (0x1E8E3E, 0x5BC97D),
    "openai": (0x3A4250, 0xB8C2D1),
    "deepseek": (0x2E54E8, 0x7D97FF),
    "meta": (0x0A7FE0, 0x5AB0FF),
    "xai": (0x6A5FD0, 0xA59BFF),
    "spacexai": (0x6A5FD0, 0xA59BFF),
    "alibaba": (0xE0640F, 0xFF9A52),
    "mistral": (0xE0420F, 0xFF7A52),
    "minimax": (0xD62E5E, 0xFF7097),
    "moonshot ai": (0x1673E6, 0x63A6FF),
    "kimi": (0x1673E6, 0x63A6FF),
    "z ai": (0x1C74E0, 0x6AA8FF),
    "nvidia": (0x5E9400, 0x9AD13A),
    "xiaomi": (0xEB6100, 0xFF9447)
]

private let rgbWhite = RGB(r: 1, g: 1, b: 1)
private let rgbBlack = RGB(r: 0, g: 0, b: 0)

private func baseCreatorHex(_ name: String) -> UInt32? {
    // Colors observed on Artificial Analysis charts; the API does not provide colors.
    let known: [String: UInt32] = [
        "alibaba": 0xFF7018,
        "anthropic": 0xCC785C,
        "apodex": 0x0FD9D2,
        "china mobile": 0x00B8EA,
        "cohere": 0xD18EE2,
        "deepseek": 0x2243E6,
        "google": 0x34A853,
        "ibm": 0x0F62FE,
        "inclusionai": 0x4FB5FF,
        "institute of foundation models": 0x1521A9,
        "kimi": 0x047AFE,
        "moonshot ai": 0x047AFE,
        "lg ai research": 0xDF3B8A,
        "meta": 0x0089F4,
        "minimax": 0xEB3568,
        "mistral": 0xF32E02,
        "nanbeige": 0x023C3E,
        "nvidia": 0x76B900,
        "openai": 0x1F1F1F,
        "reflection": 0x195428,
        "sapiens ai": 0x1521A9,
        "spacexai": 0x736CD3,
        "xai": 0x736CD3,
        "stepfun": 0x00F5E7,
        "tencent": 0x5CB9FF,
        "thinking machines": 0x676767,
        "upstage": 0x7C59F5,
        "xiaomi": 0xFF6900,
        "z ai": 0x1C7FF8
    ]
    return known[name.lowercased()]
}

func creatorColor(_ name: String, in colorScheme: ColorScheme) -> Color {
    let key = name.lowercased()
    if let tuned = tunedCreatorColors[key] {
        return RGB(hex: colorScheme == .dark ? tuned.dark : tuned.light).color
    }
    let base: RGB
    if let hex = baseCreatorHex(name) {
        base = RGB(hex: hex)
    } else {
        let hash = name.utf8.reduce(0) { ($0 * 31 + Int($1)) % 10007 }
        base = RGB(hex: palette[hash % palette.count])
    }
    // Lift only as much as needed, so saturated brand colors don't wash out on dark,
    // and neon colors (cyan, lime) are deepened enough to read on light backgrounds.
    if colorScheme == .dark {
        return base.adjusted(toward: rgbWhite, until: { $0 >= 0.30 }, limit: 0.7).color
    }
    return base.adjusted(toward: rgbBlack, until: { $0 <= 0.28 }, limit: 0.5).color
}

func number(_ value: Double?, digits: Int = 2) -> String {
    guard let value, value.isFinite else { return "暂无数据" }
    return value.formatted(.number.precision(.fractionLength(0...digits)))
}
func dollars(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "暂无数据" }
    return "$" + value.formatted(.number.precision(.fractionLength(0...4)))
}


extension View {
    func card() -> some View {
        self.padding(18).background(appSurface, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.05)))
    }
}
