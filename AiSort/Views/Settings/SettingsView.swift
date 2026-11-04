import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ModelController
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Artificial Analysis API Key") {
                    SecureField(store.hasKey ? "输入新密钥以替换" : "输入 API Key", text: $key)
                        #if os(iOS)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        #endif
                    Text("密钥保存在设备的系统钥匙串中，并直接发送至 Artificial Analysis。")
                        .font(.caption).foregroundStyle(.secondary)
                    Link("获取 API Key", destination: URL(string: "https://artificialanalysis.ai/data-api")!)
                }
                Section {
                    Button("保存并刷新") { let value = key; key = ""; Task { await store.saveKey(value) } }
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading)
                    if store.hasKey { Button("删除已保存的密钥", role: .destructive) { store.deleteKey(); key = "" } }
                }
                if let error = store.error { Section { Text(error).foregroundStyle(.orange) } }
                if store.isLoading { ProgressView("正在获取模型数据…") }
            }.formStyle(.grouped).navigationTitle("设置")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 320, minHeight: 400)
    }
}
