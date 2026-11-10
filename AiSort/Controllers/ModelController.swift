import Foundation
import Combine

@MainActor
final class ModelController: ObservableObject {
    @Published var models: [AIModel] = []
    @Published var updatedAt: Date?
    @Published var indexVersion: Double?
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasKey = Keychain.read() != nil
    @Published var selectedCreators: Set<String> = []
    @Published private(set) var canvasResetVersion = 0
    private var allSelected: Bool
    private var didRefreshOnLaunch = false
    private var isSilentRefresh = false
    private let filterKey = "creatorFilterSelection"
    private var generation = 0
    private let api: ModelAPI
    private let cacheStore: ModelCacheStore
    private let defaults: UserDefaults
    var showsLoadingIndicator: Bool { isLoading && !isSilentRefresh }
    var creators: [String] { Array(Set(models.map { $0.modelCreator.name })).sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    var filtered: [AIModel] { models.filter { selectedCreators.contains($0.modelCreator.name) } }
    init(api: ModelAPI? = nil, cacheStore: ModelCacheStore? = nil, defaults: UserDefaults = .standard) {
        self.api = api ?? ModelAPI()
        self.cacheStore = cacheStore ?? ModelCacheStore()
        self.defaults = defaults
        self.allSelected = defaults.object(forKey: "creatorFilterAll") as? Bool ?? true
        selectedCreators = Set(defaults.stringArray(forKey: filterKey) ?? [])
        loadCache()
        if allSelected {
            selectedCreators = Set(creators)
        } else if updatedAt != nil {
            selectedCreators.formIntersection(creators)
            saveFilter()
        }
    }
    private func saveFilter() {
        defaults.set(allSelected, forKey: "creatorFilterAll")
        if !allSelected { defaults.set(Array(selectedCreators), forKey: filterKey) }
    }
    func selectAll() { allSelected = true; selectedCreators = Set(creators); saveFilter(); canvasResetVersion += 1 }
    func clearSelection() { allSelected = false; selectedCreators = []; saveFilter(); canvasResetVersion += 1 }
    func toggleCreator(_ creator: String) {
        if selectedCreators.contains(creator) { selectedCreators.remove(creator) } else { selectedCreators.insert(creator) }
        allSelected = Set(creators).isSubset(of: selectedCreators) && !creators.isEmpty
        saveFilter()
        canvasResetVersion += 1
    }
    func saveKey(_ value: String) async {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { error = "请输入 API Key。"; return }
        do { try Keychain.save(key); hasKey = true; await refresh() } catch { self.error = error.localizedDescription }
    }
    func deleteKey() {
        do { try Keychain.delete(); generation += 1; isLoading = false; hasKey = false; error = nil } catch { self.error = error.localizedDescription }
    }
    func refreshOnLaunch() async {
        guard !didRefreshOnLaunch, hasKey else { return }
        didRefreshOnLaunch = true
        await refresh(silently: updatedAt != nil)
    }
    func refresh(silently: Bool = false) async {
        guard !isLoading, let key = Keychain.read(), !key.isEmpty else { return }
        generation += 1
        let requestGeneration = generation
        isSilentRefresh = silently
        isLoading = true
        error = nil
        defer { if generation == requestGeneration { isLoading = false } }
        do {
            let cache = try await api.fetchModels(key: key)
            guard generation == requestGeneration else { return }
            models = cache.models; updatedAt = cache.updatedAt; indexVersion = cache.indexVersion
            if allSelected {
                selectedCreators = Set(creators)
            } else {
                selectedCreators.formIntersection(creators)
                saveFilter()
            }
            if !silently { canvasResetVersion += 1 }
            do {
                try cacheStore.save(cache)
            } catch {
                if !silently { self.error = "数据已更新，但无法保存离线缓存。" }
            }
        } catch {
            guard generation == requestGeneration, !silently, !Task.isCancelled, !(error is CancellationError) else { return }
            if error is DecodingError { self.error = "数据格式无法解析，请稍后重试。" }
            else if let failure = error as? ModelAPI.FetchError { self.error = failure.localizedDescription }
            else { self.error = "网络连接失败，请检查网络后重试。" }
        }
    }
    private func loadCache() {
        guard let cache = cacheStore.load() else { return }
        models = cache.models; updatedAt = cache.updatedAt; indexVersion = cache.indexVersion
    }
}
