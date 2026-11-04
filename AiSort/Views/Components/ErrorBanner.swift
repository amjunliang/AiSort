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
