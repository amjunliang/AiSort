import SwiftUI

struct ContentView: View {
    @StateObject private var store = ModelController()
    @State private var showSettings = false
    @State private var showFilters = false
    @State private var selected: AIModel?
    @State private var pendingDetail: AIModel?
    @State private var search = ""
    @State private var highlighted: AIModel?
    @State private var sort = ModelSort.intelligence
    @State private var showsChinaOnly = false
    @State private var showModels = false
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var focusRequest: String?

    private var visibleModels: [AIModel] {
        showsChinaOnly ? store.filtered.filter { CreatorRegion.china.includes($0.modelCreator) } : store.filtered
    }
    private var plotted: [AIModel] { visibleModels.filter(\.isPlottable) }

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
                    ChartControls(hasModels: !plotted.isEmpty,
                                  creators: Set(visibleModels.map(\.modelCreator.name)).sorted { $0.localizedStandardCompare($1) == .orderedAscending },
                                  scale: $scale, offset: $offset, resetCanvas: resetCanvas)
                        .background(Color(red: 0.965, green: 0.972, blue: 0.962))
                        .zIndex(1)
                }
            }
            .coordinateSpace(name: "overviewViewport")
            .background(Color(red: 0.965, green: 0.972, blue: 0.962).ignoresSafeArea())
            .toolbar(.hidden)
            .sheet(isPresented: $showSettings) { SettingsView(store: store) }
            .sheet(isPresented: $showFilters) { FilterView(store: store) }
            .sheet(isPresented: $showModels, onDismiss: {
                if let model = pendingDetail { selected = model; pendingDetail = nil }
            }) {
                NavigationStack {
                    ScrollView {
                        ModelListView(models: visibleModels, search: $search, sort: $sort, selectModel: selectModel)
                            .padding()
                    }
                        .navigationTitle("模型列表")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showModels = false } } }
                }.frame(minWidth: 320, minHeight: 400)
            }
            .sheet(item: $selected) { ModelDetail(model: $0, version: store.indexVersion) }
            .onChange(of: store.canvasResetVersion) { _, _ in resetCanvas() }
            .onChange(of: showsChinaOnly) { _, _ in
                highlighted = nil
                focusRequest = nil
            }
            .task {
                let request = Task { await store.refreshOnLaunch() }
                await request.value
            }
        }.tint(teal).font(.appBody).preferredColorScheme(.light)
    }

    private func scrollContent(minHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if let error = store.error {
                    ErrorBanner(text: error, canRetry: store.hasKey && !store.isLoading, retry: refresh).padding(.horizontal, 16).padding(.top, 10)
                }
                if store.updatedAt != nil {
                    OverviewHeader(count: visibleModels.count, updatedAt: store.updatedAt,
                                   showsChinaOnly: $showsChinaOnly)
                    if plotted.isEmpty {
                        ContentUnavailableView {
                            Label("暂无可绘制的模型", systemImage: "chart.xyaxis.line")
                        } description: {
                            Text(visibleModels.isEmpty ? "当前筛选条件下没有模型。" : "当前模型没有完整的图表指标。")
                        } actions: {
                            Button("选择厂商") { showFilters = true }.buttonStyle(.borderedProminent)
                            if !visibleModels.isEmpty {
                                Button("查看模型列表") { showModels = true }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ChartCanvas(models: plotted, scaleModels: store.filtered.filter(\.isPlottable),
                                    highlighted: $highlighted, focusRequest: $focusRequest,
                                    offset: $offset, scale: $scale, showDetail: { selected = $0 })
                            .frame(minHeight: max(280, minHeight * 0.5))
                    }
                } else if store.isLoading {
                    ProgressView("正在获取模型数据…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WelcomeView(hasKey: store.hasKey, refresh: refresh, showSettings: { showSettings = true }).padding(20).frame(maxWidth: 540).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minHeight: minHeight)
        }
        .scrollClipDisabled(highlighted != nil)
        .scrollBounceBehavior(.always)
    }

    private func resetCanvas() { scale = 1; offset = .zero; highlighted = nil }

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
