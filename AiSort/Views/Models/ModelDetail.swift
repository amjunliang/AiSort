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
                    detailCard("评测") {
                        metric("发布日期", model.releaseDate.flatMap { $0.isEmpty ? nil : $0 } ?? "暂无数据")
                        metric("智力指数\(version.map { " v\(number($0))" } ?? "")", number(model.intelligence))
                        measuredMetric("编程", model.evaluations.artificialAnalysisCodingIndex)
                        measuredMetric("智能体", model.evaluations.artificialAnalysisAgenticIndex)
                        measuredMetric("金融与会计", model.evaluations.artificialAnalysisFinanceAndAccountingIndex)
                        measuredMetric("战略与运营", model.evaluations.artificialAnalysisStrategyAndOpsIndex)
                        measuredMetric("法律", model.evaluations.artificialAnalysisLegalIndex)
                        measuredMetric("医疗与健康", model.evaluations.artificialAnalysisHealthcareAndMedicalIndex)
                        measuredMetric("工程", model.evaluations.artificialAnalysisEngineeringIndex)
                        measuredMetric("经济学", model.evaluations.artificialAnalysisEconomicsIndex)
                        if let cost = model.artificialAnalysisIntelligenceIndexCost {
                            if let total = cost.totalCost { metric("智力指数评测总成本", dollars(total)) }
                            if let perTask = cost.costPerTask?.totalCost { metric("评测平均每题成本", dollars(perTask)) }
                        }
                    }
                    detailCard("价格") {
                        metric("混合单价（3:1）", tokenPrice(model.cost))
                        metric("输入单价", tokenPrice(model.pricing.price1mInputTokens))
                        metric("输出单价", tokenPrice(model.pricing.price1mOutputTokens))
                        if let cacheHit = model.pricing.price1mCacheHitTokens {
                            metric("缓存命中单价", tokenPrice(cacheHit))
                        }
                        if let cacheWrite = model.pricing.price1mCacheWriteTokens {
                            metric("缓存写入单价", tokenPrice(cacheWrite))
                        }
                    }
                    detailCard("性能") {
                        if let performance = model.performanceV3 {
                            measuredMetric("平均输出速度（v3）", performance.meanOutputTokensPerSecond, unit: " token / 秒")
                            measuredMetric("平均首 Token 延迟（v3）", performance.meanTimeToFirstTokenSeconds, unit: " 秒")
                            measuredMetric("平均首个答案 Token 延迟（v3）", performance.meanTimeToFirstAnswerTokenSeconds, unit: " 秒")
                        }
                        metric("中位输出速度", model.speed.map { "\(number($0)) token / 秒" } ?? "暂无数据")
                        measuredMetric("中位首 Token 延迟", model.performance.medianTimeToFirstTokenSeconds, unit: " 秒")
                        measuredMetric("中位首个答案 Token 延迟", model.performance.medianTimeToFirstAnswerTokenSeconds, unit: " 秒")
                        measuredMetric("中位端到端响应耗时", model.performance.medianEndToEndResponseTimeSeconds, unit: " 秒")
                    }
                    Text("混合单价假设输入与输出 token 的比例为 3:1，计算方式为（输入单价 × 3 + 输出单价）÷ 4。它是用于比较的平均单价，实际费用取决于输入和输出 token 的数量。速度为跨供应商的输出速度中位数。数据由 Artificial Analysis 提供。")
                        .font(.appCaption).foregroundStyle(.secondary)
                    Link("在 Artificial Analysis 查看 ↗", destination: URL(string: "https://artificialanalysis.ai/models/\(model.slug)")!)
                }.padding(22).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }.background(Color(red: 0.965, green: 0.972, blue: 0.962))
                .navigationTitle("模型详情").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 320, minHeight: 400)
    }
    private func detailCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.headline).foregroundStyle(ink).accessibilityAddTraits(.isHeader)
            content()
        }
        .card()
    }

    @ViewBuilder
    private func measuredMetric(_ label: String, _ value: Double?, unit: String = "") -> some View {
        if let value, value.isFinite {
            metric(label, number(value) + unit)
        }
    }

    private func tokenPrice(_ value: Double?) -> String {
        value.map { "\(dollars($0)) / 百万 token" } ?? "暂无数据"
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.medium).multilineTextAlignment(.trailing) }.font(.appSubheadline).padding(.vertical, 12)
    }
}
