import Foundation

enum ModelSort: String, CaseIterable, Identifiable {
    case intelligence = "智力由高到低", cost = "成本由低到高", speed = "速度由快到慢"
    var id: String { rawValue }
    func precedes(_ lhs: AIModel, _ rhs: AIModel) -> Bool {
        let left: Double?, right: Double?
        switch self {
        case .intelligence: left = lhs.intelligence; right = rhs.intelligence
        case .cost: left = lhs.cost; right = rhs.cost
        case .speed: left = lhs.speed; right = rhs.speed
        }
        if left == nil { return right == nil && lhs.name < rhs.name }
        if right == nil { return true }
        if left == right { return lhs.name < rhs.name }
        return self == .cost ? left! < right! : left! > right!
    }
}
