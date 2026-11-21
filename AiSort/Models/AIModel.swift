import Foundation

struct AIModel: Codable, Identifiable {
    struct Creator: Codable {
        let id: String
        let name: String

        var region: CreatorRegion? {
            if Self.china.contains(name) { return .china }
            if Self.outsideChina.contains(name) { return .outsideChina }
            return nil
        }

        // Match the publisher names supplied by Artificial Analysis. New or
        // ambiguous publishers stay unclassified until their origin is confirmed.
        private static let china: Set<String> = [
            "Alibaba", "Baidu", "ByteDance Seed", "China Mobile", "DeepSeek",
            "InclusionAI", "Kimi", "KwaiKAT", "LongCat", "MiniMax", "Nanbeige",
            "OpenBMB", "StepFun", "Tencent", "Xiaomi", "Z AI"
        ]
        private static let outsideChina: Set<String> = [
            "AI21 Labs", "Allen Institute for AI", "Amazon", "Anthropic", "Arcee AI",
            "Cohere", "Databricks", "Deep Cogito", "Google", "IBM", "Inception",
            "Institute of Foundation Models", "Korea Telecom", "LG AI Research",
            "Liquid AI", "Meta", "Microsoft", "Mistral", "Motif Technologies",
            "Multiverse Computing", "NVIDIA", "Naver", "Nous Research", "OpenAI",
            "Perplexity", "Prime Intellect", "Reflection", "Reka AI", "SK Telecom",
            "Sarvam", "ServiceNow", "Snowflake", "SpaceXAI", "Swiss AI Initiative",
            "TII UAE", "Thinking Machines", "Trillion Labs", "Upstage"
        ]
    }
    struct Evaluations: Codable {
        let artificialAnalysisIntelligenceIndex: Double?
        var artificialAnalysisCodingIndex: Double?
        var artificialAnalysisAgenticIndex: Double?
        var artificialAnalysisFinanceAndAccountingIndex: Double?
        var artificialAnalysisStrategyAndOpsIndex: Double?
        var artificialAnalysisLegalIndex: Double?
        var artificialAnalysisHealthcareAndMedicalIndex: Double?
        var artificialAnalysisEngineeringIndex: Double?
        var artificialAnalysisEconomicsIndex: Double?
    }
    struct Pricing: Codable {
        let price1mInputTokens: Double?
        let price1mOutputTokens: Double?
        var price1mCacheHitTokens: Double?
        var price1mCacheWriteTokens: Double?
        enum CodingKeys: String, CodingKey {
            case price1mInputTokens = "price1MInputTokens"
            case price1mOutputTokens = "price1MOutputTokens"
            case price1mCacheHitTokens = "price1MCacheHitTokens"
            case price1mCacheWriteTokens = "price1MCacheWriteTokens"
        }
    }
    struct Performance: Codable {
        let medianOutputTokensPerSecond: Double?
        var medianTimeToFirstTokenSeconds: Double?
        var medianTimeToFirstAnswerTokenSeconds: Double?
        var medianEndToEndResponseTimeSeconds: Double?
    }
    struct PerformanceV3: Codable {
        let meanOutputTokensPerSecond: Double?
        let meanTimeToFirstTokenSeconds: Double?
        let meanTimeToFirstAnswerTokenSeconds: Double?
    }
    struct IntelligenceIndexCost: Codable {
        struct CostPerTask: Codable { let totalCost: Double? }
        let totalCost: Double?
        let costPerTask: CostPerTask?
    }
    let id: String
    let name: String
    let slug: String
    let releaseDate: String?
    let modelCreator: Creator
    let evaluations: Evaluations
    let pricing: Pricing
    let performance: Performance
    var performanceV3: PerformanceV3?
    var artificialAnalysisIntelligenceIndexCost: IntelligenceIndexCost?

    var intelligence: Double? { evaluations.artificialAnalysisIntelligenceIndex }
    var speed: Double? { performance.medianOutputTokensPerSecond }
    var chartSpeed: Double? { speed.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } }
    var cost: Double? {
        guard let input = pricing.price1mInputTokens, let output = pricing.price1mOutputTokens, input >= 0, output >= 0 else { return nil }
        let blended = (input * 3 + output) / 4
        return blended.isFinite ? blended : nil
    }
    var isPlottable: Bool {
        intelligence?.isFinite == true && (cost == nil || chartSpeed != nil)
    }
    // log(1 + cost) retains zero and compresses the wide range of prices.
    var chartCost: Double? { cost.map { log10(1 + $0) } }

    var reasoningEffort: ReasoningEffort {
        ReasoningEffort.parse(from: name)
    }
}

enum ReasoningEffort: String, CaseIterable, Codable, Hashable, Identifiable {
    case max = "Max"
    case xhigh = "XHigh"
    case high = "High"
    case medium = "Med"
    case low = "Low"
    case min = "Min"
    case none = "无档位"

    var id: String { rawValue }

    static func parse(from modelName: String) -> ReasoningEffort {
        var searchStart = modelName.startIndex
        while let open = modelName[searchStart...].firstIndex(of: "("),
              let close = modelName[modelName.index(after: open)...].firstIndex(of: ")") {
            let inside = modelName[modelName.index(after: open)..<close]
            for token in inside.split(separator: ",") {
                switch token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "max", "maximum": return .max
                case "xhigh", "extra high": return .xhigh
                case "high": return .high
                case "medium", "med": return .medium
                case "low": return .low
                case "min", "minimum", "minimal": return .min
                default: break
                }
            }
            searchStart = modelName.index(after: close)
        }
        return .none
    }
}

enum CreatorRegion: String, CaseIterable {
    case all = "全部"
    case china = "中国"
    case outsideChina = "非中国"

    func includes(_ creator: AIModel.Creator) -> Bool {
        self == .all || creator.region == self
    }
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
