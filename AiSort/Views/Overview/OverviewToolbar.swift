import SwiftUI

struct OverviewToolbar: View {
    @ObservedObject var store: ModelController
    let showModels: () -> Void
    let showFilters: () -> Void
    let showSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(teal, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI SORT").font(.appSubheadline.bold()).tracking(0.8)
                    Text("模型探索").font(.appCaption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if store.updatedAt != nil {
                Button { showModels() } label: { Image(systemName: "magnifyingglass").frame(width: 32, height: 44) }
                    .accessibilityLabel("搜索模型")
                    .help("搜索模型")
                Button { showFilters() } label: {
                    Image(systemName: store.selectedCreators.count < store.creators.count ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .frame(width: 32, height: 44)
                }
                .accessibilityLabel("筛选厂商，已选择 \(store.selectedCreators.count) 个")
                .help("筛选厂商")
                Button { Task { await store.refresh() } } label: {
                    if store.isLoading { ProgressView().controlSize(.small).frame(width: 32, height: 44) }
                    else { Image(systemName: "arrow.clockwise").frame(width: 32, height: 44) }
                }.disabled(!store.hasKey || store.isLoading)
                    .accessibilityLabel("刷新数据").help("刷新数据")
            }
            Menu {
                Button { Task { await store.refresh() } } label: { Label("刷新数据", systemImage: "arrow.clockwise") }
                    .disabled(!store.hasKey || store.isLoading)
                Button { showSettings() } label: { Label("API Key 设置", systemImage: "gearshape") }
            } label: { Image(systemName: "ellipsis.circle").frame(width: 32, height: 44) }
                .accessibilityLabel("更多选项")
        }
        .font(.system(size: 19, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.white)
    }

}
