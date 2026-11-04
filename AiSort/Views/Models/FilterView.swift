import SwiftUI

struct FilterView: View {
    @ObservedObject var store: ModelController
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private var matchingCreators: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.creators.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索厂商", text: $search)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("搜索厂商")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("清除搜索")
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16).padding(.top, 12)

                HStack {
                    Text("已选择 \(store.selectedCreators.count) / \(store.creators.count)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button("全选") { store.selectAll() }
                        .disabled(store.creators.isEmpty || store.selectedCreators.count == store.creators.count)
                    Button("清除") { store.clearSelection() }
                        .disabled(store.selectedCreators.isEmpty)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 16).padding(.vertical, 12)

                if matchingCreators.isEmpty {
                    ContentUnavailableView.search(text: search)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(matchingCreators, id: \.self) { creator in
                                Button { store.toggleCreator(creator) } label: {
                                    HStack {
                                        Circle().fill(creatorColor(creator)).frame(width: 10, height: 10)
                                        Text(creator).foregroundStyle(.primary)
                                        Spacer()
                                        if store.selectedCreators.contains(creator) {
                                            Image(systemName: "checkmark").foregroundStyle(teal)
                                        }
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                    .accessibilityValue(store.selectedCreators.contains(creator) ? "已选择" : "未选择")
                            }
                        } header: {
                            Text(search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "厂商" : "搜索结果 · \(matchingCreators.count)")
                        }
                    }.listStyle(.plain)
                }
            }
            .navigationTitle("筛选厂商")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 320, minHeight: 400)
    }
}
