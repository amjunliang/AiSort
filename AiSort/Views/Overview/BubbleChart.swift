import SwiftUI
import Charts

struct BubbleChart: View {
    let models: [AIModel]
    @Binding var highlighted: AIModel?
    @Binding var focusRequest: String?
    @Binding var offset: CGSize
    let scale: CGFloat
    private var maxX: Double { max(0.1, (models.map(\.chartCost).max() ?? 0) * 1.08) }
    private var yBounds: ClosedRange<Double> {
        let values = models.compactMap(\.intelligence)
        let low = values.min() ?? 0, high = values.max() ?? 1
        let padding = max((high - low) * 0.12, 2)
        return (low - padding)...(high + padding)
    }
    private var maxSpeed: Double { max(models.compactMap(\.speed).max() ?? 1, 1) }
    private var ticks: [Double] { [0.0, 0.1, 1, 10, 100, 1000, 10000].map { log10(1 + $0) }.filter { $0 <= maxX } }
    var body: some View {
        Chart {
            ForEach(models) { model in
                if let intelligence = model.intelligence, let speed = model.speed {
                    PointMark(x: .value("成本", model.chartCost), y: .value("智力指数", intelligence))
                        .symbolSize(28 + 650 * speed / maxSpeed)
                        .foregroundStyle(creatorColor(model.modelCreator.name).opacity(highlighted == nil || highlighted?.id == model.id ? 0.75 : 0.25))
                        .accessibilityLabel("\(model.name)，智力 \(number(intelligence))，成本 \(dollars(model.cost))，速度 \(number(speed))")
                }
            }
        }
        .chartXScale(domain: 0...maxX).chartYScale(domain: yBounds)
        .chartXAxis {
            AxisMarks(values: ticks) { value in
                AxisGridLine().foregroundStyle(.primary.opacity(0.07)); AxisTick()
                AxisValueLabel { if let v = value.as(Double.self) { Text(dollars(pow(10, v) - 1)).font(.caption2) } }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(.primary.opacity(0.07)); AxisValueLabel() } }
        .chartXAxisLabel("混合价格 · 美元 / 百万 token", position: .bottom, alignment: .center)
        .chartYAxisLabel("智力指数", position: .top, alignment: .leading)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onChange(of: focusRequest) { _, request in
                        guard let request, let model = models.first(where: { $0.id == request }), let score = model.intelligence,
                              let frame = proxy.plotFrame, let x = proxy.position(forX: model.chartCost), let y = proxy.position(forY: score) else { return }
                        let origin = geo[frame].origin
                        let proposed = CGSize(width: (geo.size.width / 2 - origin.x - x) * scale, height: (geo.size.height / 2 - origin.y - y) * scale)
                        let maxX = (geo.size.width + 40) * (scale - 1) / 2
                        let maxY = (geo.size.height + 40) * (scale - 1) / 2
                        offset = CGSize(width: min(maxX, max(-maxX, proposed.width)), height: min(maxY, max(-maxY, proposed.height)))
                        focusRequest = nil
                    }
                    .gesture(SpatialTapGesture().onEnded { gesture in
                    guard let frame = proxy.plotFrame else { return }
                    let origin = geo[frame].origin
                    let point = CGPoint(x: gesture.location.x - origin.x, y: gesture.location.y - origin.y)
                    let nearest = models.compactMap { model -> (AIModel, CGFloat)? in
                        guard let score = model.intelligence, let x = proxy.position(forX: model.chartCost), let y = proxy.position(forY: score) else { return nil }
                        return (model, hypot(x - point.x, y - point.y))
                    }.min { $0.1 < $1.1 }
                    if let nearest, nearest.1 < 30 / scale {
                        highlighted = highlighted?.id == nearest.0.id ? nil : nearest.0
                    } else {
                        highlighted = nil
                    }
                })
            }
        }
    }
}
