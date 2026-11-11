import SwiftUI

struct ErrorBanner: View {
    let text: String
    let canRetry: Bool
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text).frame(maxWidth: .infinity, alignment: .leading)
            if canRetry {
                Button("重试", action: retry).fontWeight(.semibold)
            }
        }.font(.appCaption).foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.08))
            .padding(12).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 冷却期提示：可关闭，或忽略冷却期仍然更新。
struct RefreshNoticeBanner: View {
    let text: String
    let remaining: String?
    let canUpdate: Bool
    let update: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                Text(text).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: dismiss) {
                    Image(systemName: "xmark").font(.appCaption.weight(.semibold)).frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭提示")
                .help("关闭提示")
            }
            HStack(spacing: 10) {
                if let remaining {
                    Text(remaining).font(.appCaption.weight(.medium)).foregroundStyle(ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("仍然更新", action: update).fontWeight(.semibold).disabled(!canUpdate)
                    .fixedSize()
            }
            .padding(.leading, 26)
        }.font(.appCaption).foregroundStyle(teal)
            .padding(12).background(teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }
}
