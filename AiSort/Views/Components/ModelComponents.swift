import SwiftUI

struct HighlightCard: View {
    let model: AIModel
    let showDetail: () -> Void
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(creatorColor(model.modelCreator.name)).frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name).font(.subheadline.bold()).foregroundStyle(ink)
                    Text(model.modelCreator.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("详情", action: showDetail).font(.caption.weight(.semibold))
                Button(action: dismiss) { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("关闭模型信息")
            }
            HStack(spacing: 8) {
                MetricValue(title: "智力指数 ↑", value: number(model.intelligence))
                MetricValue(title: "成本 ↓", value: dollars(model.cost))
                MetricValue(title: "速度 ↑", value: number(model.speed, digits: 0))
            }
        }.padding(14).background(teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MetricValue: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ModelRow: View {
    let model: AIModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(creatorColor(model.modelCreator.name)).frame(width: 8, height: 8)
                Text(model.name).font(.subheadline.weight(.semibold)).foregroundStyle(ink).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(.tertiary)
            }
            Text(model.modelCreator.name + (model.isPlottable ? "" : " · 指标不完整")).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                MetricValue(title: "智力 ↑", value: model.intelligence.map { number($0) } ?? "—")
                MetricValue(title: "成本 ↓ · $/百万", value: model.cost.map { dollars($0) } ?? "—")
                MetricValue(title: "速度 ↑ · token/s", value: model.speed.map { number($0, digits: 0) } ?? "—")
            }
        }.padding(.vertical, 14).contentShape(Rectangle())
    }
}
