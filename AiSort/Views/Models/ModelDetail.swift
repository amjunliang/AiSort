import SwiftUI

struct ModelDetail: View {
    let model: AIModel
    let version: Double?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Circle().fill(creatorColor(model.modelCreator.name)).frame(width: 12, height: 12)
                        Text(model.modelCreator.name).font(.appSubheadline.weight(.medium)).foregroundStyle(.secondary)
                        Text(model.modelCreator.region?.rawValue ?? "未分类")
                            .font(.appCaption.weight(.semibold)).foregroundStyle(teal)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(teal.opacity(0.09), in: Capsule())
                    }
                    Text(model.name).font(.title.bold()).foregroundStyle(ink)
                    VStack(spacing: 0) {
                        metric("智力指数\(version.map { " v\(number($0))" } ?? "")", number(model.intelligence))
                        metric("输出速度", model.speed.map { "\(number($0)) token / 秒" } ?? "暂无数据")
                        metric("混合单价（3:1）", model.cost.map { "\(dollars($0)) / 百万 token" } ?? "暂无数据")
                        metric("输入单价", model.pricing.price1mInputTokens.map { "\(dollars($0)) / 百万 token" } ?? "暂无数据")
                        metric("输出单价", model.pricing.price1mOutputTokens.map { "\(dollars($0)) / 百万 token" } ?? "暂无数据")
                    }.card()
                    Text("混合单价假设输入与输出 token 的比例为 3:1，计算方式为（输入单价 × 3 + 输出单价）÷ 4。它是用于比较的平均单价，实际费用取决于输入和输出 token 的数量。速度为跨供应商的输出速度中位数。数据由 Artificial Analysis 提供。")
                        .font(.appCaption).foregroundStyle(.secondary)
                    Link("在 Artificial Analysis 查看 ↗", destination: URL(string: "https://artificialanalysis.ai/models/\(model.slug)")!)
                }.padding(22).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }.background(Color(red: 0.965, green: 0.972, blue: 0.962))
                .navigationTitle("模型详情").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 320, minHeight: 400)
    }
    private func metric(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.medium).multilineTextAlignment(.trailing) }.font(.appSubheadline).padding(.vertical, 12)
    }
}
