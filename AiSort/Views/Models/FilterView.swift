import SwiftUI

struct FilterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: ModelController
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var minimumScore: String
    @State private var maximumScore: String

    init(store: ModelController) {
        self.store = store
        _minimumScore = State(initialValue: store.scoreFilter.minimum.map { String($0) } ?? "")
        _maximumScore = State(initialValue: store.scoreFilter.maximum.map { String($0) } ?? "")
    }

    private var scoreFilter: ModelController.ScoreFilter {
        .init(minimum: parseScore(minimumScore), maximum: parseScore(maximumScore))
    }

    private func parseScore(_ input: String) -> Double? {
        let separator = Locale.current.decimalSeparator ?? "."
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(trimmed.replacingOccurrences(of: separator, with: "."))
    }

    private var scoreError: String? {
        let bounds = scoreFilter
        if (!minimumScore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bounds.minimum?.isFinite != true)
            || (!maximumScore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bounds.maximum?.isFinite != true) {
            return "请输入有效的分数。"
        }
        if let minimum = bounds.minimum, let maximum = bounds.maximum, minimum > maximum {
            return "最低分不能高于最高分。"
        }
        return nil
    }

    private var matchingCreators: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.creators.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scoreControls
                Divider()
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
                        .font(.appSubheadline).foregroundStyle(.secondary)
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
                                        Circle().fill(creatorColor(creator, in: colorScheme)).frame(width: 10, height: 10)
                                        Text(creator).foregroundStyle(.primary)
                                        Spacer()
                                        if store.selectedCreators.contains(creator) {
                                            Image(systemName: "checkmark").foregroundStyle(ink)
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
            .navigationTitle("筛选模型")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        store.setScoreFilter(scoreFilter)
                        dismiss()
                    }
                    .disabled(scoreError != nil)
                }
            }
        }.frame(minWidth: 320, minHeight: 400)
    }

    private var scoreControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("智力指数").font(.appSubheadline.bold())
                Spacer()
                Button("清除分数") {
                    minimumScore = ""
                    maximumScore = ""
                }
                .buttonStyle(.borderless)
                .disabled(minimumScore.isEmpty && maximumScore.isEmpty)
            }
            HStack(spacing: 8) {
                scoreField("最低分", text: $minimumScore)
                scoreField("最高分", text: $maximumScore)
            }
            if let scoreError {
                Text(scoreError).font(.appCaption2).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func scoreField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.appCaption2).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(title, text: text, prompt: Text("不限"))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
