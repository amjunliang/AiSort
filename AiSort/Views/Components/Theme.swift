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
let teal = Color("Teal")
let tealFill = Color("TealFill")
let appBackground = Color("AppBackground")
let appSurface = Color("AppSurface")
let warningText = Color("WarningText")
private let palette: [Color] = [.init(red: 0.13, green: 0.49, blue: 0.46), .init(red: 0.88, green: 0.48, blue: 0.30), .init(red: 0.37, green: 0.47, blue: 0.71), .init(red: 0.73, green: 0.58, blue: 0.27), .init(red: 0.61, green: 0.40, blue: 0.57), .init(red: 0.35, green: 0.61, blue: 0.66), .init(red: 0.66, green: 0.48, blue: 0.39), .init(red: 0.54, green: 0.60, blue: 0.36)]

extension Font {
    static var appBody: Font { .system(size: 14) }
    static var appSubheadline: Font { .system(size: 15) }
    static var appCaption: Font { .system(size: 14) }
    static var appCaption2: Font { .system(size: 14) }
}

private func hexColor(_ hex: UInt32) -> Color {
    Color(
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255
    )
}

private func baseCreatorColor(_ name: String) -> Color {
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
    if let hex = known[name.lowercased()] { return hexColor(hex) }
    let hash = name.utf8.reduce(0) { ($0 * 31 + Int($1)) % 10007 }
    return palette[hash % palette.count]
}
func creatorColor(_ name: String, in colorScheme: ColorScheme) -> Color {
    let color = baseCreatorColor(name)
    // Keep dark brand colors visible against the chart and sheet backgrounds.
    return colorScheme == .dark ? color.mix(with: .white, by: 0.48) : color
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
