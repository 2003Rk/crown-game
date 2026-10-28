import Foundation

/// The five collectible jewels. Each has a distinct silhouette as well as a distinct
/// color so the game never relies on color alone to communicate value.
enum JewelKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case ruby
    case sapphire
    case emerald
    case amethyst
    case gold

    var id: String { rawValue }

    /// Base points before the combo multiplier is applied.
    var points: Int {
        switch self {
        case .ruby: return 10
        case .sapphire: return 15
        case .emerald: return 20
        case .amethyst: return 30
        case .gold: return 50
        }
    }

    /// Relative spawn weight. Rarer jewels are worth more.
    var spawnWeight: Double {
        switch self {
        case .ruby: return 35
        case .sapphire: return 25
        case .emerald: return 20
        case .amethyst: return 13
        case .gold: return 7
        }
    }

    var displayName: String {
        switch self {
        case .ruby: return "Ruby"
        case .sapphire: return "Sapphire"
        case .emerald: return "Emerald"
        case .amethyst: return "Amethyst"
        case .gold: return "Gold Star"
        }
    }

    /// Plain-language description of the jewel's shape, used by VoiceOver and How to Play.
    var shapeDescription: String {
        switch self {
        case .ruby: return "red octagon"
        case .sapphire: return "blue diamond"
        case .emerald: return "green rectangle"
        case .amethyst: return "purple hexagon"
        case .gold: return "gold star"
        }
    }
}

/// Everything that can fall from the top of the playfield.
enum FallingObjectKind: Hashable {
    case jewel(JewelKind)
    /// Catching a bomb costs a life.
    case bomb
    /// A rare royal heart restores a lost life (or awards bonus points at full health).
    case heart

    var isHazard: Bool {
        if case .bomb = self { return true }
        return false
    }

    var accessibilityName: String {
        switch self {
        case .jewel(let kind): return kind.displayName
        case .bomb: return "Bomb"
        case .heart: return "Royal Heart"
        }
    }
}
