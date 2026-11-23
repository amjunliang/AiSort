import Foundation
import Combine

@MainActor
final class ModelController: ObservableObject {
    struct ScoreFilter: Equatable {
        var minimum: Double?
        var maximum: Double?

        var isActive: Bool { minimum != nil || maximum != nil }

        func includes(_ score: Double?) -> Bool {
            guard isActive else { return true }
            guard let score, score.isFinite else { return false }
            return score >= (minimum ?? -.infinity) && score <= (maximum ?? .infinity)
        }
    }

    @Published var models: [AIModel] = []
    @Published var updatedAt: Date?
    @Published var indexVersion: Double?
    @Published var isLoading = false
    @Published var error: String?
    /// 冷却期提示：可关闭，也可以选择仍然更新。
    @Published var notice: String?
    @Published var hasKey: Bool
    @Published var selectedCreators: Set<String> = []
    @Published private(set) var favoriteModelIDs: Set<String> = []
    @Published private(set) var selectedReasoningEffort: ReasoningEffort?
    @Published private(set) var scoreFilter = ScoreFilter()
    @Published private(set) var canvasResetVersion = 0
    @Published private(set) var rateLimit: RateLimit?
    private(set) var pagesPerRefresh: Int?
    private var allSelected: Bool
    private var didRefreshOnLaunch = false
    private var isSilentRefresh = false
    private let filterKey = "creatorFilterSelection"
    private let favoritesKey = "favoriteModelIDs"
    private let reasoningEffortKey = "reasoningEffortFilter"
    private let scoreFilterKey = "intelligenceScoreFilter"
    private var generation = 0
    private let api: ModelAPI
    private let cacheStore: ModelCacheStore
    private let defaults: UserDefaults
    private let policy: RefreshPolicy
    private let now: () -> Date
    private let readKey: @MainActor () -> String?
    private let rateLimitKey = "apiRateLimit"
    private let pagesKey = "apiPagesPerRefresh"
    var showsLoadingIndicator: Bool { isLoading && !isSilentRefresh }
    var hasCreatorFilter: Bool { !allSelected }
    var creators: [String] { Array(Set(models.map { $0.modelCreator.name })).sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    var filtered: [AIModel] {
        models.filter { selectedCreators.contains($0.modelCreator.name) && scoreFilter.includes($0.intelligence) }
    }
    init(api: ModelAPI? = nil, cacheStore: ModelCacheStore? = nil, defaults: UserDefaults = .standard,
         policy: RefreshPolicy? = nil, now: @escaping () -> Date = Date.init,
         readKey: @escaping @MainActor () -> String? = Keychain.read) {
        self.api = api ?? ModelAPI()
        self.cacheStore = cacheStore ?? ModelCacheStore()
        self.defaults = defaults
        self.policy = policy ?? RefreshPolicy()
        self.now = now
        self.readKey = readKey
        hasKey = readKey() != nil
        rateLimit = defaults.data(forKey: rateLimitKey).flatMap { try? JSONDecoder().decode(RateLimit.self, from: $0) }
        pagesPerRefresh = defaults.object(forKey: pagesKey) as? Int
        self.allSelected = defaults.object(forKey: "creatorFilterAll") as? Bool ?? true
        selectedCreators = Set(defaults.stringArray(forKey: filterKey) ?? [])
        favoriteModelIDs = Set(defaults.stringArray(forKey: favoritesKey) ?? [])
        let savedEfforts = (defaults.stringArray(forKey: reasoningEffortKey) ?? [])
            .compactMap(ReasoningEffort.init(rawValue:))
        selectedReasoningEffort = savedEfforts.count == 1 ? savedEfforts.first : nil
        let scoreBounds = defaults.dictionary(forKey: scoreFilterKey)
        scoreFilter = ScoreFilter(minimum: scoreBounds?["minimum"] as? Double, maximum: scoreBounds?["maximum"] as? Double)
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
    func setScoreFilter(_ filter: ScoreFilter, resetsCanvas: Bool = true) {
        guard scoreFilter != filter else { return }
        scoreFilter = filter
        let bounds = ["minimum": filter.minimum, "maximum": filter.maximum].compactMapValues { $0 }
        defaults.set(bounds, forKey: scoreFilterKey)
        if resetsCanvas { canvasResetVersion += 1 }
    }
    func selectAll(resetsCanvas: Bool = true) {
        allSelected = true
        selectedCreators = Set(creators)
        saveFilter()
        if resetsCanvas { canvasResetVersion += 1 }
    }
    func clearSelection() { allSelected = false; selectedCreators = []; saveFilter(); canvasResetVersion += 1 }
    func toggleCreator(_ creator: String) {
        if selectedCreators.contains(creator) { selectedCreators.remove(creator) } else { selectedCreators.insert(creator) }
        allSelected = Set(creators).isSubset(of: selectedCreators) && !creators.isEmpty
        saveFilter()
        canvasResetVersion += 1
    }
    func isFavorite(_ modelID: String) -> Bool {
        favoriteModelIDs.contains(modelID)
    }
    func toggleFavorite(_ modelID: String) {
        if favoriteModelIDs.contains(modelID) {
            favoriteModelIDs.remove(modelID)
        } else {
            favoriteModelIDs.insert(modelID)
        }
        defaults.set(Array(favoriteModelIDs).sorted(), forKey: favoritesKey)
    }
    func toggleReasoningEffort(_ effort: ReasoningEffort) {
        selectedReasoningEffort = selectedReasoningEffort == effort ? nil : effort
        defaults.set(selectedReasoningEffort.map { [$0.rawValue] } ?? [], forKey: reasoningEffortKey)
    }
    func clearFilters() {
        selectAll(resetsCanvas: false)
        setScoreFilter(ScoreFilter(), resetsCanvas: false)
        if let selectedReasoningEffort {
            toggleReasoningEffort(selectedReasoningEffort)
        }
    }
    func saveKey(_ value: String) async {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { error = "请输入 API Key。"; return }
        do { try Keychain.save(key); hasKey = true; await refresh(respectsCooldown: false) } catch { self.error = error.localizedDescription }
    }
    func deleteKey() {
        do { try Keychain.delete(); generation += 1; isLoading = false; hasKey = false; error = nil } catch { self.error = error.localizedDescription }
    }
    /// 当前额度窗口内的剩余次数，窗口已过期时为 nil。
    var activeRateLimit: RateLimit? { rateLimit.flatMap { $0.isActive(at: now()) ? $0 : nil } }
    /// 现在不能发请求的原因（额度不足或刚刷新过），nil 表示可以刷新。
    var refreshBlockReason: String? {
        policy.blockReason(updatedAt: updatedAt, rateLimit: rateLimit, pagesNeeded: pagesPerRefresh ?? 1, now: now())
    }
    var canRetry: Bool { hasKey && !isLoading && refreshBlockReason == nil }
    /// “仍然更新”按钮上的剩余额度说明，额度未知时为 nil。
    var remainingQuotaText: String? {
        activeRateLimit.map { "剩余 \($0.remaining) 次 · 本次约用 \(pagesPerRefresh ?? 1) 次" }
    }
    func dismissNotice() { notice = nil }
    /// 忽略冷却期立即更新；额度不足时仍会拦截。
    func forceRefresh() async { await refresh(respectsCooldown: false) }
    func refreshOnLaunch() async {
        guard !didRefreshOnLaunch, hasKey else { return }
        didRefreshOnLaunch = true
        guard policy.shouldRefreshOnLaunch(updatedAt: updatedAt, now: now()) else { return }
        await refresh(silently: updatedAt != nil)
    }
    func refresh(silently: Bool = false, respectsCooldown: Bool = true) async {
        guard !isLoading, let key = readKey(), !key.isEmpty else { return }
        if let block = policy.block(updatedAt: updatedAt, rateLimit: rateLimit, pagesNeeded: pagesPerRefresh ?? 1,
                                    now: now(), respectsCooldown: respectsCooldown) {
            guard !silently else { return }
            switch block {
            case .quota(let text): error = text; notice = nil
            case .cooldown(let text): notice = text; error = nil
            }
            return
        }
        notice = nil
        generation += 1
        let requestGeneration = generation
        isSilentRefresh = silently
        isLoading = true
        error = nil
        defer { if generation == requestGeneration { isLoading = false } }
        var metrics = ModelAPI.FetchMetrics()
        defer { record(metrics) }
        do {
            let cache = try await api.fetchModels(key: key, metrics: &metrics)
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
    private func record(_ metrics: ModelAPI.FetchMetrics) {
        if let limit = metrics.rateLimit, let data = try? JSONEncoder().encode(limit) {
            rateLimit = limit
            defaults.set(data, forKey: rateLimitKey)
        }
        if let pages = metrics.totalPages, pages > 0 {
            pagesPerRefresh = pages
            defaults.set(pages, forKey: pagesKey)
        }
    }
    private func loadCache() {
        guard let cache = cacheStore.load() else { return }
        models = cache.models; updatedAt = cache.updatedAt; indexVersion = cache.indexVersion
    }
}
