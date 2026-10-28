import Foundation

/// One object the scene should release.
struct SpawnRequest: Equatable {
    enum Placement: Equatable {
        /// Horizontal position as a fraction (0...1) of the playable lane.
        case lane(Double)
        /// Directly above the catcher's current position. Only used by test scenarios.
        case aboveCatcher
    }

    let kind: FallingObjectKind
    let placement: Placement
    /// Seconds after the wave starts before this object is released.
    let delay: TimeInterval
    /// Per-object variation applied to the difficulty's fall speed.
    let speedMultiplier: Double
}

/// Deterministic scenarios used only by automated UI tests.
enum GameScenario: String {
    case standard
    /// Every wave is a single bomb dropped onto the catcher — reaches game over quickly.
    case bombsOnly
}

/// Decides what falls next. All randomness comes from the injected generator so a
/// given seed always yields the same sequence of waves.
struct SpawnPlanner {
    static let heartChance = 0.03
    static let minimumPairSeparation = 0.35

    private var rng: SeededGenerator
    let scenario: GameScenario

    init(seed: UInt64, scenario: GameScenario = .standard) {
        rng = SeededGenerator(seed: seed)
        self.scenario = scenario
    }

    mutating func nextWave(difficulty: Difficulty, canAwardHeart: Bool) -> [SpawnRequest] {
        if scenario == .bombsOnly {
            return [SpawnRequest(kind: .bomb, placement: .aboveCatcher, delay: 0, speedMultiplier: 1.6)]
        }

        let pattern = difficulty.patterns.randomElement(using: &rng) ?? .single
        switch pattern {
        case .single:
            return [request(kind: nextKind(difficulty, canAwardHeart: canAwardHeart), x: unit(), delay: 0)]

        case .pair:
            let first = unit()
            var second = unit()
            if abs(second - first) < Self.minimumPairSeparation {
                second = first < 0.5 ? min(1, first + 0.5) : max(0, first - 0.5)
            }
            // Never two bombs in one pair: one object is always worth catching.
            let firstKind = nextKind(difficulty, canAwardHeart: canAwardHeart)
            let secondKind: FallingObjectKind = firstKind.isHazard ? .jewel(nextJewel()) : nextKind(difficulty, canAwardHeart: false)
            return [request(kind: firstKind, x: first, delay: 0), request(kind: secondKind, x: second, delay: 0)]

        case .diagonal:
            let leftToRight = Bool.random(using: &rng)
            let positions = leftToRight ? [0.12, 0.5, 0.88] : [0.88, 0.5, 0.12]
            return positions.enumerated().map { index, x in
                let kind: FallingObjectKind = index == 1 ? nextKind(difficulty, canAwardHeart: canAwardHeart) : .jewel(nextJewel())
                return request(kind: kind, x: x, delay: Double(index) * 0.22)
            }

        case .shower:
            let bombIndex = Double.random(in: 0..<1, using: &rng) < difficulty.bombChance ? Int.random(in: 0..<4, using: &rng) : nil
            return (0..<4).map { index in
                let kind: FallingObjectKind = index == bombIndex ? .bomb : .jewel(nextJewel())
                return request(kind: kind, x: unit(), delay: Double(index) * 0.16)
            }
        }
    }

    // MARK: - Helpers

    private mutating func request(kind: FallingObjectKind, x: Double, delay: TimeInterval) -> SpawnRequest {
        let variation = Double.random(in: 0.9...1.12, using: &rng)
        return SpawnRequest(kind: kind, placement: .lane(min(1, max(0, x))), delay: delay, speedMultiplier: variation)
    }

    private mutating func unit() -> Double {
        Double.random(in: 0...1, using: &rng)
    }

    private mutating func nextKind(_ difficulty: Difficulty, canAwardHeart: Bool) -> FallingObjectKind {
        let roll = Double.random(in: 0..<1, using: &rng)
        if roll < difficulty.bombChance { return .bomb }
        if canAwardHeart, roll < difficulty.bombChance + Self.heartChance { return .heart }
        return .jewel(nextJewel())
    }

    private mutating func nextJewel() -> JewelKind {
        let total = JewelKind.allCases.reduce(0) { $0 + $1.spawnWeight }
        var pick = Double.random(in: 0..<total, using: &rng)
        for kind in JewelKind.allCases {
            if pick < kind.spawnWeight { return kind }
            pick -= kind.spawnWeight
        }
        return .ruby
    }
}
