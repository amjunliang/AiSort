import SwiftUI

struct WelcomeView: View {
    let hasKey: Bool
    let refresh: () -> Void
    let showSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 28, weight: .medium)).foregroundStyle(teal)
                .frame(width: 60, height: 60)
                .background(teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 8) {
                Text("找到适合你的 AI 模型").font(.title2.bold()).foregroundStyle(ink)
                Text("在一张图中比较模型的智力、价格和速度，快速发现值得关注的选择。")
                    .font(.appSubheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Label("连接 Artificial Analysis 数据", systemImage: "link")
                Label("API Key 安全保存在设备钥匙串中", systemImage: "lock.shield")
            }.font(.appCaption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                if hasKey {
                    Button(action: refresh) {
                        Label("重试获取数据", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    Button("检查 API Key 设置") { showSettings() }.font(.appSubheadline)
                } else {
                    Button { showSettings() } label: {
                        Label("设置 API Key", systemImage: "key.horizontal").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    Link("获取 Artificial Analysis API Key ↗", destination: URL(string: "https://artificialanalysis.ai/data-api")!).font(.appSubheadline)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }
}
