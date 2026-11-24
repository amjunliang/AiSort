import SwiftUI

struct ChartControls: View {
    @Environment(\.colorScheme) private var colorScheme
    let hasMissingPrices: Bool
    let creators: [String]
    let selectedCreator: String?
    let toggleCreator: (String) -> Void
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let resetCanvas: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    bubbleHint
                    Spacer(minLength: 8)
                    zoomControls
                }
                VStack(alignment: .leading, spacing: 8) {
                    bubbleHint
                    zoomControls
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if creators.isEmpty {
                        Text(" ").font(.appCaption2).padding(.vertical, 6).hidden()
                    } else {
                        ForEach(creators, id: \.self) { creator in
                            let color = creatorColor(creator, in: colorScheme)
                            let isSelected = creator == selectedCreator
                            Button { toggleCreator(creator) } label: {
                                HStack(spacing: 5) {
                                    Circle().fill(color).frame(width: 7, height: 7)
                                    Text(creator).font(.appCaption2).lineLimit(1)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .background(isSelected ? color.opacity(0.16) : .clear, in: Capsule())
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                            .help(isSelected ? "显示所有厂商" : "只看 \(creator)")
                        }
                    }
                }
            }
            Text("混合单价按输入∶输出 3∶1 计算 · 价格轴对数压缩\n数据来源：Artificial Analysis")
                .font(.appCaption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 12)
    }

    private var bubbleHint: some View {
        Label(hasMissingPrices ? "气泡越大，输出越快\n空心圆表示暂无报价" : "气泡越大，输出越快",
              systemImage: "circle.dotted.circle")
            .font(.appCaption).foregroundStyle(.secondary)
            .fixedSize()
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                Button { withAnimation(.easeInOut(duration: 0.2)) { scale = max(1, scale / 1.25); offset = .zero } } label: {
                    Image(systemName: "minus").frame(width: 36, height: 36)
                }.disabled(scale <= 1).accessibilityLabel("缩小")
                Text("\(Int(scale * 100))%")
                    .font(.appCaption.monospacedDigit()).frame(minWidth: 42)
                    .accessibilityLabel("缩放 \(Int(scale * 100)) 百分比")
                Button { withAnimation(.easeInOut(duration: 0.2)) { scale = min(5, scale * 1.25) } } label: {
                    Image(systemName: "plus").frame(width: 36, height: 36)
                }.disabled(scale >= 5).accessibilityLabel("放大")
            }.buttonStyle(.plain).background(appSurface, in: Capsule())
            Button { withAnimation(.easeInOut(duration: 0.2)) { resetCanvas() } } label: {
                Image(systemName: "arrow.counterclockwise").frame(width: 36, height: 36)
            }.buttonStyle(.plain).background(appSurface, in: Circle()).accessibilityLabel("重置图表")
        }
        .fixedSize()
    }
}
