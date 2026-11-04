import Foundation

struct AIModel: Codable, Identifiable {
    struct Creator: Codable { let id: String; let name: String }
    struct Evaluations: Codable { let artificialAnalysisIntelligenceIndex: Double? }
    struct Pricing: Codable {
        let price1mInputTokens: Double?
        let price1mOutputTokens: Double?
        enum CodingKeys: String, CodingKey {
            case price1mInputTokens = "price1MInputTokens"
            case price1mOutputTokens = "price1MOutputTokens"
        }
    }
    struct Performance: Codable { let medianOutputTokensPerSecond: Double? }
    let id: String
    let name: String
    let slug: String
    let modelCreator: Creator
    let evaluations: Evaluations
    let pricing: Pricing
    let performance: Performance

    var intelligence: Double? { evaluations.artificialAnalysisIntelligenceIndex }
    var speed: Double? { performance.medianOutputTokensPerSecond }
    var cost: Double? {
        guard let input = pricing.price1mInputTokens, let output = pricing.price1mOutputTokens, input >= 0, output >= 0 else { return nil }
        return (input * 3 + output) / 4
    }
    var isPlottable: Bool {
        guard let cost, let intelligence, let speed else { return false }
        return cost.isFinite && intelligence.isFinite && speed.isFinite && speed >= 0
    }
    // log(1 + cost) retains zero and compresses the wide range of prices.
    var chartCost: Double { log10(1 + (cost ?? 0)) }
}

struct APIPage: Decodable {
    struct Pagination: Decodable { let page: Int; let totalPages: Int; let hasMore: Bool }
    let pagination: Pagination
    let data: [AIModel]
    let intelligenceIndexVersion: Double
}

struct ModelCache: Codable {
    let models: [AIModel]
    let updatedAt: Date
    let indexVersion: Double
}
