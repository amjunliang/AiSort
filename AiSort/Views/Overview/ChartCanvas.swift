import SwiftUI

struct ChartCanvas: View {
    private let chartPadding: CGFloat = 20
    let models: [AIModel]
    let scaleModels: [AIModel]
    let favoriteModelIDs: Set<String>
    @Binding var highlighted: AIModel?
    @Binding var focusRequest: String?
    @Binding var offset: CGSize
    @Binding var scale: CGFloat
    @Binding var isZooming: Bool
    let toggleFavorite: (AIModel) -> Void
    let showDetail: (AIModel) -> Void
    @State private var dragOrigin: CGSize?
    @State private var zoomOrigin: (CGFloat, CGSize)?

    var body: some View {
        GeometryReader { geometry in
            let metrics = ChartMetrics(models: scaleModels, viewportSize: geometry.size)
            ZStack {
                BubbleChart(models: models, metrics: metrics, favoriteModelIDs: favoriteModelIDs,
                            highlighted: $highlighted,
                            focusRequest: $focusRequest, offset: $offset, scale: scale,
                            isInteracting: dragOrigin != nil || zoomOrigin != nil,
                            toggleFavorite: toggleFavorite,
                            showDetail: showDetail)
                    .padding(.vertical, chartPadding)
                    .padding(.horizontal, 6)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .simultaneousGesture(scale > 1 ? DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard zoomOrigin == nil else { return }
                            if dragOrigin == nil { dragOrigin = offset }
                            if let start = dragOrigin {
                                let proposed = CGSize(width: start.width + value.translation.width,
                                                      height: start.height + value.translation.height)
                                offset = metrics.boundedOffset(proposed, scale: scale)
                            }
                        }.onEnded { _ in dragOrigin = nil } : nil)
                    .highPriorityGesture(MagnifyGesture(minimumScaleDelta: 0.01)
                        .onChanged { value in
                            if zoomOrigin == nil {
                                zoomOrigin = (scale, offset)
                                dragOrigin = nil
                                isZooming = true
                            }
                            guard let start = zoomOrigin else { return }
                            let next = min(5, max(1, start.0 * value.magnification))
                            guard next != scale else { return }
                            let anchor = CGPoint(x: (value.startAnchor.x - 0.5) * geometry.size.width, y: (value.startAnchor.y - 0.5) * geometry.size.height)
                            let ratio = next / start.0
                            let proposed = CGSize(width: anchor.x - (anchor.x - start.1.width) * ratio, height: anchor.y - (anchor.y - start.1.height) * ratio)
                            offset = metrics.boundedOffset(proposed, scale: next)
                            scale = next
                        }.onEnded { _ in
                            zoomOrigin = nil
                            dragOrigin = nil
                            isZooming = false
                        })

                TrackpadPanReader(isEnabled: scale > 1) { delta in
                    let proposed = CGSize(width: offset.width + delta.width, height: offset.height + delta.height)
                    offset = metrics.boundedOffset(proposed, scale: scale)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }.padding(.horizontal, 12)
    }
}
