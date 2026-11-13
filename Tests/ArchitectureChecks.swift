import Foundation
import CoreGraphics

private func model(_ name: String, creator: String, score: Double?, input: Double?, output: Double?, speed: Double?) -> AIModel {
    AIModel(id: name, name: name, slug: name, releaseDate: nil, modelCreator: .init(id: creator, name: creator),
            evaluations: .init(artificialAnalysisIntelligenceIndex: score),
            pricing: .init(price1mInputTokens: input, price1mOutputTokens: output),
            performance: .init(medianOutputTokensPerSecond: speed))
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

private final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    static var headers: [String: String] = [:]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: Self.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@main
struct ArchitectureChecks {
    @MainActor static func main() async throws {
        let first = model("Alpha", creator: "OpenAI", score: 50, input: 2, output: 6, speed: 40)
        let second = model("Beta", creator: "Google", score: 40, input: 1, output: 1, speed: 80)
        let incomplete = model("Gamma", creator: "Google", score: nil, input: 0, output: 0, speed: 1)
        require(first.cost == 3, "3:1 price calculation changed")
        require(first.isPlottable && !incomplete.isPlottable, "Plot eligibility changed")
        let chinese = AIModel.Creator(id: "alibaba", name: "Alibaba")
        let unknown = AIModel.Creator(id: "unknown", name: "Unknown")
        require(CreatorRegion.china.includes(chinese) && !CreatorRegion.outsideChina.includes(chinese), "Chinese publisher misclassified")
        require(CreatorRegion.outsideChina.includes(first.modelCreator) && !CreatorRegion.china.includes(first.modelCreator), "Non-Chinese publisher misclassified")
        require(CreatorRegion.all.includes(unknown) && !CreatorRegion.china.includes(unknown) && !CreatorRegion.outsideChina.includes(unknown), "Unknown publisher should appear only in All")
        require([second, first, incomplete].sorted(by: ModelSort.intelligence.precedes).map(\.name) == ["Alpha", "Beta", "Gamma"], "Intelligence ordering changed")
        require([first, second].sorted(by: ModelSort.cost.precedes).map(\.name) == ["Beta", "Alpha"], "Cost ordering changed")
        require([first, second].sorted(by: ModelSort.speed.precedes).map(\.name) == ["Beta", "Alpha"], "Speed ordering changed")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cacheStore = ModelCacheStore(url: directory.appendingPathComponent("models.json"))
        let cache = ModelCache(models: [first, second, incomplete], updatedAt: Date(timeIntervalSince1970: 100), indexVersion: 4)
        let suiteName = "AiSort.ArchitectureChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suiteName)
        }
        try cacheStore.save(cache)
        require(cacheStore.load()?.models.count == 3, "Cache did not round trip")
        let controller = ModelController(cacheStore: cacheStore, defaults: defaults, readKey: { nil })
        require(controller.selectedCreators == Set(["OpenAI", "Google"]), "Initial selection changed")
        controller.clearSelection()
        require(controller.filtered.isEmpty, "Clear did not clear the filtered models")
        controller.toggleCreator("Google")
        require(controller.filtered.map(\.name) == ["Beta", "Gamma"], "Creator filtering changed")
        let restored = ModelController(cacheStore: cacheStore, defaults: defaults, readKey: { nil })
        require(restored.selectedCreators == ["Google"], "Selection was not persisted")
        restored.selectAll()
        require(restored.filtered.count == 3, "Select all did not select every model")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let api = ModelAPI(session: session)
        StubProtocol.handler = { request in
            require(request.value(forHTTPHeaderField: "x-api-key") == "test-key", "API key header missing")
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first!.value!
            let item = page == "1" ? first : second
            var jsonItem = try JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as! [String: Any]
            if page == "1" { jsonItem["release_date"] = "2025-08-11" }
            let response: [String: Any] = [
                "pagination": ["page": Int(page)!, "total_pages": 2, "has_more": page == "1"],
                "data": [jsonItem], "intelligence_index_version": 4
            ]
            return (200, try JSONSerialization.data(withJSONObject: response))
        }
        let fetched = try await api.fetchModels(key: "test-key")
        require(fetched.models.map(\.name) == ["Alpha", "Beta"], "API pagination changed")
        require(fetched.models.map(\.releaseDate) == ["2025-08-11", nil], "Release dates should decode when present")
        let releaseDateCache = ModelCacheStore(url: directory.appendingPathComponent("release-dates.json"))
        try releaseDateCache.save(fetched)
        require(releaseDateCache.load()?.models.map(\.releaseDate) == ["2025-08-11", nil], "Release dates should survive cache round trip")
        StubProtocol.handler = { _ in throw URLError(.cancelled) }
        do {
            _ = try await api.fetchModels(key: "test-key")
            fatalError("Cancelled request should throw")
        } catch is CancellationError {}
        StubProtocol.handler = { _ in throw URLError(.timedOut) }
        do {
            _ = try await api.fetchModels(key: "test-key")
            fatalError("Timed-out request should throw")
        } catch let error as ModelAPI.FetchError {
            require(error.localizedDescription.contains("第 1 页"), "Failed page missing")
            require(error.localizedDescription.contains("-1001"), "Network error code missing")
        }
        StubProtocol.handler = { _ in (401, Data()) }
        do {
            _ = try await api.fetchModels(key: "test-key")
            fatalError("Unauthorized API response should fail")
        } catch let error as ModelAPI.FetchError {
            require(error.localizedDescription.contains("API Key"), "Unexpected API error")
        }

        // 额度：读取响应头，失败时也保留已读到的值
        let resetTimestamp = 2_000_000_000.0
        StubProtocol.headers = ["X-RateLimit-Limit": "100", "X-RateLimit-Remaining": "42", "X-RateLimit-Reset": String(Int(resetTimestamp))]
        StubProtocol.handler = { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first!.value!
            let item = page == "1" ? first : second
            let jsonItem = try JSONSerialization.jsonObject(with: JSONEncoder().encode(item))
            let response: [String: Any] = [
                "pagination": ["page": Int(page)!, "total_pages": 2, "has_more": page == "1"],
                "data": [jsonItem], "intelligence_index_version": 4
            ]
            return (200, try JSONSerialization.data(withJSONObject: response))
        }
        var metrics = ModelAPI.FetchMetrics()
        _ = try await api.fetchModels(key: "test-key", metrics: &metrics)
        require(metrics.rateLimit == RateLimit(limit: 100, remaining: 42, resetAt: Date(timeIntervalSince1970: resetTimestamp)), "Rate limit headers not parsed")
        require(metrics.totalPages == 2, "Page count not recorded")
        StubProtocol.headers = ["Retry-After": "120"]
        StubProtocol.handler = { _ in (429, Data()) }
        var limited = ModelAPI.FetchMetrics()
        do {
            _ = try await api.fetchModels(key: "test-key", metrics: &limited)
            fatalError("429 should fail")
        } catch let error as ModelAPI.FetchError {
            require(error.localizedDescription.contains("额度已用完"), "429 message changed")
        }
        require(limited.rateLimit?.remaining == 0, "429 should record zero remaining")
        StubProtocol.headers = [:]

        // 刷新策略
        let policy = RefreshPolicy()
        let clock = Date(timeIntervalSince1970: 1_000_000)
        require(policy.shouldRefreshOnLaunch(updatedAt: nil, now: clock), "Empty cache must refresh on launch")
        require(!policy.shouldRefreshOnLaunch(updatedAt: clock.addingTimeInterval(-3_600), now: clock), "Fresh cache should not refresh on launch")
        require(policy.shouldRefreshOnLaunch(updatedAt: clock.addingTimeInterval(-7 * 3_600), now: clock), "Stale cache should refresh on launch")
        require(policy.blockReason(updatedAt: clock.addingTimeInterval(-60), rateLimit: nil, pagesNeeded: 4, now: clock) != nil, "Cooldown not applied")
        require(policy.blockReason(updatedAt: clock.addingTimeInterval(-60), rateLimit: nil, pagesNeeded: 4, now: clock, respectsCooldown: false) == nil, "Cooldown bypass broken")
        require(policy.blockReason(updatedAt: nil, rateLimit: .init(limit: 100, remaining: 3, resetAt: clock.addingTimeInterval(60)), pagesNeeded: 4, now: clock)?.contains("额度不足") == true, "Low quota not blocked")
        require(policy.blockReason(updatedAt: nil, rateLimit: .init(limit: 100, remaining: 3, resetAt: clock.addingTimeInterval(-60)), pagesNeeded: 4, now: clock) == nil, "Expired quota window should not block")

        // 额度信息持久化
        let quota = RateLimit(limit: 100, remaining: 2, resetAt: clock.addingTimeInterval(600))
        defaults.set(try JSONEncoder().encode(quota), forKey: "apiRateLimit")
        defaults.set(4, forKey: "apiPagesPerRefresh")
        let throttled = ModelController(cacheStore: cacheStore, defaults: defaults, now: { clock }, readKey: { "test-key" })
        require(throttled.activeRateLimit == quota && throttled.pagesPerRefresh == 4, "Quota not restored")
        require(throttled.refreshBlockReason?.contains("额度不足") == true && !throttled.canRetry, "Controller should block refresh on low quota")

        // 冷却期：显示可关闭的提示，“仍然更新”绕过冷却
        defaults.removeObject(forKey: "apiRateLimit")
        let justUpdated = Date(timeIntervalSince1970: 160)
        var requests = 0
        StubProtocol.headers = ["X-RateLimit-Limit": "100", "X-RateLimit-Remaining": "37", "X-RateLimit-Reset": "1000"]
        StubProtocol.handler = { _ in requests += 1; return (429, Data()) }
        let cooled = ModelController(api: api, cacheStore: cacheStore, defaults: defaults, now: { justUpdated }, readKey: { "test-key" })
        await cooled.refresh()
        require(cooled.notice?.contains("刚更新") == true && cooled.error == nil && requests == 0, "Cooldown should show a notice without requesting")
        cooled.dismissNotice()
        require(cooled.notice == nil, "Notice not dismissible")
        await cooled.refresh()
        await cooled.forceRefresh()
        require(requests == 1 && cooled.notice == nil, "Force refresh should bypass cooldown")
        require(cooled.activeRateLimit?.remaining == 0, "Quota not recorded after force refresh")
        StubProtocol.headers = [:]

        // 标签排布：支持左右两侧放置 + 显示区域整体分布，不压气泡、不重叠、细线不交叉
        let plotRect = CGRect(x: 50, y: 20, width: 650, height: 425)
        let labelHeight: CGFloat = 15
        func placement(_ id: String, x: CGFloat, score: Double, r: CGFloat, w: CGFloat) -> ChartLabelPlacement {
            let y = plotRect.minY + CGFloat(62.0 - score) * 15.2
            return ChartLabelPlacement(id: id, name: id, radius: r, anchor: CGPoint(x: x, y: y),
                                       frame: CGRect(x: x + r + 4, y: y - labelHeight / 2, width: w, height: labelHeight))
        }
        let cluster: [ChartLabelPlacement] = [
            placement("GPT-6.1 Terra · Max", x: 180, score: 51.3, r: 6, w: 116),
            placement("GPT-6.1 Terra · XHigh", x: 180, score: 45.3, r: 6, w: 124),
            placement("GPT-6.1 Terra · High", x: 180, score: 42.5, r: 6, w: 116),
            placement("GPT-6.1 Terra · Med", x: 180, score: 38.3, r: 6, w: 116),
            placement("Gemini 4 Hydrogen · XHigh", x: 320, score: 54.0, r: 11, w: 155),
            placement("Gemini 4 Hydrogen · High", x: 320, score: 50.8, r: 11, w: 148),
            placement("Gemini 4 Hydrogen · Med", x: 320, score: 41.2, r: 11, w: 148),
            placement("Gemini 4 Carbon · High", x: 425, score: 60.0, r: 7, w: 138),
            placement("Gemini 4 Carbon · Med", x: 425, score: 58.3, r: 7, w: 138),
            placement("GPT-6.1 Sol · Max", x: 425, score: 54.6, r: 6, w: 108),
            placement("Sonnet 5.5 · Max", x: 425, score: 54.5, r: 9, w: 105),
            placement("Gemini 4 Carbon · Low", x: 425, score: 54.4, r: 7, w: 136),
            placement("GPT-6.1 Sol · XHigh", x: 425, score: 52.5, r: 6, w: 116),
            placement("Gemini 4 Argon · High", x: 425, score: 50.3, r: 7, w: 132),
            placement("Sonnet 5.5 · XHigh", x: 425, score: 50.1, r: 9, w: 112),
            placement("GPT-6.1 Sol · High", x: 425, score: 50.0, r: 6, w: 105),
            placement("GPT-6.1 Sol · Med", x: 425, score: 46.3, r: 6, w: 105),
            placement("GPT-6 Sol · Max", x: 425, score: 44.3, r: 8, w: 98),
            placement("Sonnet 5.5 · High", x: 425, score: 41.5, r: 7, w: 105),
            placement("GPT-6.1 Sol · Low", x: 425, score: 35.0, r: 6, w: 105)
        ]
        let offsets = BubbleChart.resolveLabelOffsets(cluster, plotRect: plotRect, scale: 2.63, featured: ["Gemini 4 Carbon · High", "GPT-6.1 Sol · Low"])
        require(offsets.count == cluster.count, "All 20 cluster labels should fit when distributed holistically")
        let placed = cluster.compactMap { item -> (item: ChartLabelPlacement, frame: CGRect, spanMinX: CGFloat, spanMaxX: CGFloat)? in
            guard let offset = offsets[item.id] else { return nil }
            let frame = CGRect(x: item.anchor.x + offset.width, y: item.anchor.y + offset.height,
                               width: item.frame.width, height: item.frame.height)
            let onRight = frame.minX >= item.anchor.x + item.radius + 4
            let onLeft = frame.maxX <= item.anchor.x - item.radius - 4
            require(onRight || onLeft, "Label \(item.id) must not overlap its own bubble")
            for bubble in cluster {
                let bubbleBox = CGRect(x: bubble.anchor.x - bubble.radius, y: bubble.anchor.y - bubble.radius,
                                       width: bubble.radius * 2, height: bubble.radius * 2)
                require(!frame.intersects(bubbleBox), "Label \(item.id) overlaps bubble \(bubble.id)")
            }
            let spanMinX = onLeft ? frame.minX : item.anchor.x
            let spanMaxX = onLeft ? item.anchor.x : frame.maxX
            return (item, frame, spanMinX, spanMaxX)
        }
        require(placed.contains { $0.frame.maxX < $0.item.anchor.x }, "Dense cluster should use left side when helpful")
        for i in 0..<placed.count {
            for j in (i + 1)..<placed.count {
                let a = placed[i], b = placed[j]
                if max(a.frame.minX, b.frame.minX) < min(a.frame.maxX, b.frame.maxX) {
                    require(abs(a.frame.midY - b.frame.midY) >= labelHeight - 0.1, "Labels \(a.item.id) and \(b.item.id) overlap vertically")
                }
                if max(a.spanMinX, b.spanMinX) < min(a.spanMaxX, b.spanMaxX) + 4 {
                    if a.item.anchor.y < b.item.anchor.y {
                        require(a.frame.midY < b.frame.midY, "Leader lines cross between \(a.item.id) and \(b.item.id)")
                    } else if a.item.anchor.y > b.item.anchor.y {
                        require(a.frame.midY > b.frame.midY, "Leader lines cross between \(a.item.id) and \(b.item.id)")
                    }
                }
            }
        }

        // 右边缘气泡在未放大时应放到左侧，避免被裁切或压回气泡上
        let rightEdgeItem = placement("Gemini 4 Carbon · High", x: 665, score: 60.0, r: 9, w: 145)
        let leftEdgeItem = placement("GPT-6.1 Sol · Low", x: 85, score: 35.0, r: 8, w: 110)
        let overviewOffsets = BubbleChart.resolveLabelOffsets([rightEdgeItem, leftEdgeItem], plotRect: plotRect, scale: 1.0,
                                                              featured: [rightEdgeItem.id, leftEdgeItem.id])
        let rightLabelX = rightEdgeItem.anchor.x + (overviewOffsets[rightEdgeItem.id]?.width ?? 0)
        require(rightLabelX + rightEdgeItem.frame.width <= rightEdgeItem.anchor.x - rightEdgeItem.radius - 4,
                "Right-edge featured label should sit cleanly on the left side")
        let leftLabelX = leftEdgeItem.anchor.x + (overviewOffsets[leftEdgeItem.id]?.width ?? 0)
        require(leftLabelX >= leftEdgeItem.anchor.x + leftEdgeItem.radius + 4,
                "Left-edge featured label should sit cleanly on the right side")

        // 筛选后可见模型数量较少时，即使 scale = 1.0（未放大）也应尽量显示所有不冲突的标签
        let sparseFiltered: [ChartLabelPlacement] = [
            placement("Gemini 4 Carbon · High", x: 600, score: 60.0, r: 9, w: 140),
            placement("Gemini 4 Carbon · Med", x: 600, score: 58.3, r: 9, w: 140),
            placement("Gemini 4 Carbon · Low", x: 600, score: 55.0, r: 9, w: 138),
            placement("Gemini 4 Argon · High", x: 600, score: 52.0, r: 8, w: 135),
            placement("Gemini 4 Hydrogen · XHigh", x: 460, score: 54.7, r: 13, w: 155),
            placement("Gemini 4 Hydrogen · High", x: 460, score: 52.2, r: 13, w: 148),
            placement("Gemini 4 Hydrogen · Med", x: 460, score: 45.0, r: 13, w: 148),
            placement("Gemini 4 Hydrogen · Low", x: 460, score: 36.0, r: 14, w: 148),
            placement("Gemini 4 Flash · High", x: 160, score: 38.5, r: 10, w: 130),
            placement("Gemini 4 Flash · Med", x: 160, score: 37.8, r: 10, w: 130),
            placement("Gemini 4 Flash · Low", x: 160, score: 34.0, r: 9, w: 128)
        ]
        let sparseOffsets = BubbleChart.resolveLabelOffsets(sparseFiltered, plotRect: plotRect, scale: 1.0,
                                                            featured: ["Gemini 4 Carbon · High", "Gemini 4 Carbon · Med"])
        require(sparseOffsets.count == sparseFiltered.count,
                "Sparse filtered view at scale 1.0 should show all \(sparseFiltered.count) labels, got \(sparseOffsets.count)")
        for flashID in ["Gemini 4 Flash · High", "Gemini 4 Flash · Med", "Gemini 4 Flash · Low"] {
            require((sparseOffsets[flashID]?.width ?? -1) > 0,
                    "Sparse pair \(flashID) has room on the right and should prefer right side")
        }
        print("Architecture checks passed")
    }
}
