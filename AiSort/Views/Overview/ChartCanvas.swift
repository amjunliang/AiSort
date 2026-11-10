import SwiftUI

struct ChartCanvas: View {
    private let chartPadding: CGFloat = 20
    let models: [AIModel]
    let scaleModels: [AIModel]
    @Binding var highlighted: AIModel?
    @Binding var focusRequest: String?
    @Binding var offset: CGSize
    @Binding var scale: CGFloat
    let showDetail: (AIModel) -> Void
    @State private var dragOrigin: CGSize?
    @State private var zoomOrigin: (CGFloat, CGSize)?
    private var labelPanAllowance: CGFloat {
        guard scale >= 1.5 else { return 0 }
        // Reserve enough room for a full model name and the bubble beside it.
        return CGFloat(scaleModels.map { $0.name.count }.max() ?? 0) * 14 + 40
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BubbleChart(models: models, scaleModels: scaleModels, highlighted: $highlighted,
                            focusRequest: $focusRequest, offset: $offset, scale: scale,
                            viewportSize: geometry.size,
                            extraHorizontalPan: labelPanAllowance,
                            isInteracting: dragOrigin != nil || zoomOrigin != nil,
                            showDetail: showDetail)
                    .padding(.vertical, chartPadding)
                    .padding(.horizontal, 6)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .highPriorityGesture(scale > 1 ? DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard zoomOrigin == nil else { return }
                            if dragOrigin == nil { dragOrigin = offset }
                            if let start = dragOrigin {
                                offset = bounded(CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height), size: geometry.size, scale: scale)
                            }
                        }.onEnded { _ in dragOrigin = nil } : nil)
                    .simultaneousGesture(MagnifyGesture()
                        .onChanged { value in
                            if zoomOrigin == nil { zoomOrigin = (scale, offset); dragOrigin = nil }
                            guard let start = zoomOrigin else { return }
                            let next = min(5, max(1, start.0 * value.magnification))
                            let anchor = CGPoint(x: (value.startAnchor.x - 0.5) * geometry.size.width, y: (value.startAnchor.y - 0.5) * geometry.size.height)
                            let ratio = next / start.0
                            let proposed = CGSize(width: anchor.x - (anchor.x - start.1.width) * ratio, height: anchor.y - (anchor.y - start.1.height) * ratio)
                            offset = bounded(proposed, size: geometry.size, scale: next)
                            scale = next
                        }.onEnded { _ in zoomOrigin = nil; dragOrigin = nil })

                TrackpadPanReader(isEnabled: scale > 1) { delta in
                    offset = bounded(CGSize(width: offset.width + delta.width,
                                            height: offset.height + delta.height),
                                     size: geometry.size, scale: scale)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)


            }
        }.padding(.horizontal, 12)
    }

    private func bounded(_ value: CGSize, size: CGSize, scale: CGFloat) -> CGSize {
        let x = size.width * (scale - 1) / 2, y = size.height * (scale - 1) / 2
        let extra = scale >= 1.5 ? CGFloat(scaleModels.map { $0.name.count }.max() ?? 0) * 14 + 40 : 0
        return CGSize(width: min(x, max(-x - extra, value.width)), height: min(y, max(-y, value.height)))
    }
}
