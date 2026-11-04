import SwiftUI

struct ModelListView: View {
    let models: [AIModel]
    @Binding var search: String
    @Binding var sort: ModelSort
    let selectModel: (AIModel) -> Void

    private var visibleModels: [AIModel] {
        models.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.modelCreator.name.localizedCaseInsensitiveContains(search) }
            .sorted { sort.precedes($0, $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("模型列表").font(.title3.bold()).foregroundStyle(ink)
                    Text("查看全部数据，包括指标尚不完整的模型").font(.appCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(visibleModels.count)").font(.appSubheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索模型或厂商", text: $search).textFieldStyle(.plain)
                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
            }.padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Text("排序方式").font(.appCaption).foregroundStyle(.secondary)
                Spacer()
                Picker("排序方式", selection: $sort) {
                    ForEach(ModelSort.allCases) { option in Text(option.rawValue).tag(option) }
                }.labelsHidden()
            }
            if visibleModels.isEmpty {
                ContentUnavailableView {
                    Label("没有匹配的模型", systemImage: "magnifyingglass")
                } description: {
                    Text(search.isEmpty ? "请先选择厂商。" : "试试其他模型名称或厂商。")
                } actions: {
                    if !search.isEmpty { Button("清除搜索") { search = "" } }
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(visibleModels) { model in
                        Button {
                            selectModel(model)
                        } label: { ModelRow(model: model) }.buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }.card()
    }
}
