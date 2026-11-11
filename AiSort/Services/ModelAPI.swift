import Foundation
import OSLog

#if DEBUG && canImport(LayerLens)
import LayerLens
#endif

struct ModelAPI {
    private static let logger = Logger(subsystem: "com.readit.AiSort", category: "ModelAPI")
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 刷新过程中观察到的额度信息；即使请求失败也会保留已读到的值。
    struct FetchMetrics {
        var rateLimit: RateLimit?
        var totalPages: Int?
    }

    func fetchModels(key: String) async throws -> ModelCache {
        var metrics = FetchMetrics()
        return try await fetchModels(key: key, metrics: &metrics)
    }

    func fetchModels(key: String, metrics: inout FetchMetrics) async throws -> ModelCache {
        let refreshID = UUID().uuidString
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        var page = 1
        var items: [AIModel] = []
        var version: Double = 0
        while true {
            var components = URLComponents(string: "https://artificialanalysis.ai/api/v2/language/models/free")!
            components.queryItems = [URLQueryItem(name: "page", value: String(page))]
            var request = URLRequest(url: components.url!)
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            let startedAt = ProcessInfo.processInfo.systemUptime
            Self.log("refresh=\(refreshID) page=\(page) GET /api/v2/language/models/free")
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: request)
            } catch let error as URLError where error.code == .cancelled {
                Self.log("refresh=\(refreshID) page=\(page) cancelled url_error=\(error.code.rawValue) task_cancelled=\(Task.isCancelled)")
                throw CancellationError()
            } catch let error as CancellationError {
                Self.log("refresh=\(refreshID) page=\(page) task cancelled")
                throw error
            } catch let error as URLError {
                let elapsedMs = Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
                Self.log("refresh=\(refreshID) page=\(page) transport failed url_error=\(error.code.rawValue) elapsed_ms=\(elapsedMs)", level: .error)
                throw FetchError.message("第 \(page) 页请求失败（网络错误 \(error.code.rawValue)）：\(error.localizedDescription)")
            } catch {
                let failure = error as NSError
                Self.log("refresh=\(refreshID) page=\(page) request failed domain=\(failure.domain) code=\(failure.code)", level: .error)
                throw error
            }
            let elapsedMs = Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
            guard let http = response as? HTTPURLResponse else {
                Self.log("refresh=\(refreshID) page=\(page) non-HTTP response elapsed_ms=\(elapsedMs)", level: .error)
                throw FetchError.message("服务器响应无效。")
            }
            let rateLimit = RateLimit(response: http)
            if let rateLimit { metrics.rateLimit = rateLimit }
            Self.log("refresh=\(refreshID) page=\(page) status=\(http.statusCode) elapsed_ms=\(elapsedMs) bytes=\(data.count) quota_remaining=\(rateLimit.map { String($0.remaining) } ?? "-")")
            switch http.statusCode {
            case 200: break
            case 401, 403: throw FetchError.message("API Key 无效或无权访问，请检查设置。")
            case 429: throw FetchError.rateLimited(resetAt: rateLimit?.resetAt)
            default: throw FetchError.message("服务器返回错误（\(http.statusCode)），请稍后重试。")
            }
            let result: APIPage
            do {
                result = try decoder.decode(APIPage.self, from: data)
            } catch {
                Self.log("refresh=\(refreshID) page=\(page) JSON decoding failed", level: .error)
                throw error
            }
            let pagination = result.pagination
            guard pagination.page == page, !pagination.hasMore || (page < pagination.totalPages && page < 100) else {
                Self.log("refresh=\(refreshID) page=\(page) invalid pagination response_page=\(pagination.page) total_pages=\(pagination.totalPages) has_more=\(pagination.hasMore)", level: .error)
                throw FetchError.message("服务器分页数据无效。")
            }
            metrics.totalPages = pagination.totalPages
            items.append(contentsOf: result.data)
            version = result.intelligenceIndexVersion
            if !pagination.hasMore { break }
            page += 1
        }
        Self.log("refresh=\(refreshID) complete pages=\(page) models=\(items.count)")
        return ModelCache(models: items, updatedAt: Date(), indexVersion: version)
    }

    private static func log(_ message: String, level: OSLogType = .default) {
        logger.log(level: level, "\(message, privacy: .public)")
        #if DEBUG && canImport(LayerLens)
        LayerLens.log(message)
        #endif
    }

    enum FetchError: LocalizedError {
        case message(String)
        case rateLimited(resetAt: Date?)
        var errorDescription: String? {
            switch self {
            case .message(let text): return text
            case .rateLimited(let resetAt):
                guard let resetAt else { return "今日 API 额度已用完，请稍后重试。" }
                return "今日 API 额度已用完，将于 \(RefreshPolicy.format(resetAt, now: Date())) 重置。"
            }
        }
    }
}
