import Foundation

/// Artificial Analysis 免费额度：每个账号固定 24 小时窗口内 100 次请求，分页的每一页各算一次。
struct RateLimit: Codable, Equatable {
    let limit: Int?
    let remaining: Int
    let resetAt: Date

    func isActive(at now: Date) -> Bool { resetAt > now }

    /// 从响应头读取 X-RateLimit-*；429 时用 Retry-After 推算重置时间。
    init?(response: HTTPURLResponse, now: Date = Date()) {
        let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let limit = response.value(forHTTPHeaderField: "X-RateLimit-Limit").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        var resetAt = response.value(forHTTPHeaderField: "X-RateLimit-Reset")
            .flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            .map { Date(timeIntervalSince1970: $0 > 1e12 ? $0 / 1_000 : $0) }
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap({ Double($0.trimmingCharacters(in: .whitespaces)) }) {
            resetAt = now.addingTimeInterval(retryAfter)
        }
        if response.statusCode == 429 {
            self.init(limit: limit, remaining: 0, resetAt: resetAt ?? now.addingTimeInterval(3_600))
            return
        }
        guard let remaining, let resetAt else { return nil }
        self.init(limit: limit, remaining: remaining, resetAt: resetAt)
    }

    init(limit: Int?, remaining: Int, resetAt: Date) {
        self.limit = limit
        self.remaining = remaining
        self.resetAt = resetAt
    }
}

enum RefreshBlock: Equatable {
    /// 额度不够拉完一轮，不能强制。
    case quota(String)
    /// 刚更新过，用户可以选择仍然更新。
    case cooldown(String)

    var message: String {
        switch self { case .quota(let text), .cooldown(let text): return text }
    }
}

/// 决定什么时候可以真正发请求，避免浪费每日额度。
struct RefreshPolicy {
    /// 启动时缓存比这更新就不请求。
    var launchFreshness: TimeInterval = 6 * 3_600
    /// 手动刷新的最短间隔。
    var manualCooldown: TimeInterval = 10 * 60

    func shouldRefreshOnLaunch(updatedAt: Date?, now: Date) -> Bool {
        guard let updatedAt else { return true }
        #if DEBUG
        // 开发时每次 Run 都会启动应用，有缓存就不自动请求。
        return false
        #else
        return now.timeIntervalSince(updatedAt) >= launchFreshness
        #endif
    }

    /// 返回不能刷新的原因；nil 表示可以请求。
    func blockReason(updatedAt: Date?, rateLimit: RateLimit?, pagesNeeded: Int, now: Date, respectsCooldown: Bool = true) -> String? {
        block(updatedAt: updatedAt, rateLimit: rateLimit, pagesNeeded: pagesNeeded, now: now, respectsCooldown: respectsCooldown)?.message
    }

    func block(updatedAt: Date?, rateLimit: RateLimit?, pagesNeeded: Int, now: Date, respectsCooldown: Bool = true) -> RefreshBlock? {
        if let rateLimit, rateLimit.isActive(at: now), rateLimit.remaining < pagesNeeded {
            return .quota("今日 API 额度不足（剩余 \(rateLimit.remaining) 次，完整刷新需要 \(pagesNeeded) 次），将于 \(Self.format(rateLimit.resetAt, now: now)) 重置。")
        }
        if respectsCooldown, let updatedAt, now.timeIntervalSince(updatedAt) < manualCooldown, now >= updatedAt {
            let minutes = max(1, Int(now.timeIntervalSince(updatedAt) / 60))
            return .cooldown("数据 \(minutes) 分钟前刚更新，为节省额度，\(Int(manualCooldown / 60)) 分钟内不重复请求。")
        }
        return nil
    }

    static func format(_ date: Date, now: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: now)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(date: .abbreviated, time: .shortened)
    }
}
