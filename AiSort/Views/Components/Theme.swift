import SwiftUI

let ink = Color(red: 0.10, green: 0.16, blue: 0.22)
let teal = Color(red: 0.10, green: 0.43, blue: 0.42)
private let palette: [Color] = [.init(red: 0.13, green: 0.49, blue: 0.46), .init(red: 0.88, green: 0.48, blue: 0.30), .init(red: 0.37, green: 0.47, blue: 0.71), .init(red: 0.73, green: 0.58, blue: 0.27), .init(red: 0.61, green: 0.40, blue: 0.57), .init(red: 0.35, green: 0.61, blue: 0.66), .init(red: 0.66, green: 0.48, blue: 0.39), .init(red: 0.54, green: 0.60, blue: 0.36)]

extension Font {
    static var appBody: Font { .system(size: 14) }
    static var appSubheadline: Font { .system(size: 15) }
    static var appCaption: Font { .system(size: 14) }
    static var appCaption2: Font { .system(size: 14) }
}

func creatorColor(_ name: String) -> Color {
    // Approximate the colors visible on Artificial Analysis; the API does not provide colors.
    let known: [String: Color] = [
        "openai": Color(red: 0.10, green: 0.10, blue: 0.10),
        "anthropic": Color(red: 0.80, green: 0.47, blue: 0.38),
        "google": Color(red: 0.20, green: 0.68, blue: 0.32),
        "deepseek": Color(red: 0.14, green: 0.25, blue: 0.85),
        "meta": Color(red: 0.00, green: 0.52, blue: 0.93),
        "kimi": Color(red: 0.04, green: 0.43, blue: 0.96),
        "moonshot ai": Color(red: 0.04, green: 0.43, blue: 0.96),
        "xai": Color(red: 0.45, green: 0.41, blue: 0.80),
        "spacexai": Color(red: 0.45, green: 0.41, blue: 0.80),
        "z ai": Color(red: 0.13, green: 0.46, blue: 0.91),
        "xiaomi": Color(red: 1.00, green: 0.41, blue: 0.00)
    ]
    if let color = known[name.lowercased()] { return color }
    let hash = name.utf8.reduce(0) { ($0 * 31 + Int($1)) % 10007 }
    return palette[hash % palette.count]
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
        self.padding(18).background(.background, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.05)))
    }
}
