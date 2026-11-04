import SwiftUI

struct MetricValue: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.appCaption2).foregroundStyle(.secondary)
            Text(value).font(.appSubheadline.weight(.semibold).monospacedDigit()).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ModelRow: View {
    let model: AIModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(creatorColor(model.modelCreator.name)).frame(width: 8, height: 8)
                Text(model.name).font(.appSubheadline.weight(.semibold)).foregroundStyle(ink).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.appCaption2.bold()).foregroundStyle(.tertiary)
            }
            Text(model.modelCreator.name + (model.isPlottable ? "" : " · 指标不完整")).font(.appCaption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                MetricValue(title: "智力 ↑", value: model.intelligence.map { number($0) } ?? "—")
                MetricValue(title: "成本 ↓ · $/百万", value: model.cost.map { dollars($0) } ?? "—")
                MetricValue(title: "速度 ↑ · token/s", value: model.speed.map { number($0, digits: 0) } ?? "—")
            }
        }.padding(.vertical, 14).contentShape(Rectangle())
    }
}
