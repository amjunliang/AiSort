import SwiftUI
import Charts

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct BubbleChart: View {
    let models: [AIModel]
    let scaleModels: [AIModel]
    @Binding var highlighted: AIModel?
    @Binding var focusRequest: String?
    @Binding var offset: CGSize
    let scale: CGFloat
    let viewportSize: CGSize
    let extraHorizontalPan: CGFloat
    let isInteracting: Bool
    let showDetail: (AIModel) -> Void
    @State private var labelOffsets: [String: CGSize] = [:]
    @State private var hoveredModelID: String?
    private var maxX: Double { max(0.1, (scaleModels.map(\.chartCost).max() ?? 0) * 1.08) }
    private var yBounds: ClosedRange<Double> {
        let values = scaleModels.compactMap(\.intelligence)
        let low = values.min() ?? 0, high = values.max() ?? 1
        let height = max(viewportSize.height - 80, 80)
        let padding = max((high - low) * max(0.03, Double(24 / height)), 1)
        return floor(low - padding)...ceil(high + padding)
    }
    private var xBounds: ClosedRange<Double> {
        // Keep room for the largest circles at both ends, including zero cost.
        let plotWidth = max(viewportSize.width - 100, 80)
        let fraction = Double(min(0.3, 24 / plotWidth))
        let inset = maxX * fraction / (1 - 2 * fraction)
        return (-inset)...(maxX + inset)
    }
    private var visibleXBounds: ClosedRange<Double> {
        visibleBounds(xBounds, offset: offset.width, axisLength: viewportSize.width, inverted: true,
                      trailingMargin: extraHorizontalPan)
    }
    private var visibleYBounds: ClosedRange<Double> {
        visibleBounds(yBounds, offset: offset.height, axisLength: viewportSize.height, inverted: false)
    }
    private var maxSpeed: Double { max(scaleModels.compactMap(\.speed).max() ?? 1, 1) }
    private var featuredModelIDs: Set<String> {
        let ordered = models.sorted { $0.id < $1.id }
        let smartest = ordered.max { ($0.intelligence ?? -.infinity) < ($1.intelligence ?? -.infinity) }
        let costliest = ordered.max { ($0.cost ?? -.infinity) < ($1.cost ?? -.infinity) }
        return Set([smartest?.id, costliest?.id].compactMap { $0 })
    }
    private var intelligenceTicks: [Double] {
        let lower = ceil(visibleYBounds.lowerBound), upper = floor(visibleYBounds.upperBound)
        guard lower <= upper else { return [] }
        return Array(stride(from: lower, through: upper, by: 1))
    }
    private var showsEveryIntelligenceValue: Bool {
        let span = visibleYBounds.upperBound - visibleYBounds.lowerBound
        return Double(max(0, viewportSize.height - 80)) / span >= 26
    }
    private var referenceModel: AIModel? {
        highlighted ?? models.first { $0.id == hoveredModelID }
    }
    private var ticks: [Double] {
        let values = [0.0, 0.1, 1, 10, 100, 1000, 10000].map { log10(1 + $0) }.filter { $0 <= maxX }
        let spacing = log10(1.1) / (visibleXBounds.upperBound - visibleXBounds.lowerBound) * Double(max(viewportSize.width - 100, 0))
        return spacing < 55 && values.count > 1 ? Array(values.dropFirst()) : values
    }
    var body: some View {
        Chart {
            ForEach(models) { model in
                if let intelligence = model.intelligence, let speed = model.speed {
                    PointMark(x: .value("成本", model.chartCost), y: .value("智力指数", intelligence))
                        .symbolSize(28 + 650 * speed / maxSpeed)
                        .foregroundStyle(creatorColor(model.modelCreator.name).opacity(0.82))
                        .accessibilityLabel("\(model.name)，智力 \(number(intelligence))，3比1混合单价 \(dollars(model.cost)) 美元每百万 token，速度 \(number(speed))")
                }
            }
        }
        .chartXScale(domain: visibleXBounds).chartYScale(domain: visibleYBounds)
        .chartPlotStyle { plot in
            plot.clipped()
        }
        .chartXAxis {
            AxisMarks(values: ticks) { value in
                AxisGridLine().foregroundStyle(.primary.opacity(0.07)); AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(dollars(pow(10, v) - 1)).font(.appCaption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: intelligenceTicks) { value in
                let score = value.as(Double.self) ?? 0
                let isMajor = Int(score).isMultiple(of: 5)
                AxisGridLine()
                    .foregroundStyle(ink.opacity(isMajor ? 0.14 : 0.045))
                if isMajor || showsEveryIntelligenceValue {
                    AxisTick().foregroundStyle(ink.opacity(isMajor ? 0.3 : 0.12))
                    AxisValueLabel {
                        Text(score, format: .number.precision(.fractionLength(0)))
                            .font(.appCaption.monospacedDigit())
                            .frame(width: 30, alignment: .leading)
                    }
                }
            }
        }
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            Text("混合单价（输入∶输出 = 3∶1）· 美元 / 百万 token")
                .font(.appCaption)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
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
                                    guard let score = model.intelligence, let speed = model.speed,
                                          let x = proxy.position(forX: model.chartCost),
                                          let y = proxy.position(forY: score) else { return nil }
                                    let distance = hypot(location.x - plot.minX - x, location.y - plot.minY - y)
                                    let radius = sqrt(28 + 650 * speed / maxSpeed) / 2
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
                            guard let request, let model = models.first(where: { $0.id == request }), let score = model.intelligence,
                                  let frame = proxy.plotFrame else { return }
                            let plotFrame = geo[frame]
                            let visibleXSpan = (xBounds.upperBound - xBounds.lowerBound) / scale
                            let visibleYSpan = (yBounds.upperBound - yBounds.lowerBound) / scale
                            let xCenter = (xBounds.upperBound + xBounds.lowerBound) / 2
                            let yCenter = (yBounds.upperBound + yBounds.lowerBound) / 2
                            let proposedX = CGFloat(xCenter - model.chartCost) * plotFrame.width / CGFloat(visibleXSpan)
                            let proposedY = CGFloat(score - yCenter) * plotFrame.height / CGFloat(visibleYSpan)
                            let proposed = CGSize(width: proposedX, height: proposedY)
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
                            if let nearest, nearest.1 < 24 {
                                highlighted = highlighted?.id == nearest.0.id ? nil : nearest.0
                            } else {
                                highlighted = nil
                            }
                        })

                    if let frame = proxy.plotFrame {
                        modelLabels(plotRect: geo[frame])
                    }
                    if let model = referenceModel, let score = model.intelligence,
                       let frame = proxy.plotFrame,
                       let x = proxy.position(forX: model.chartCost),
                       let y = proxy.position(forY: score) {
                        let plot = geo[frame]
                        let anchor = CGPoint(x: plot.minX + x, y: plot.minY + y)
                        if plot.contains(anchor) {
                            intelligenceGuide(score: score, anchor: anchor, plotRect: plot)
                        }
                    }
                    if let model = highlighted, let score = model.intelligence,
                       let plotFrame = proxy.plotFrame,
                       let x = proxy.position(forX: model.chartCost),
                       let y = proxy.position(forY: score) {
                        let plot = geo[plotFrame]
                        let anchor = CGPoint(x: plot.minX + x, y: plot.minY + y)
                        if plot.contains(anchor) {
                            selectionBubble(for: model, anchor: anchor, size: geo.size,
                                            spaceAbove: max(0, geo.frame(in: .named("overviewViewport")).minY - 8))
                        }
                    }
                }
            }
        }
    }

    private func selectionBubble(for model: AIModel, anchor: CGPoint, size: CGSize, spaceAbove: CGFloat) -> some View {
        let width = min(320, max(148, size.width - 24))
        let showsName = width >= 190 && size.width >= 280 && size.height >= 220
        let height: CGFloat = showsName ? 138 : 86
        let radius = sqrt(28 + 650 * (model.speed ?? 0) / maxSpeed) / 2
        let placement = BubblePlacement.place(size: CGSize(width: width, height: height),
                                              at: CGPoint(x: anchor.x, y: anchor.y + spaceAbove),
                                              in: CGSize(width: size.width, height: size.height + spaceAbove),
                                              gap: radius)
        let frame = placement.frame.offsetBy(dx: 0, dy: -spaceAbove)
        return ModelBubble(model: model, width: width, showsName: showsName,
                           pointsUp: placement.isBelowAnchor,
                           tailCenterX: min(width - 23, max(23, anchor.x - frame.minX)),
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
            .stroke(teal.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            Text(number(score))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(teal, in: RoundedRectangle(cornerRadius: 4))
                .fixedSize()
                .position(x: plotRect.minX + 24, y: anchor.y)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("智力指数 \(number(score))")
    }

    private func modelLabels(plotRect: CGRect) -> some View {
        let candidates = labelCandidates(plotRect: plotRect)
        let labels = candidates.compactMap { candidate -> ChartLabelPlacement? in
            guard scale >= 1.5 || featuredModelIDs.contains(candidate.id) else { return nil }
            guard let offset = labelOffsets[candidate.id] else { return nil }
            var label = candidate
            label.frame.origin = CGPoint(x: label.anchor.x + offset.width,
                                         y: label.anchor.y + offset.height)
            return label
        }
        let layoutKey = LabelLayoutKey(plotRect: plotRect, offset: offset, scale: scale,
                                       xBounds: visibleXBounds, yBounds: visibleYBounds, maxSpeed: maxSpeed,
                                       interacting: isInteracting,
                                       models: models.map { "\($0.id):\($0.chartCost):\($0.intelligence ?? 0):\($0.speed ?? 0):\($0.name)" })
        return ZStack(alignment: .topLeading) {
            Path { path in
                for label in labels {
                    let isLeft = label.frame.maxX < label.anchor.x
                    let edgeX = isLeft ? label.frame.maxX : label.frame.minX
                    let end = CGPoint(x: edgeX, y: label.frame.midY)
                    let dx = end.x - label.anchor.x, dy = end.y - label.anchor.y
                    let distance = hypot(dx, dy)
                    guard abs(dy) > 1, distance > label.radius + 2 else { continue }
                    path.move(to: CGPoint(x: label.anchor.x + dx / distance * label.radius,
                                          y: label.anchor.y + dy / distance * label.radius))
                    path.addLine(to: end)
                }
            }
            .stroke(ink.opacity(0.4), lineWidth: 1)
            ForEach(labels) { label in
                Text(label.name)
                    .font(.appCaption.weight(.medium))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: label.frame.width, alignment: .leading)
                    .offset(x: label.frame.minX, y: label.frame.minY)
            }
        }
        .mask(alignment: .topLeading) {
            Rectangle()
                .frame(width: plotRect.width + 40, height: plotRect.height + 60)
                .offset(x: plotRect.minX - 20, y: plotRect.minY - 30)
        }
        .allowsHitTesting(false)
        .task(id: layoutKey) {
            guard !isInteracting else { return }
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            guard !Task.isCancelled else { return }
            labelOffsets = resolveLabelOffsets(candidates, plotRect: plotRect)
        }
    }

    private func labelCandidates(plotRect: CGRect) -> [ChartLabelPlacement] {
        guard plotRect.width > 0, plotRect.height > 0 else { return [] }
        let xRange = visibleXBounds, yRange = visibleYBounds
        return models.compactMap { model -> ChartLabelPlacement? in
            guard let intelligence = model.intelligence, let speed = model.speed else { return nil }
            let x = (model.chartCost - xRange.lowerBound) / (xRange.upperBound - xRange.lowerBound)
            let y = (yRange.upperBound - intelligence) / (yRange.upperBound - yRange.lowerBound)
            let anchor = CGPoint(x: plotRect.minX + CGFloat(x) * plotRect.width,
                                 y: plotRect.minY + CGFloat(y) * plotRect.height)
            let name = shortModelName(model.name)
            let radius = sqrt(28 + 650 * speed / maxSpeed) / 2
            let frame = CGRect(x: anchor.x + radius + 4, y: anchor.y - measuredLabelHeight() / 2,
                               width: min(measuredLabelWidth(name), max(1, plotRect.width - 12)), height: measuredLabelHeight())
            return ChartLabelPlacement(id: model.id, name: name, radius: radius, anchor: anchor, frame: frame)
        }.sorted {
            if $0.anchor.y != $1.anchor.y { return $0.anchor.y < $1.anchor.y }
            if $0.anchor.x != $1.anchor.x { return $0.anchor.x < $1.anchor.x }
            return $0.id < $1.id
        }
    }

    private func resolveLabelOffsets(_ candidates: [ChartLabelPlacement], plotRect: CGRect) -> [String: CGSize] {
        let area = plotRect.insetBy(dx: -16, dy: -24)
        let featured = featuredModelIDs
        let visible = candidates.filter {
            (scale >= 1.5 || featured.contains($0.id)) && area.insetBy(dx: -20, dy: -20).contains($0.anchor)
        }.sorted {
            let firstFeatured = featured.contains($0.id), secondFeatured = featured.contains($1.id)
            if firstFeatured != secondFeatured { return firstFeatured }
            if $0.anchor.y != $1.anchor.y { return $0.anchor.y < $1.anchor.y }
            return $0.id < $1.id
        }
        var occupied = candidates.map {
            CGRect(x: $0.anchor.x - $0.radius - 2, y: $0.anchor.y - $0.radius - 2,
                   width: $0.radius * 2 + 4, height: $0.radius * 2 + 4)
        }
        var result: [String: CGSize] = [:]
        var placedLabels: [(frame: CGRect, anchorY: CGFloat)] = []
        for label in visible {
            let gap = label.radius + 5
            let right = gap, left = -gap - label.frame.width
            var options: [CGSize] = []
            let previous = labelOffsets[label.id]
            let naturalY = -label.frame.height / 2
            // A free interval starts at an obstacle edge. Search those exact
            // positions instead of jumping whole rows or retaining a distant slot.
            for x in [right, left] {
                let minX = label.anchor.x + x - 2
                let maxX = minX + label.frame.width + 4
                var positions = [naturalY, area.minY - label.anchor.y,
                                 area.maxY - label.anchor.y - label.frame.height]
                for obstacle in occupied where obstacle.minX < maxX && minX < obstacle.maxX {
                    positions.append(obstacle.maxY + 2 - label.anchor.y)
                    positions.append(obstacle.minY - 2 - label.frame.height - label.anchor.y)
                }
                if let previous, (previous.width >= 0) == (x >= 0) {
                    positions.append(previous.height)
                }
                func cost(_ y: CGFloat) -> CGFloat {
                    let distance = abs(y - naturalY)
                    guard distance > 0.5 else { return -1 }
                    let retained = previous.map { abs($0.width - x) < 1 && abs($0.height - y) < 1 } ?? false
                    return distance - (retained ? 3 : 0)
                }
                positions.sort {
                    if cost($0) != cost($1) { return cost($0) < cost($1) }
                    return $0 < $1
                }
                for y in positions where featured.contains(label.id) || abs(y - naturalY) <= label.frame.height * 4 {
                    options.append(CGSize(width: x, height: y))
                }
            }
            for option in options {
                let frame = CGRect(x: label.anchor.x + option.width, y: label.anchor.y + option.height,
                                   width: label.frame.width, height: label.frame.height)
                guard area.contains(frame),
                      !placedLabels.contains(where: {
                          $0.frame.minX < frame.maxX && frame.minX < $0.frame.maxX &&
                          (($0.anchorY < label.anchor.y && $0.frame.midY > frame.midY) ||
                           ($0.anchorY > label.anchor.y && $0.frame.midY < frame.midY))
                      }),
                      !occupied.contains(where: { $0.intersects(frame.insetBy(dx: -2, dy: -1)) }) else { continue }
                result[label.id] = option
                occupied.append(frame)
                placedLabels.append((frame, label.anchor.y))
                break
            }
            if result[label.id] == nil && featured.contains(label.id) {
                // Keep featured names visible even when the chart is exceptionally dense.
                let x = min(area.maxX - label.frame.width, max(area.minX, label.anchor.x + right))
                let y = min(area.maxY - label.frame.height, max(area.minY, label.anchor.y + naturalY))
                result[label.id] = CGSize(width: x - label.anchor.x, height: y - label.anchor.y)
                let frame = CGRect(x: x, y: y, width: label.frame.width, height: label.frame.height)
                occupied.append(frame)
                placedLabels.append((frame, label.anchor.y))
            }
        }
        return result
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

    private func measuredLabelWidth(_ text: String) -> CGFloat {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width) + 4
        #elseif canImport(UIKit)
        let font = UIFont.systemFont(ofSize: 14, weight: .medium)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width) + 4
        #else
        return ceil(CGFloat(text.count) * 8) + 4
        #endif
    }

    private func measuredLabelHeight() -> CGFloat {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        return ceil(font.ascender - font.descender + font.leading)
        #elseif canImport(UIKit)
        return ceil(UIFont.systemFont(ofSize: 14, weight: .medium).lineHeight)
        #else
        return 17
        #endif
    }

    private func visibleBounds(_ base: ClosedRange<Double>, offset: CGFloat,
                               axisLength: CGFloat, inverted: Bool, trailingMargin: CGFloat = 0) -> ClosedRange<Double> {
        guard axisLength > 0 else { return base }
        let baseSpan = base.upperBound - base.lowerBound
        let span = baseSpan / scale
        let direction = inverted ? -1.0 : 1.0
        let baseCenter = (base.upperBound + base.lowerBound) / 2
        let center = baseCenter + direction * Double(offset / axisLength) * span
        let extraSpan = Double(trailingMargin / axisLength) * span
        let lowerBound = min(base.upperBound - span + extraSpan, max(base.lowerBound, center - span / 2))
        return lowerBound...(lowerBound + span)
    }
}

private struct ChartLabelPlacement: Identifiable {
    let id: String
    let name: String
    let radius: CGFloat
    let anchor: CGPoint
    var frame: CGRect
}

private struct LabelLayoutKey: Equatable {
    let plotRect: CGRect
    let offset: CGSize
    let scale: CGFloat
    let xBounds: ClosedRange<Double>
    let yBounds: ClosedRange<Double>
    let maxSpeed: Double
    let interacting: Bool
    let models: [String]
}
