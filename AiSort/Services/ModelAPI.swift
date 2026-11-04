import Foundation

struct ModelAPI {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchModels(key: String) async throws -> ModelCache {
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
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw FetchError.message("服务器响应无效。") }
            switch http.statusCode {
            case 200: break
            case 401, 403: throw FetchError.message("API Key 无效或无权访问，请检查设置。")
            case 429: throw FetchError.message("请求过于频繁，请稍后重试。")
            default: throw FetchError.message("服务器返回错误（\(http.statusCode)），请稍后重试。")
            }
            let result = try decoder.decode(APIPage.self, from: data)
            guard result.pagination.page == page, result.pagination.totalPages >= page || !result.pagination.hasMore else { throw FetchError.message("服务器分页数据无效。") }
            items.append(contentsOf: result.data)
            version = result.intelligenceIndexVersion
            if !result.pagination.hasMore { break }
            guard page < result.pagination.totalPages, page < 100 else { throw FetchError.message("服务器分页数据无效。") }
            page += 1
        }
        return ModelCache(models: items, updatedAt: Date(), indexVersion: version)
    }

    enum FetchError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case .message(let text) = self { return text }
            return nil
        }
    }
}
