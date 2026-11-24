import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ModelController
    @Binding var appearance: AppAppearance
    @State private var showSettings = false
    @State private var showFilters = false
    @State private var selected: AIModel?
    @State private var pendingDetail: AIModel?
    @State private var search = ""
    @State private var highlighted: AIModel?
    @State private var sort = ModelSort.intelligence
    @State private var showsChinaOnly = false
    @State private var showsFavoritesOnly = false
    @State private var chartCreator: String?
    @State private var showModels = false
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var isChartZooming = false
    @State private var focusRequest: String?

    private static let preferredLegendCreators = [
        "Google", "OpenAI", "Anthropic", "Alibaba", "DeepSeek", "Kimi", "MiniMax", "Z AI"
    ]

    private var regionFilteredModels: [AIModel] {
        showsChinaOnly ? store.filtered.filter { CreatorRegion.china.includes($0.modelCreator) } : store.filtered
    }
    private var availableEfforts: Set<ReasoningEffort> {
        Set(regionFilteredModels.lazy.filter(\.isPlottable).map(\.reasoningEffort))
    }
    private var selectedEffort: ReasoningEffort? {
        guard let effort = store.selectedReasoningEffort, availableEfforts.contains(effort) else { return nil }
        return effort
    }
    private var effortFilteredModels: [AIModel] {
        guard let effort = selectedEffort else { return regionFilteredModels }
        return regionFilteredModels.filter { $0.reasoningEffort == effort }
    }
    private var favoriteCountInScope: Int {
        effortFilteredModels.filter { store.isFavorite($0.id) }.count
    }
    private var modelsBeforeChartCreator: [AIModel] {
        showsFavoritesOnly ? effortFilteredModels.filter { store.isFavorite($0.id) } : effortFilteredModels
    }
    private var visibleModels: [AIModel] {
        let models = modelsBeforeChartCreator
        guard let chartCreator, models.contains(where: { $0.modelCreator.name == chartCreator && $0.isPlottable }) else {
            return models
        }
        return models.filter { $0.modelCreator.name == chartCreator }
    }
    private var plotted: [AIModel] { visibleModels.filter(\.isPlottable) }
    private var plottedCreators: [String] {
        let creators = Set(modelsBeforeChartCreator.lazy.filter(\.isPlottable).map(\.modelCreator.name))
        let preferred = Self.preferredLegendCreators.filter { creators.contains($0) }
        let others = creators.subtracting(preferred).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        return preferred + others
    }
    private var filterRules: [String] {
        var rules: [String] = []
        if showsChinaOnly { rules.append("只看中国") }
        if showsFavoritesOnly { rules.append("只看收藏") }
        if let selectedEffort { rules.append("思考档位 \(selectedEffort.rawValue)") }
        if let chartCreator { rules.append("图例厂商 \(chartCreator)") }
        if store.hasCreatorFilter {
            let creators = store.creators.filter { store.selectedCreators.contains($0) }
            rules.append(creators.isEmpty ? "未选择厂商" : "厂商 \(creators.joined(separator: "、"))")
        }
        if let minimum = store.scoreFilter.minimum { rules.append("智力 ≥ \(number(minimum, digits: 15))") }
        if let maximum = store.scoreFilter.maximum { rules.append("智力 ≤ \(number(maximum, digits: 15))") }
        return rules
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OverviewToolbar(store: store, showModels: { showModels = true },
                                showFilters: { showFilters = true }, showSettings: { showSettings = true })
                GeometryReader { geometry in
                    if store.hasKey {
                        scrollContent(minHeight: geometry.size.height)
                            .refreshable {
                                let request = Task { await store.refresh() }
                                await request.value
                            }
                    } else {
                        scrollContent(minHeight: geometry.size.height)
                    }
                }
                if store.updatedAt != nil {
                    ChartControls(hasMissingPrices: plotted.contains { $0.cost == nil },
                                  creators: plottedCreators, selectedCreator: chartCreator,
                                  toggleCreator: toggleChartCreator,
                                  scale: $scale, offset: $offset, resetCanvas: resetCanvas)
                        .background(appBackground)
                        .zIndex(1)
                }
            }
            .coordinateSpace(name: "overviewViewport")
            .background(appBackground.ignoresSafeArea())
            .toolbar(.hidden)
            .sheet(isPresented: $showSettings) {
                SettingsView(store: store, appearance: $appearance)
                    .preferredColorScheme(appearance.colorScheme)
            }
            .sheet(isPresented: $showFilters) { FilterView(store: store) }
            .sheet(isPresented: $showModels, onDismiss: {
                if let model = pendingDetail { selected = model; pendingDetail = nil }
            }) {
                NavigationStack {
                    ScrollView {
                        ModelListView(models: visibleModels, favoriteModelIDs: store.favoriteModelIDs,
                                      search: $search, sort: $sort, selectModel: selectModel)
                            .padding()
                    }
                        .navigationTitle("模型列表")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showModels = false } } }
                }.frame(minWidth: 320, minHeight: 400)
            }
            .sheet(item: $selected) { model in
                ModelDetail(model: model, version: store.indexVersion,
                            isFavorite: store.isFavorite(model.id),
                            toggleFavorite: { store.toggleFavorite(model.id) })
            }
            .onChange(of: store.canvasResetVersion) { _, _ in resetCanvas() }
            .onChange(of: showsChinaOnly) { _, _ in
                highlighted = nil
                focusRequest = nil
            }
            .onChange(of: showsFavoritesOnly) { _, _ in
                highlighted = nil
                focusRequest = nil
            }
            .onChange(of: store.favoriteModelIDs) { _, ids in
                if ids.isEmpty && showsFavoritesOnly {
                    showsFavoritesOnly = false
                }
                if showsFavoritesOnly, let current = highlighted, !ids.contains(current.id) {
                    highlighted = nil
                }
            }
            .onChange(of: selectedEffort) { _, _ in
                highlighted = nil
                focusRequest = nil
            }
            .onChange(of: plottedCreators) { _, creators in
                if let chartCreator, !creators.contains(chartCreator) {
                    self.chartCreator = nil
                }
            }
            .task {
                let request = Task { await store.refreshOnLaunch() }
                await request.value
            }
        }.tint(ink).font(.appBody)
    }

    private func scrollContent(minHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if let error = store.error {
                    ErrorBanner(text: error, canRetry: store.canRetry, retry: refresh).padding(.horizontal, 16).padding(.top, 10)
                }
                if let notice = store.notice {
                    RefreshNoticeBanner(text: notice, remaining: store.remainingQuotaText,
                                        canUpdate: store.hasKey && !store.isLoading,
                                        update: { Task { await store.forceRefresh() } },
                                        dismiss: store.dismissNotice)
                        .padding(.horizontal, 16).padding(.top, 10)
                }
                if store.updatedAt != nil {
                    let models = visibleModels
                    let chartModels = models.filter(\.isPlottable)
                    OverviewHeader(count: models.count, totalCount: store.models.count,
                                   favoriteCount: favoriteCountInScope, totalFavoriteCount: store.favoriteModelIDs.count,
                                   rateLimit: store.activeRateLimit,
                                   filterRules: filterRules, clearFilters: clearFilters,
                                   availableEfforts: availableEfforts,
                                   selectedEffort: selectedEffort,
                                   toggleEffort: store.toggleReasoningEffort,
                                   showsChinaOnly: $showsChinaOnly, showsFavoritesOnly: $showsFavoritesOnly)
                    if chartModels.isEmpty {
                        ContentUnavailableView {
                            Label("暂无可绘制的模型", systemImage: "chart.xyaxis.line")
                        } description: {
                            Text(models.isEmpty ? "当前筛选条件下没有模型。" : "当前模型缺少绘图所需的指标。")
                        } actions: {
                            Button("调整筛选") { showFilters = true }.buttonStyle(.borderedProminent).tint(ink).foregroundStyle(appBackground)
                            if !models.isEmpty {
                                Button("查看模型列表") { showModels = true }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ChartCanvas(models: chartModels, scaleModels: store.filtered.filter(\.isPlottable),
                                    favoriteModelIDs: store.favoriteModelIDs,
                                    highlighted: $highlighted, focusRequest: $focusRequest,
                                    offset: $offset, scale: $scale, isZooming: $isChartZooming,
                                    toggleFavorite: { store.toggleFavorite($0.id) },
                                    showDetail: { selected = $0 })
                            .frame(minHeight: max(280, minHeight * 0.5), maxHeight: .infinity)
                    }
                } else if store.isLoading {
                    ProgressView("正在获取模型数据…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WelcomeView(hasKey: store.hasKey, refresh: refresh, showSettings: { showSettings = true }).padding(20).frame(maxWidth: 540).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minHeight: minHeight, alignment: .top)
        }
        .scrollClipDisabled(highlighted != nil)
        .modifier(ChartScrollLock(scale: $scale, isZooming: $isChartZooming))
        .scrollBounceBehavior(plotted.isEmpty ? .always : .basedOnSize)
    }

    private func resetCanvas() { scale = 1; offset = .zero; highlighted = nil; focusRequest = nil }

    private func clearFilters() {
        showsChinaOnly = false
        showsFavoritesOnly = false
        chartCreator = nil
        highlighted = nil
        focusRequest = nil
        store.clearFilters()
    }

    private func toggleChartCreator(_ creator: String) {
        chartCreator = chartCreator == creator ? nil : creator
        highlighted = nil
        focusRequest = nil
    }

    private func refresh() {
        Task { await store.refresh() }
    }

    private func selectModel(_ model: AIModel) {
        if model.isPlottable {
            highlighted = model
            scale = max(scale, 2)
            focusRequest = model.id
        } else {
            pendingDetail = model
        }
        showModels = false
    }
}

private struct ChartScrollLock: ViewModifier {
    @Binding var scale: CGFloat
    @Binding var isZooming: Bool

    func body(content: Content) -> some View {
        content.scrollDisabled(isZooming || scale > 1)
    }
}
