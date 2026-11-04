import SwiftUI

struct ChartControls: View {
    let hasModels: Bool
    let creators: [String]
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let resetCanvas: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("气泡越大，输出越快", systemImage: "circle.dotted.circle")
                    .font(.appCaption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
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
                }.buttonStyle(.plain).background(.white, in: Capsule())
                Button { withAnimation(.easeInOut(duration: 0.2)) { resetCanvas() } } label: {
                    Image(systemName: "arrow.counterclockwise").frame(width: 36, height: 36)
                }.buttonStyle(.plain).background(.white, in: Circle()).accessibilityLabel("重置图表")
            }
            if hasModels {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(creators, id: \.self) { creator in
                            HStack(spacing: 5) {
                                Circle().fill(creatorColor(creator)).frame(width: 7, height: 7)
                                Text(creator).font(.appCaption2).lineLimit(1)
                            }.padding(.vertical, 6)
                        }
                    }
                }
            }
            Text("混合单价按输入∶输出 3∶1 计算 · 价格轴对数压缩\n数据来源：Artificial Analysis")
                .font(.appCaption2).foregroundStyle(.secondary)
        }.padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 12)
    }

}
