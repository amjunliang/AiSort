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
    @State private var showModels = false
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var focusRequest: String?

    private var plotted: [AIModel] { store.filtered.filter(\.isPlottable) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OverviewToolbar(store: store, showModels: { showModels = true },
                                showFilters: { showFilters = true }, showSettings: { showSettings = true })
                GeometryReader { geometry in
                    if store.hasKey {
                        scrollContent(minHeight: geometry.size.height)
                            .refreshable { await store.refresh() }
                    } else {
                        scrollContent(minHeight: geometry.size.height)
                    }
                }
                if store.updatedAt != nil {
                    ChartControls(hasModels: !plotted.isEmpty,
                                  creators: store.creators.filter { store.selectedCreators.contains($0) },
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
                        ModelListView(models: store.filtered, search: $search, sort: $sort, selectModel: selectModel)
                            .padding()
                    }
                        .navigationTitle("模型列表")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showModels = false } } }
                }.frame(minWidth: 320, minHeight: 400)
            }
            .sheet(item: $selected) { ModelDetail(model: $0, version: store.indexVersion) }
            .onChange(of: store.selectedCreators) { _, _ in resetCanvas() }
            .onChange(of: store.updatedAt) { _, _ in resetCanvas() }
            .task { if store.hasKey && store.updatedAt == nil { await store.refresh() } }
        }.tint(teal).font(.appBody).preferredColorScheme(.light)
    }

    private func scrollContent(minHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if let error = store.error {
                    ErrorBanner(text: error, canRetry: store.hasKey && !store.isLoading, retry: refresh).padding(.horizontal, 16).padding(.top, 10)
                }
                if store.updatedAt != nil {
                    OverviewHeader(count: plotted.count, updatedAt: store.updatedAt)
                    if plotted.isEmpty {
                        ContentUnavailableView {
                            Label("暂无可绘制的模型", systemImage: "chart.xyaxis.line")
                        } description: {
                            Text(store.selectedCreators.isEmpty ? "选择厂商后，即可在这里比较模型。" : "当前厂商没有完整的图表指标。")
                        } actions: {
                            Button("选择厂商") { showFilters = true }.buttonStyle(.borderedProminent)
                            if !store.selectedCreators.isEmpty {
                                Button("查看模型列表") { showModels = true }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ChartCanvas(models: plotted, highlighted: $highlighted, focusRequest: $focusRequest,
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
