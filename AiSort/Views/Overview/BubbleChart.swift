import SwiftUI
import Charts

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct BubbleChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let models: [AIModel]
    let metrics: ChartMetrics
    let favoriteModelIDs: Set<String>
    @Binding var highlighted: AIModel?
    @Binding var focusRequest: String?
    @Binding var offset: CGSize
    let scale: CGFloat
    let isInteracting: Bool
    let toggleFavorite: (AIModel) -> Void
    let showDetail: (AIModel) -> Void
    @State private var resolvedLabels: ResolvedChartLabels?
    @State private var hoveredModelID: String?
    nonisolated private static let labelFontSize: CGFloat = 12
    nonisolated private static let labelFontSizes: [CGFloat] = [12, 10, 9, 8.5]
    private static let labelTracking: CGFloat = -0.35
    private static let intelligenceAxisLabelWidth: CGFloat = 44
    private func visibleFrontierIDs(metrics: ChartMetrics, xRange: ClosedRange<Double>,
                                    yRange: ClosedRange<Double>) -> Set<String> {
        let visibleModels = models.filter { model in
            guard let intelligence = model.intelligence else { return false }
            return xRange.contains(metrics.x(for: model)) && yRange.contains(intelligence)
        }
        return Self.paretoFrontierIDs(for: visibleModels)
    }

    private func primaryModelIDs(frontier: Set<String>) -> Set<String> {
        var ids = frontier.union(favoriteModelIDs)
        if let highlightedID = highlighted?.id { ids.insert(highlightedID) }
        if let hoveredModelID { ids.insert(hoveredModelID) }
        return ids
    }

    private var featuredModelIDs: Set<String> {
        let ordered = models.sorted { $0.id < $1.id }
        let smartest = ordered.max { ($0.intelligence ?? -.infinity) < ($1.intelligence ?? -.infinity) }
        let costliest = ordered.filter { $0.cost != nil }.max { ($0.cost ?? 0) < ($1.cost ?? 0) }
        return Set([smartest?.id, costliest?.id].compactMap { $0 })
    }

    /// Cost-intelligence Pareto frontier inside the active viewport (cheapest at each intelligence gain).
    static func paretoFrontierIDs(for models: [AIModel]) -> Set<String> {
        let ranked = models.compactMap { model -> (id: String, cost: Double, intelligence: Double, speed: Double)? in
            guard let intelligence = model.intelligence, let cost = model.chartCost, let speed = model.chartSpeed else { return nil }
            return (model.id, cost, intelligence, speed)
        }.sorted {
            if $0.cost != $1.cost { return $0.cost < $1.cost }
            if $0.intelligence != $1.intelligence { return $0.intelligence > $1.intelligence }
            if $0.speed != $1.speed { return $0.speed > $1.speed }
            return $0.id < $1.id
        }
        var bestIntelligence = -Double.infinity
        var frontier: Set<String> = []
        for item in ranked where item.intelligence > bestIntelligence + 1e-9 {
            frontier.insert(item.id)
            bestIntelligence = item.intelligence
        }
        return frontier
    }
    private var referenceModel: AIModel? {
        highlighted ?? models.first { $0.id == hoveredModelID }
    }

    static func priceTicks(maxX: Double, visibleRange: ClosedRange<Double>, viewportWidth: CGFloat) -> [Double] {
        let lower = max(0, visibleRange.lowerBound)
        let upper = min(maxX, visibleRange.upperBound)
        guard lower <= upper else { return [] }
        let span = upper - lower
        guard span > 0 else { return [lower] }

        let plotWidth = Double(max(viewportWidth - 100, 0))
        let priceWidth = plotWidth * span / (visibleRange.upperBound - visibleRange.lowerBound)
        let tickCount = 1 + Int(min(4, priceWidth / 54))
        guard tickCount > 1 else {
            return [roundedPriceTick(near: lower + span / 2, in: lower...upper)]
        }

        let spacing = span / Double(tickCount - 1)
        return (0..<tickCount).map { index in
            let target = min(upper, lower + Double(index) * spacing)
            let tolerance = spacing * 0.18
            return roundedPriceTick(near: target, in: max(lower, target - tolerance)...min(upper, target + tolerance))
        }
    }

    private static func roundedPriceTick(near target: Double, in range: ClosedRange<Double>) -> Double {
        let price = pow(10, target) - 1
        let priceSpan = pow(10, range.upperBound) - pow(10, range.lowerBound)
        let unit = pow(10, floor(log10(max(priceSpan, 0.0001))))
        // Use the largest round dollar increment that fits this slot on the log axis.
        for step in [unit * 10, unit * 5, unit * 2, unit, unit / 2, unit / 5] where step >= 0.0001 {
            let units = (price / step).rounded()
            let nearest = log10(1 + units * step)
            if range.contains(nearest) { return nearest }
            let inward = nearest < range.lowerBound ? units + 1 : units - 1
            let tick = log10(1 + inward * step)
            if range.contains(tick) { return tick }
        }
        return target
    }

    var body: some View {
        let viewportSize = metrics.viewportSize
        let (visibleXBounds, visibleYBounds) = metrics.visibleBounds(offset: offset, scale: scale)
        let xMidpoint = (visibleXBounds.lowerBound + visibleXBounds.upperBound) / 2
        let lower = ceil(visibleYBounds.lowerBound), upper = floor(visibleYBounds.upperBound)
        let intelligenceTicks = lower <= upper ? Array(stride(from: lower, through: upper, by: 1)) : []
        let ySpan = visibleYBounds.upperBound - visibleYBounds.lowerBound
        let pointsPerIntelligence = Double(max(0, viewportSize.height - 80)) / ySpan
        let showsEveryIntelligenceValue = pointsPerIntelligence >= 26
        let highestModel = models.max { lhs, rhs in
            let lhsScore = lhs.intelligence ?? -.infinity
            let rhsScore = rhs.intelligence ?? -.infinity
            if lhsScore != rhsScore { return lhsScore < rhsScore }
            let lhsX = metrics.x(for: lhs)
            let rhsX = metrics.x(for: rhs)
            if lhsX != rhsX { return lhsX > rhsX }
            return lhs.id > rhs.id
        }
        let highestScore = highestModel?.intelligence
        let highestScoreTicks = highestScore.map { visibleYBounds.contains($0) ? [$0] : [] } ?? []
        let highestColor = highestModel.map { creatorColor($0.modelCreator.name, in: colorScheme) } ?? ink
        let visibleReferenceScore = referenceModel.flatMap { model -> Double? in
            guard let score = model.intelligence, visibleYBounds.contains(score),
                  visibleXBounds.contains(metrics.x(for: model)) else { return nil }
            return score
        }
        let drawsHighestGuide = highestModel.map { visibleXBounds.contains(metrics.x(for: $0)) } ?? false
        let guideScores = (drawsHighestGuide ? highestScoreTicks : []) + [visibleReferenceScore].compactMap { $0 }

        let orderedModels = models.sorted {
            let favA = favoriteModelIDs.contains($0.id)
            let favB = favoriteModelIDs.contains($1.id)
            if favA != favB { return !favA && favB }
            let sizeA = metrics.bubbleSize(for: $0)
            let sizeB = metrics.bubbleSize(for: $1)
            if sizeA != sizeB { return sizeA > sizeB }
            return $0.id < $1.id
        }

        Chart {
            ForEach(orderedModels) { model in
                if let intelligence = model.intelligence {
                    let isFavorite = favoriteModelIDs.contains(model.id)
                    let color = creatorColor(model.modelCreator.name, in: colorScheme).opacity(0.96)
                    let point = PointMark(x: .value("成本", metrics.x(for: model)), y: .value("智力指数", intelligence))
                    let diameter = 2 * metrics.bubbleRadius(for: model)
                    if isFavorite {
                        let starSize = max(4.8, diameter * 0.52)
                        if let cost = model.cost {
                            point.symbol {
                                ZStack {
                                    Circle()
                                        .fill(color)
                                        .frame(width: diameter, height: diameter)
                                    Image(systemName: "star.fill")
                                        .font(.system(size: starSize, weight: .bold))
                                        .foregroundStyle(colorScheme == .dark ? appBackground : .white)
                                }
                            }
                            .accessibilityLabel("已收藏，\(model.name)，智力 \(number(intelligence))，3比1混合单价 \(dollars(cost)) 美元每百万 token，速度 \(number(model.chartSpeed))")
                        } else {
                            point.symbol {
                                ZStack {
                                    Circle()
                                        .strokeBorder(color, lineWidth: 1.8)
                                        .frame(width: diameter, height: diameter)
                                    Image(systemName: "star.fill")
                                        .font(.system(size: min(10, max(5, diameter * 0.45)), weight: .bold))
                                        .foregroundStyle(color)
                                }
                            }
                            .accessibilityLabel("已收藏，\(model.name)，智力 \(number(intelligence))，暂无报价，速度 \(model.chartSpeed.map { number($0) } ?? "暂无数据")")
                        }
                    } else if let cost = model.cost {
                        point.symbolSize(metrics.bubbleSize(for: model))
                            .foregroundStyle(color)
                            .accessibilityLabel("\(model.name)，智力 \(number(intelligence))，3比1混合单价 \(dollars(cost)) 美元每百万 token，速度 \(number(model.chartSpeed))")
                    } else {
                        point.symbol {
                            Circle().strokeBorder(color, lineWidth: 1.8).frame(width: diameter, height: diameter)
                        }
                        .accessibilityLabel("\(model.name)，智力 \(number(intelligence))，暂无报价，速度 \(model.chartSpeed.map { number($0) } ?? "暂无数据")")
                    }
                }
            }
        }
        .chartXScale(domain: visibleXBounds).chartYScale(domain: visibleYBounds)
        .chartPlotStyle { plot in
            plot.clipped()
        }
        .chartXAxis {
            AxisMarks(values: Self.priceTicks(maxX: metrics.maxX, visibleRange: visibleXBounds,
                                             viewportWidth: viewportSize.width)) { value in
                AxisGridLine().foregroundStyle(.primary.opacity(0.07))
                AxisTick()
                if let tick = value.as(Double.self) {
                    let anchor: UnitPoint = if value.index == 0 && tick <= xMidpoint {
                        .topLeading
                    } else if value.index == value.count - 1 && tick >= xMidpoint {
                        .topTrailing
                    } else {
                        .top
                    }
                    AxisValueLabel(anchor: anchor) {
                        Text(dollars(pow(10, tick) - 1))
                            .font(.appCaption2)
                            .fixedSize()
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: intelligenceTicks) { value in
                let score = value.as(Double.self) ?? 0
                let isMajor = Int(score).isMultiple(of: 5)
                let sharesGuideRow = guideScores.contains { abs(score - $0) * pointsPerIntelligence < 1 }
                if !sharesGuideRow {
                    AxisGridLine()
                        .foregroundStyle(ink.opacity(isMajor ? 0.14 : 0.045))
                }
                let overlapsHighestScore = highestScoreTicks.contains {
                    abs(score - $0) * pointsPerIntelligence < 24
                }
                if (isMajor || showsEveryIntelligenceValue) && !overlapsHighestScore {
                    AxisValueLabel(horizontalSpacing: 6) {
                        Text(score, format: .number.precision(.fractionLength(0)))
                            .font(.appCaption.monospacedDigit())
                            .frame(width: Self.intelligenceAxisLabelWidth, alignment: .trailing)
                    }
                }
            }
            AxisMarks(position: .leading, values: highestScoreTicks) { value in
                AxisValueLabel(collisionResolution: .disabled, horizontalSpacing: 6) {
                    if let score = value.as(Double.self) {
                        Text(number(score))
                            .font(.appCaption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(highestColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: Self.intelligenceAxisLabelWidth, alignment: .trailing)
                            .accessibilityLabel("最高智力指数 \(number(score))")
                    }
                }
            }
        }
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            Text(viewportSize.width >= 380 ? "混合单价（输入∶输出 = 3∶1）· 美元 / 百万 token"
                 : viewportSize.width >= 250 ? "混合单价 · 美元 / 百万 token" : "美元 / 百万 token")
                .font(.appCaption)
                .lineLimit(1)
                .help("混合单价按输入与输出 token 数量 3:1 计算；横轴采用对数压缩。")
        }
        .chartYAxisLabel(position: .top, alignment: .leading) {
            Text("智力指数").font(.appCaption)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            guard !isInteracting, let frame = proxy.plotFrame else {
                                hoveredModelID = nil
                                return
                            }
                            switch phase {
                            case .active(let location):
                                let plot = geo[frame]
                                let nearest = models.compactMap { model -> (String, CGFloat)? in
                                    guard let score = model.intelligence,
                                          let x = proxy.position(forX: metrics.x(for: model)),
                                          let y = proxy.position(forY: score) else { return nil }
                                    let distance = hypot(location.x - plot.minX - x, location.y - plot.minY - y)
                                    let radius = metrics.bubbleRadius(for: model)
                                    return distance <= radius + 6 ? (model.id, distance) : nil
                                }.min { $0.1 < $1.1 }
                                hoveredModelID = nearest?.0
                            case .ended:
                                hoveredModelID = nil
                            }
                        }
                        .onChange(of: isInteracting) { _, active in
                            if active { hoveredModelID = nil }
                        }
                        .onChange(of: focusRequest) { _, request in
                            guard let request, let model = models.first(where: { $0.id == request }),
                                  let score = model.intelligence else { return }
                            let visibleXSpan = visibleXBounds.upperBound - visibleXBounds.lowerBound
                            let visibleYSpan = visibleYBounds.upperBound - visibleYBounds.lowerBound
                            let xCenter = (metrics.xBounds.upperBound + metrics.xBounds.lowerBound) / 2
                            let yCenter = (metrics.yBounds.upperBound + metrics.yBounds.lowerBound) / 2
                            let proposedX = CGFloat(xCenter - metrics.x(for: model)) * viewportSize.width / CGFloat(visibleXSpan)
                            let proposedY = CGFloat(score - yCenter) * viewportSize.height / CGFloat(visibleYSpan)
                            let proposed = CGSize(width: proposedX, height: proposedY)
                            offset = metrics.boundedOffset(proposed, scale: scale)
                            focusRequest = nil
                        }
                        .gesture(SpatialTapGesture().onEnded { gesture in
                            guard let frame = proxy.plotFrame else { return }
                            let origin = geo[frame].origin
                            let point = CGPoint(x: gesture.location.x - origin.x, y: gesture.location.y - origin.y)
                            let nearest = models.compactMap { model -> (AIModel, CGFloat)? in
                                guard let score = model.intelligence, let x = proxy.position(forX: metrics.x(for: model)), let y = proxy.position(forY: score) else { return nil }
                                return (model, hypot(x - point.x, y - point.y))
                            }.min { $0.1 < $1.1 }
                            if let nearest, nearest.1 < 24 {
                                highlighted = highlighted?.id == nearest.0.id ? nil : nearest.0
                            } else {
                                highlighted = nil
                            }
                        })

                    if let frame = proxy.plotFrame {
                        let plot = geo[frame]
                        let guideHighlighted = highestModel.map { $0.id == referenceModel?.id } ?? false
                        let guideEnd = highestModel.flatMap { model -> CGPoint? in
                            guard drawsHighestGuide, let score = highestScoreTicks.first,
                                  guideHighlighted || visibleReferenceScore != score,
                                  let x = proxy.position(forX: metrics.x(for: model)),
                                  let y = proxy.position(forY: score) else { return nil }
                            return CGPoint(x: plot.minX + x - metrics.bubbleRadius(for: model), y: plot.minY + y)
                        }
                        if isInteracting {
                            if let guideEnd {
                                highestScoreGuide(from: plot.minX, to: guideEnd, avoiding: [],
                                                  color: highestColor, highlighted: guideHighlighted)
                            }
                        } else {
                            modelLabels(plotRect: plot, metrics: metrics,
                                        xRange: visibleXBounds, yRange: visibleYBounds,
                                        guideEnd: guideEnd, guideColor: highestColor,
                                        guideHighlighted: guideHighlighted)
                        }
                    }
                    if let model = referenceModel, model.id != highestModel?.id, let score = model.intelligence,
                       let frame = proxy.plotFrame,
                       let x = proxy.position(forX: metrics.x(for: model)),
                       let y = proxy.position(forY: score) {
                        let plot = geo[frame]
                        let anchor = CGPoint(x: plot.minX + x, y: plot.minY + y)
                        if plot.contains(anchor) {
                            intelligenceGuide(score: score, anchor: anchor, plotRect: plot)
                        }
                    }
                    if let model = highlighted, let score = model.intelligence,
                       let plotFrame = proxy.plotFrame,
                       let x = proxy.position(forX: metrics.x(for: model)),
                       let y = proxy.position(forY: score) {
                        let plot = geo[plotFrame]
                        let anchor = CGPoint(x: plot.minX + x, y: plot.minY + y)
                        if plot.contains(anchor) {
                            selectionBubble(for: model, radius: metrics.bubbleRadius(for: model), anchor: anchor,
                                            size: CGSize(width: geo.size.width, height: plot.maxY),
                                            spaceAbove: max(0, geo.frame(in: .named("overviewViewport")).minY - 8))
                        }
                    }
                }
            }
        }
    }

    private func selectionBubble(for model: AIModel, radius: CGFloat, anchor: CGPoint, size: CGSize, spaceAbove: CGFloat) -> some View {
        let width = min(320, max(148, size.width - 24))
        let showsName = width >= 190 && size.width >= 280 && size.height >= 220
        let height = ModelBubble.height(showsName: showsName)
        let placement = BubblePlacement.place(size: CGSize(width: width, height: height),
                                              at: CGPoint(x: anchor.x, y: anchor.y + spaceAbove),
                                              in: CGSize(width: size.width, height: size.height + spaceAbove),
                                              gap: radius)
        let frame = placement.frame.offsetBy(dx: 0, dy: -spaceAbove)
        return ModelBubble(model: model, isFavorite: favoriteModelIDs.contains(model.id),
                           width: width, showsName: showsName,
                           pointsUp: placement.isBelowAnchor,
                           tailCenterX: min(width - 23, max(23, anchor.x - frame.minX)),
                           toggleFavorite: { toggleFavorite(model) },
                           showDetail: { showDetail(model) }, dismiss: { highlighted = nil })
            .position(x: frame.midX, y: frame.midY)
            .zIndex(2)
    }

    private func intelligenceGuide(score: Double, anchor: CGPoint, plotRect: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: plotRect.minX, y: anchor.y))
                path.addLine(to: anchor)
            }
            .stroke(ink.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            Text(number(score))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(appBackground)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(ink, in: RoundedRectangle(cornerRadius: 4))
                .fixedSize()
                .position(x: plotRect.minX + 24, y: min(anchor.y, plotRect.maxY - 14))
        }
        .allowsHitTesting(false)
        .accessibilityLabel("智力指数 \(number(score))")
    }

    private func modelLabels(plotRect: CGRect, metrics: ChartMetrics,
                             xRange: ClosedRange<Double>, yRange: ClosedRange<Double>,
                             guideEnd: CGPoint?, guideColor: Color, guideHighlighted: Bool) -> some View {
        let layoutKey = LabelLayoutKey(
            plotRect: plotRect, scale: scale, xBounds: xRange, yBounds: yRange,
            missingPriceX: metrics.missingPriceX, maxSpeed: metrics.maxSpeed,
            models: models.map { model in
                LabelModel(id: model.id, name: model.name, creator: model.modelCreator.name,
                           cost: model.cost, intelligence: model.intelligence, speed: model.chartSpeed,
                           isFavorite: favoriteModelIDs.contains(model.id))
            }
        )
        let canReuseLabels = resolvedLabels.map { $0.key == layoutKey || $0.key.hasSameViewport(as: layoutKey) } ?? false
        let visibleIDs = Set(models.map(\.id))
        let labels = canReuseLabels ? resolvedLabels?.placements.filter { visibleIDs.contains($0.id) } ?? [] : []
        let orderedLabels = labels.filter { !$0.isFavorite } + labels.filter { $0.isFavorite }
        let primary = primaryModelIDs(frontier: resolvedLabels?.frontier ?? [])
        let featured = resolvedLabels?.featured ?? []
        return ZStack(alignment: .topLeading) {
            if let guideEnd {
                highestScoreGuide(from: plotRect.minX, to: guideEnd, avoiding: labels,
                                  color: guideColor, highlighted: guideHighlighted)
            }
            ForEach(orderedLabels) { label in
                let emphasized = primary.contains(label.id) || featured.contains(label.id)
                let color = creatorColor(label.creator, in: colorScheme)
                leaderLine(for: label)
                    .stroke(color.opacity(emphasized ? 0.6 : 0.3),
                            lineWidth: emphasized ? 1.0 : 0.75)
            }
            ForEach(orderedLabels) { label in
                let emphasized = primary.contains(label.id) || featured.contains(label.id)
                let creatorTint = creatorColor(label.creator, in: colorScheme)
                let color = emphasized ? creatorTint
                    : creatorTint.opacity(colorScheme == .dark ? 0.78 : 0.72)
                Text(label.name)
                    .font(.system(size: label.fontSize, weight: emphasized ? .semibold : .regular))
                    .tracking(Self.labelTracking)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: label.frame.width,
                           alignment: label.frame.maxX < label.anchor.x ? .trailing : .leading)
                    .offset(x: label.frame.minX, y: label.frame.minY)
            }
        }
        .mask(alignment: .topLeading) {
            Rectangle()
                .frame(width: plotRect.width + 40, height: plotRect.height + 30)
                .offset(x: plotRect.minX - 20, y: plotRect.minY - 30)
        }
        .allowsHitTesting(false)
        .task(id: layoutKey) {
            guard resolvedLabels?.key != layoutKey else { return }
            let sameViewport = resolvedLabels?.key.hasSameViewport(as: layoutKey) ?? false
            if !sameViewport {
                do { try await Task.sleep(for: .milliseconds(80)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            let candidates = labelCandidates(plotRect: plotRect, metrics: metrics, xRange: xRange, yRange: yRange)
            let featured = featuredModelIDs
            let frontier = visibleFrontierIDs(metrics: metrics, xRange: xRange, yRange: yRange)
            let primary = primaryModelIDs(frontier: frontier)
            let input = Self.measureLabels(candidates, plotRect: plotRect)
            let layouts = await Self.solveLabelsInBackground(input, featured: featured, primary: primary)
            guard !Task.isCancelled else { return }
            let placements = candidates.compactMap { candidate -> ChartLabelPlacement? in
                guard let layout = layouts[candidate.id] else { return nil }
                var label = candidate
                label.fontSize = layout.fontSize
                label.frame = CGRect(origin: CGPoint(x: label.anchor.x + layout.offset.width,
                                                     y: label.anchor.y + layout.offset.height),
                                     size: layout.size)
                return label
            }
            resolvedLabels = ResolvedChartLabels(key: layoutKey, placements: placements,
                                                 featured: featured, frontier: frontier)
        }
    }

    private func highestScoreGuide(from startX: CGFloat, to end: CGPoint,
                                   avoiding labels: [ChartLabelPlacement], color: Color,
                                   highlighted: Bool) -> some View {
        Path { path in
            let gaps = labels.map { $0.frame.insetBy(dx: -4, dy: -2) }
                .filter { $0.minY <= end.y && end.y <= $0.maxY && $0.maxX > startX && $0.minX < end.x }
                .sorted { $0.minX < $1.minX }
            var x = startX
            for gap in gaps {
                if gap.minX > x {
                    path.move(to: CGPoint(x: x, y: end.y))
                    path.addLine(to: CGPoint(x: gap.minX, y: end.y))
                }
                x = max(x, gap.maxX)
            }
            if x < end.x {
                path.move(to: CGPoint(x: x, y: end.y))
                path.addLine(to: end)
            }
        }
        .stroke(color.opacity(highlighted ? 0.65 : 0.35),
                style: StrokeStyle(lineWidth: 1, dash: highlighted ? [4, 3] : []))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func labelCandidates(plotRect: CGRect, metrics: ChartMetrics, xRange: ClosedRange<Double>,
                                 yRange: ClosedRange<Double>) -> [ChartLabelPlacement] {
        guard plotRect.width > 0, plotRect.height > 0 else { return [] }
        let hitArea = plotRect.insetBy(dx: -4, dy: -4)
        let maxLabelWidth = max(1, plotRect.width - 12)
        return models.compactMap { model -> ChartLabelPlacement? in
            guard let intelligence = model.intelligence else { return nil }
            let x = (metrics.x(for: model) - xRange.lowerBound) / (xRange.upperBound - xRange.lowerBound)
            let y = (yRange.upperBound - intelligence) / (yRange.upperBound - yRange.lowerBound)
            let anchor = CGPoint(x: plotRect.minX + CGFloat(x) * plotRect.width,
                                 y: plotRect.minY + CGFloat(y) * plotRect.height)
            guard hitArea.contains(anchor) else { return nil }
            let isFavorite = favoriteModelIDs.contains(model.id)
            let name = shortModelName(model.name)
            let radius = metrics.bubbleRadius(for: model)
            let labelHeight = Self.measuredLabelHeight()
            let labelWidth = min(Self.measuredLabelWidth(name), maxLabelWidth)
            let frame = CGRect(x: anchor.x + radius + 4, y: anchor.y - labelHeight / 2,
                               width: labelWidth, height: labelHeight)
            return ChartLabelPlacement(id: model.id, name: name, creator: model.modelCreator.name,
                                       isFavorite: isFavorite, radius: radius, anchor: anchor, frame: frame)
        }
    }

    private func leaderLine(for label: ChartLabelPlacement) -> Path {
        Path { path in
            let isLeft = label.frame.maxX < label.anchor.x
            let edgeX = isLeft ? label.frame.maxX + 2 : label.frame.minX - 2
            let end = CGPoint(x: edgeX, y: label.frame.midY)
            let dx = end.x - label.anchor.x, dy = end.y - label.anchor.y
            let distance = hypot(dx, dy)
            let horizontalGap = isLeft ? label.anchor.x - edgeX - label.radius : edgeX - label.anchor.x - label.radius
            guard (abs(dy) > 4 || horizontalGap > 8), distance > label.radius + 2 else { return }
            path.move(to: CGPoint(x: label.anchor.x + dx / distance * label.radius,
                                  y: label.anchor.y + dy / distance * label.radius))
            path.addLine(to: end)
        }
    }

    static func resolveLabelOffsets(_ candidates: [ChartLabelPlacement], plotRect: CGRect,
                                    featured: Set<String>) -> [String: CGSize] {
        resolveLabelLayouts(candidates, plotRect: plotRect, featured: featured).mapValues(\.offset)
    }

    /// Place visible labels to the left or right of their bubbles with dynamic font sizing
    /// and distribute them holistically inside the plot viewport so leader lines never cross.
    static func resolveLabelLayouts(_ candidates: [ChartLabelPlacement], plotRect: CGRect,
                                    featured: Set<String>,
                                    primary: Set<String> = []) -> [String: ChartLabelLayout] {
        let input = measureLabels(candidates, plotRect: plotRect)
        return solveLabels(input, featured: featured, primary: primary)
    }

    private static func measureLabels(_ candidates: [ChartLabelPlacement], plotRect: CGRect) -> LabelLayoutInput {
        // Leave the horizontal axis clear for the price ticks and their labels.
        let area = CGRect(x: plotRect.minX - 16, y: plotRect.minY - 24,
                          width: plotRect.width + 20, height: plotRect.height + 20)
        let hitArea = plotRect.insetBy(dx: -4, dy: -4)
        let visibleBubbles = candidates.filter { hitArea.contains($0.anchor) }
        let active = visibleBubbles.sorted {
            if $0.anchor.y != $1.anchor.y { return $0.anchor.y < $1.anchor.y }
            if $0.anchor.x != $1.anchor.x { return $0.anchor.x < $1.anchor.x }
            return $0.id < $1.id
        }
        let maxLabelWidth = max(1, plotRect.width - 12)
        let compactFontSizes = labelFontSizes.dropFirst()
        let compactHeights = compactFontSizes.map { measuredLabelHeight(fontSize: $0) }
        let sizes = active.map { item in
            [item.frame.size] + zip(compactFontSizes, compactHeights).map { fontSize, height in
                CGSize(width: min(measuredLabelWidth(item.name, fontSize: fontSize), maxLabelWidth), height: height)
            }
        }
        return LabelLayoutInput(area: area, visibleBubbles: visibleBubbles, active: active, sizes: sizes)
    }

    @concurrent
    nonisolated private static func solveLabelsInBackground(_ input: LabelLayoutInput, featured: Set<String>,
                                                           primary: Set<String>) async -> [String: ChartLabelLayout] {
        solveLabels(input, featured: featured, primary: primary)
    }

    nonisolated private static func solveLabels(_ input: LabelLayoutInput, featured: Set<String>,
                                                primary: Set<String>) -> [String: ChartLabelLayout] {
        let area = input.area
        let active = input.active
        let visibleBubbles = input.visibleBubbles
        var placedBands: [(minX: CGFloat, maxX: CGFloat, anchorY: CGFloat)] = []
        var specs: [LabelDistributionSpec] = []
        specs.reserveCapacity(active.count)
        for (index, item) in active.enumerated() {
            guard !Task.isCancelled else { return [:] }
            let spec = makeLabelSpec(for: item, sizes: input.sizes[index], candidates: visibleBubbles,
                                     placedBands: placedBands, area: area, minFontIndex: 0)
            specs.append(spec)
            placedBands.append((spec.minX, spec.maxX, item.anchor.y))
        }
        var fontIndices = specs.map(\.fontIndex)
        var activeIndices = Array(active.indices)

        while !activeIndices.isEmpty {
            guard !Task.isCancelled else { return [:] }
            let neighbors = overlappingLabels(indices: activeIndices, specs: specs)
            let centerY = distributeCenters(indices: activeIndices, active: active, specs: specs,
                                            neighbors: neighbors, area: area)
            guard !Task.isCancelled else { return [:] }
            if let overcrowdedPos = worstOvercrowdedPosition(indices: activeIndices, centerY: centerY,
                                                             active: active, specs: specs, neighbors: neighbors,
                                                             visibleBubbles: visibleBubbles,
                                                             featured: featured, primary: primary) {
                let idx = activeIndices[overcrowdedPos]
                let nextFontIndex = fontIndices[idx] + 1
                if nextFontIndex < labelFontSizes.count {
                    fontIndices[idx] = nextFontIndex
                    let activeBands = activeIndices.filter { $0 != idx }.map {
                        (specs[$0].minX, specs[$0].maxX, active[$0].anchor.y)
                    }
                    specs[idx] = makeLabelSpec(for: active[idx], sizes: input.sizes[idx], candidates: visibleBubbles,
                                               placedBands: activeBands, area: area, minFontIndex: nextFontIndex)
                } else {
                    activeIndices.remove(at: overcrowdedPos)
                }
                continue
            }
            var result: [String: ChartLabelLayout] = [:]
            for (pos, idx) in activeIndices.enumerated() {
                let item = active[idx]
                let spec = specs[idx]
                result[item.id] = ChartLabelLayout(
                    offset: CGSize(width: spec.minX - item.anchor.x,
                                   height: centerY[pos] - spec.size.height / 2 - item.anchor.y),
                    fontSize: spec.fontSize,
                    size: spec.size
                )
            }
            return result
        }
        return [:]
    }

    nonisolated private struct LabelDistributionSpec {
        let fontIndex: Int
        let fontSize: CGFloat
        let size: CGSize
        let minX: CGFloat
        let maxX: CGFloat
        let spanMinX: CGFloat
        let spanMaxX: CGFloat
        let targetLo: CGFloat
        let targetHi: CGFloat
        let hardClampToTarget: Bool
    }

    nonisolated private static func makeLabelSpec(for item: ChartLabelPlacement, sizes: [CGSize],
                                                  candidates: [ChartLabelPlacement],
                                                  placedBands: [(minX: CGFloat, maxX: CGFloat, anchorY: CGFloat)],
                                                  area: CGRect, minFontIndex: Int) -> LabelDistributionSpec {
        var bestPenalty: CGFloat = .infinity
        var bestSpec: LabelDistributionSpec?

        for fontIndex in minFontIndex..<labelFontSizes.count {
            let fontSize = labelFontSizes[fontIndex]
            let size = sizes[fontIndex]
            let h = size.height
            let step = h + 2
            let minCenterY = area.minY + h / 2
            let maxCenterY = area.maxY - h / 2
            guard minCenterY <= maxCenterY else { continue }
            var hasFeasibleInBounds = false

            var clearanceRadius = item.radius
            for other in candidates where other.radius > clearanceRadius {
                if abs(other.anchor.x - item.anchor.x) <= other.radius + 2 &&
                    abs(other.anchor.y - item.anchor.y) <= h * 2 + item.radius + other.radius {
                    clearanceRadius = other.radius
                }
            }
            let gap = clearanceRadius + 5

            for isLeft in [true, false] {
                let minX = isLeft ? item.anchor.x - gap - size.width : item.anchor.x + gap
                let maxX = isLeft ? item.anchor.x - gap : item.anchor.x + gap + size.width
                let spanMinX = isLeft ? minX : item.anchor.x
                let spanMaxX = isLeft ? item.anchor.x : maxX

                var penalty: CGFloat = (isLeft ? 0 : 100) + (labelFontSize - fontSize) * 45
                if minX < area.minX { penalty += 10_000 + (area.minX - minX) * 10 }
                if maxX > area.maxX { penalty += 10_000 + (maxX - area.maxX) * 10 }

                var lo = minCenterY
                var hi = maxCenterY
                for other in candidates {
                    let sameColumn = abs(other.anchor.x - item.anchor.x) <= max(item.radius, other.radius) + 2
                    if sameColumn && abs(other.anchor.y - item.anchor.y) <= h * 2 {
                        continue
                    }
                    if minX - 2 < other.anchor.x + other.radius + 2 && maxX + 2 > other.anchor.x - other.radius - 2 {
                        if !sameColumn {
                            if other.anchor.y >= item.anchor.y {
                                hi = min(hi, other.anchor.y - other.radius - h / 2 - 1)
                            } else {
                                lo = max(lo, other.anchor.y + other.radius + h / 2 + 1)
                            }
                        }
                        let dy = abs(other.anchor.y - item.anchor.y)
                        if dy < h / 2 + other.radius + 4 {
                            penalty += 200
                        } else if dy < h * 2 + other.radius {
                            penalty += 10
                        }
                    }
                }
                let feasible = lo <= hi
                if !feasible { penalty += 500 }

                for band in placedBands where max(band.minX, minX) < min(band.maxX, maxX) + 4 {
                    let dy = abs(band.anchorY - item.anchor.y)
                    if dy < step {
                        penalty += 40
                    } else if dy < step * 2 {
                        penalty += 15
                    }
                }

                if minX >= area.minX && maxX <= area.maxX && feasible {
                    hasFeasibleInBounds = true
                }
                if penalty < bestPenalty {
                    bestPenalty = penalty
                    let mid = (lo + hi) / 2
                    bestSpec = LabelDistributionSpec(
                        fontIndex: fontIndex,
                        fontSize: fontSize,
                        size: size,
                        minX: minX,
                        maxX: maxX,
                        spanMinX: spanMinX,
                        spanMaxX: spanMaxX,
                        targetLo: feasible ? max(minCenterY, lo) : mid,
                        targetHi: feasible ? min(maxCenterY, hi) : mid,
                        hardClampToTarget: feasible
                    )
                }
            }
            if hasFeasibleInBounds { break }
        }

        if let bestSpec { return bestSpec }
        return LabelDistributionSpec(
            fontIndex: minFontIndex,
            fontSize: labelFontSizes[minFontIndex],
            size: item.frame.size,
            minX: item.anchor.x + item.radius + 5,
            maxX: item.anchor.x + item.radius + 5 + item.frame.width,
            spanMinX: item.anchor.x,
            spanMaxX: item.anchor.x + item.radius + 5 + item.frame.width,
            targetLo: area.midY,
            targetHi: area.midY,
            hardClampToTarget: false
        )
    }

    nonisolated private static func overlappingLabels(indices: [Int], specs: [LabelDistributionSpec]) -> [[Int]] {
        var neighbors = Array(repeating: [Int](), count: indices.count)
        for i in indices.indices {
            let a = specs[indices[i]]
            for j in (i + 1)..<indices.count {
                let b = specs[indices[j]]
                if max(a.spanMinX, b.spanMinX) < min(a.spanMaxX, b.spanMaxX) + 4 {
                    neighbors[i].append(j)
                    neighbors[j].append(i)
                }
            }
        }
        return neighbors
    }

    nonisolated private static func distributeCenters(indices: [Int], active: [ChartLabelPlacement],
                                                      specs: [LabelDistributionSpec], neighbors: [[Int]],
                                                      area: CGRect) -> [CGFloat] {
        let heights = indices.map { specs[$0].size.height }
        let minimumCenters = heights.map { area.minY + $0 / 2 }
        let maximumCenters = heights.map { area.maxY - $0 / 2 }
        let targets = indices.map { idx -> CGFloat in
            let spec = specs[idx]
            return min(spec.targetHi, max(spec.targetLo, active[idx].anchor.y))
        }
        var centerY = targets
        var previous = centerY
        for iteration in 0..<60 {
            if Task.isCancelled { return centerY }
            let alpha = max(0, 0.25 * (1 - CGFloat(iteration) / 35))
            if alpha > 0 {
                for pos in indices.indices {
                    centerY[pos] += alpha * (targets[pos] - centerY[pos])
                }
            }
            for i in indices.indices {
                let minCI = minimumCenters[i], maxCI = maximumCenters[i]
                for j in neighbors[i] where j > i {
                    let minCJ = minimumCenters[j], maxCJ = maximumCenters[j]
                    let pairStep = (heights[i] + heights[j]) / 2 + 2
                    let diff = centerY[j] - centerY[i]
                    guard diff < pairStep else { continue }
                    let push = (pairStep - diff) / 2
                    var nextI = max(minCI, centerY[i] - push)
                    var nextJ = min(maxCJ, centerY[j] + push)
                    let remaining = pairStep - (nextJ - nextI)
                    if remaining > 0 {
                        if nextI == minCI {
                            nextJ = min(maxCJ, nextJ + remaining)
                        } else if nextJ == maxCJ {
                            nextI = max(minCI, nextI - remaining)
                        }
                    }
                    centerY[i] = min(maxCI, nextI)
                    centerY[j] = max(minCJ, nextJ)
                }
            }
            for pos in centerY.indices {
                let spec = specs[indices[pos]]
                let minCY = minimumCenters[pos], maxCY = maximumCenters[pos]
                var clamped = min(maxCY, max(minCY, centerY[pos]))
                if spec.hardClampToTarget {
                    clamped = min(spec.targetHi, max(spec.targetLo, clamped))
                }
                centerY[pos] = clamped
            }
            if iteration == 0 && centerY == targets { break }
            if alpha == 0 {
                if centerY == previous { break }
                previous = centerY
            }
        }
        return centerY
    }

    nonisolated private static func worstOvercrowdedPosition(indices: [Int], centerY: [CGFloat],
                                                            active: [ChartLabelPlacement], specs: [LabelDistributionSpec],
                                                            neighbors: [[Int]],
                                                 visibleBubbles: [ChartLabelPlacement],
                                                 featured: Set<String>, primary: Set<String>) -> Int? {
        var worstPosition: Int?
        var worstScore: CGFloat = 0
        for i in indices.indices {
            let idxI = indices[i]
            guard !featured.contains(active[idxI].id) else { continue }
            let specI = specs[idxI]
            let heightI = specI.size.height
            var overlapPenalty: CGFloat = 0
            for j in neighbors[i] {
                let specJ = specs[indices[j]]
                let minGap = (heightI + specJ.size.height) / 2 - 0.5
                let gap = abs(centerY[j] - centerY[i])
                if gap < minGap {
                    overlapPenalty = max(overlapPenalty, (minGap - gap) * 10)
                }
            }
            for bubble in visibleBubbles where overlapPenalty < 50 {
                if specI.minX - 1 < bubble.anchor.x + bubble.radius &&
                    specI.maxX + 1 > bubble.anchor.x - bubble.radius &&
                    centerY[i] - heightI / 2 - 1 < bubble.anchor.y + bubble.radius &&
                    centerY[i] + heightI / 2 + 1 > bubble.anchor.y - bubble.radius {
                    overlapPenalty = 50
                    break
                }
            }
            let displacement = abs(centerY[i] - active[idxI].anchor.y)
            let displacementPenalty = displacement > heightI * 2.5 ? displacement : 0
            let conflict = overlapPenalty + displacementPenalty
            let priorityPenalty: CGFloat = conflict > 0 && !primary.contains(active[idxI].id) ? 25 : 0
            let score = conflict + priorityPenalty
            if score > worstScore {
                worstScore = score
                worstPosition = i
            }
        }
        return worstPosition
    }

    private func shortModelName(_ name: String) -> String {
        var base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var variants: [String] = []
        if let opening = base.firstIndex(of: "("),
           let closing = base.lastIndex(of: ")"),
           opening < closing {
            variants = base[base.index(after: opening)..<closing]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            base = String(base[..<opening]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let usefulVariants = variants.filter {
            let value = $0.lowercased()
            return !value.contains("fallback") && value != "default"
        }.map(abbreviateVariant)
        if base.lowercased().hasPrefix("claude ") {
            base.removeFirst("Claude ".count)
        }
        let suffix = usefulVariants.prefix(2).joined(separator: "/")
        return suffix.isEmpty ? base : "\(base) · \(suffix)"
    }

    private func abbreviateVariant(_ value: String) -> String {
        switch value.lowercased() {
        case "xhigh", "extra high": return "XHigh"
        case "medium": return "Med"
        case "minimum": return "Min"
        case "maximum": return "Max"
        case "high": return "High"
        case "low": return "Low"
        default: return value
        }
    }

    private static func measuredLabelWidth(_ text: String, fontSize: CGFloat = labelFontSize) -> CGFloat {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        return ceil((text as NSString).size(withAttributes: [.font: font, .kern: labelTracking]).width) + 4
        #elseif canImport(UIKit)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        return ceil((text as NSString).size(withAttributes: [.font: font, .kern: labelTracking]).width) + 4
        #else
        return ceil(CGFloat(text.count) * fontSize * 0.60) + 4
        #endif
    }

    private static func measuredLabelHeight(fontSize: CGFloat = labelFontSize) -> CGFloat {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        return ceil(font.ascender - font.descender + font.leading)
        #elseif canImport(UIKit)
        return ceil(UIFont.systemFont(ofSize: fontSize, weight: .medium).lineHeight)
        #else
        return ceil(fontSize * 1.25)
        #endif
    }

}

nonisolated struct ChartLabelLayout: Equatable, Sendable {
    let offset: CGSize
    let fontSize: CGFloat
    let size: CGSize
}

nonisolated struct ChartLabelPlacement: Identifiable, Sendable {
    let id: String
    let name: String
    var creator: String = ""
    var fontSize: CGFloat = 12
    var isFavorite: Bool = false
    let radius: CGFloat
    let anchor: CGPoint
    var frame: CGRect
}

struct ChartMetrics {
    let viewportSize: CGSize
    let maxX: Double
    let maxSpeed: Double
    let missingPriceX: Double
    let xBounds: ClosedRange<Double>
    let yBounds: ClosedRange<Double>
    private let rightmostX: Double

    init(models: [AIModel], viewportSize: CGSize) {
        self.viewportSize = viewportSize
        var highestCost = 0.0, fastestSpeed = 1.0
        var lowestScore = Double.infinity, highestScore = -Double.infinity
        var hasMissingPrice = false
        for model in models {
            if let cost = model.chartCost {
                highestCost = max(highestCost, cost)
            } else {
                hasMissingPrice = true
            }
            if let speed = model.chartSpeed { fastestSpeed = max(fastestSpeed, speed) }
            if let score = model.intelligence {
                lowestScore = min(lowestScore, score)
                highestScore = max(highestScore, score)
            }
        }
        maxX = max(0.1, highestCost * 1.08)
        maxSpeed = fastestSpeed
        let plotWidth = max(viewportSize.width - 100, 80)
        let fraction = Double(min(0.3, 24 / plotWidth))
        let inset = maxX * fraction / (1 - 2 * fraction)
        missingPriceX = -1.5 * inset
        let leftmostX = hasMissingPrice ? missingPriceX : 0
        xBounds = (leftmostX - inset)...(maxX + inset)
        rightmostX = highestCost

        let low = lowestScore.isFinite ? lowestScore : 0
        let high = highestScore.isFinite ? highestScore : 1
        let height = max(viewportSize.height - 80, 80)
        let padding = max((high - low) * max(0.03, Double(24 / height)), 1)
        yBounds = floor(low - padding)...ceil(high + padding)
    }

    func x(for model: AIModel) -> Double { model.chartCost ?? missingPriceX }

    func boundedOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        let horizontalLimit = viewportSize.width * (scale - 1) / 2
        let verticalLimit = viewportSize.height * (scale - 1) / 2
        // Keep the space beside the rightmost bubble constant in screen points as the data scale changes.
        let rightPaddingFraction = (xBounds.upperBound - rightmostX) / (xBounds.upperBound - xBounds.lowerBound)
        let rightPanLimit = horizontalLimit * CGFloat(2 * rightPaddingFraction - 1)
        return CGSize(width: min(horizontalLimit, max(rightPanLimit, offset.width)),
                      height: min(verticalLimit, max(-verticalLimit, offset.height)))
    }

    func visibleBounds(offset: CGSize, scale: CGFloat) -> (x: ClosedRange<Double>, y: ClosedRange<Double>) {
        let bounded = boundedOffset(offset, scale: scale)
        return (Self.visibleBounds(xBounds, movement: -bounded.width, axisLength: viewportSize.width, scale: scale),
                Self.visibleBounds(yBounds, movement: bounded.height, axisLength: viewportSize.height, scale: scale))
    }

    private static func visibleBounds(_ base: ClosedRange<Double>, movement: CGFloat,
                                      axisLength: CGFloat, scale: CGFloat) -> ClosedRange<Double> {
        guard axisLength > 0, scale > 1 else { return base }
        let span = (base.upperBound - base.lowerBound) / scale
        let center = (base.upperBound + base.lowerBound) / 2 + Double(movement / axisLength) * span
        let lower = min(base.upperBound - span, max(base.lowerBound, center - span / 2))
        return lower...(lower + span)
    }

    func bubbleSize(for model: AIModel) -> Double {
        guard let speed = model.chartSpeed else { return 144 }
        return 28 + 650 * (speed / maxSpeed)
    }

    func bubbleRadius(for model: AIModel) -> CGFloat { sqrt(bubbleSize(for: model) / .pi) }
}

nonisolated private struct LabelLayoutInput: Sendable {
    let area: CGRect
    let visibleBubbles: [ChartLabelPlacement]
    let active: [ChartLabelPlacement]
    let sizes: [[CGSize]]
}

private struct LabelLayoutKey: Equatable {
    let plotRect: CGRect
    let scale: CGFloat
    let xBounds: ClosedRange<Double>
    let yBounds: ClosedRange<Double>
    let missingPriceX: Double
    let maxSpeed: Double
    let models: [LabelModel]

    func hasSameViewport(as other: LabelLayoutKey) -> Bool {
        plotRect == other.plotRect &&
        scale == other.scale &&
        xBounds == other.xBounds &&
        yBounds == other.yBounds &&
        missingPriceX == other.missingPriceX &&
        maxSpeed == other.maxSpeed
    }
}

private struct LabelModel: Equatable {
    let id: String
    let name: String
    let creator: String
    let cost: Double?
    let intelligence: Double?
    let speed: Double?
    let isFavorite: Bool
}

private struct ResolvedChartLabels {
    let key: LabelLayoutKey
    let placements: [ChartLabelPlacement]
    let featured: Set<String>
    let frontier: Set<String>
}
