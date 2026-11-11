import SwiftUI

struct OverviewHeader: View {
    let count: Int
    let updatedAt: Date?
    let rateLimit: RateLimit?
    @Binding var showsChinaOnly: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("模型全景").font(.title2.bold()).foregroundStyle(ink)
                    Button {
                        showsChinaOnly.toggle()
                    } label: {
                        Text("只看中国")
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(showsChinaOnly ? .white : teal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(showsChinaOnly ? teal : teal.opacity(0.09), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(showsChinaOnly ? .isSelected : [])
                }
                Text("左上角代表更高智力、更低成本")
                    .font(.appCaption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 5) {
                Text("\(count) 个模型")
                    .font(.appCaption.weight(.semibold)).foregroundStyle(teal)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(teal.opacity(0.09), in: Capsule())
                if let updatedAt = updatedAt {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("更新于 \(updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        Text(updatedAt.formatted(date: .omitted, time: .shortened))
                    }
                    .font(.appCaption2).foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                if let rateLimit {
                    Text(rateLimit.limit.map { "额度 \(rateLimit.remaining)/\($0)" } ?? "额度剩余 \(rateLimit.remaining)")
                        .font(.appCaption2).foregroundStyle(rateLimit.remaining < 10 ? Color.orange : .secondary)
                        .lineLimit(1)
                        .help("Artificial Analysis 免费额度，\(RefreshPolicy.format(rateLimit.resetAt, now: Date())) 重置")
                }
            }
        }.padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)
    }

}
