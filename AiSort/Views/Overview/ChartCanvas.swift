import SwiftUI

struct ChartCanvas: View {
    let models: [AIModel]
    @Binding var highlighted: AIModel?
    @Binding var focusRequest: String?
    @Binding var offset: CGSize
    @Binding var scale: CGFloat
    @State private var dragOrigin: CGSize?
    @State private var zoomOrigin: (CGFloat, CGSize)?

    var body: some View {
        GeometryReader { geometry in
            BubbleChart(models: models, highlighted: $highlighted, focusRequest: $focusRequest, offset: $offset, scale: scale)
                .padding(20)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
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
        }.background(.white, in: RoundedRectangle(cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 12)
    }
    private func bounded(_ value: CGSize, size: CGSize, scale: CGFloat) -> CGSize {
        let x = size.width * (scale - 1) / 2, y = size.height * (scale - 1) / 2
        return CGSize(width: min(x, max(-x, value.width)), height: min(y, max(-y, value.height)))
    }
}
