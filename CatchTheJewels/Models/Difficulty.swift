import Foundation

/// The arrangement of objects released in one spawn wave.
enum SpawnPattern: String, CaseIterable, Equatable {
    /// One object.
    case single
    /// Two objects released together, well apart.
    case pair
    /// Three objects released one after another across the screen.
    case diagonal
    /// Four objects released in quick succession.
    case shower

    /// The first difficulty level at which this pattern can appear.
    var unlockLevel: Int {
        switch self {
        case .single: return 0
        case .pair: return 2
        case .diagonal: return 4
        case .shower: return 6
        }
    }
}

/// Tunable parameters for one difficulty level.
struct Difficulty: Equatable {
    let level: Int
    /// Fall speed expressed as a fraction of the playfield height per second, so the
    /// game feels the same on every screen size.
    let fallSpeed: Double
    /// Seconds between spawn waves.
    let spawnInterval: TimeInterval
    /// Probability (0...1) that any spawned object is a bomb.
    let bombChance: Double
    let patterns: [SpawnPattern]
}

/// Difficulty rises gradually with time spent playing (not wall-clock time).
enum DifficultyCurve {
    static let secondsPerLevel: TimeInterval = 12
    static let maxLevel = 10

    static let baseFallSpeed = 0.26
    static let fallSpeedPerLevel = 0.045
    static let maxFallSpeed = 0.72

    static let baseSpawnInterval: TimeInterval = 1.05
    static let spawnIntervalStepPerLevel: TimeInterval = 0.07
    static let minSpawnInterval: TimeInterval = 0.40

    static let baseBombChance = 0.12
    static let bombChancePerLevel = 0.018
    static let maxBombChance = 0.30

    static func level(at elapsed: TimeInterval) -> Int {
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        return min(maxLevel, Int(elapsed / secondsPerLevel))
    }

    static func difficulty(at elapsed: TimeInterval) -> Difficulty {
        difficulty(forLevel: level(at: elapsed))
    }

    static func difficulty(forLevel rawLevel: Int) -> Difficulty {
        let level = max(0, min(maxLevel, rawLevel))
        let speed = min(maxFallSpeed, baseFallSpeed + Double(level) * fallSpeedPerLevel)
        let interval = max(minSpawnInterval, baseSpawnInterval - Double(level) * spawnIntervalStepPerLevel)
        let bombs = min(maxBombChance, baseBombChance + Double(level) * bombChancePerLevel)
        let patterns = SpawnPattern.allCases.filter { $0.unlockLevel <= level }
        return Difficulty(level: level, fallSpeed: speed, spawnInterval: interval, bombChance: bombs, patterns: patterns)
    }
}
