import SwiftUI

struct OverviewHeader: View {
    let count: Int
    let updatedAt: Date?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("模型全景").font(.title2.bold()).foregroundStyle(ink)
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
            }
        }.padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)
    }

}
