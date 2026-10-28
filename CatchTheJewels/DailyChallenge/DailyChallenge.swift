import Foundation

/// A timed challenge that changes every day, derived entirely from the device's
/// local date — no server involved. Every player gets the same goal and the same
/// spawn sequence on the same calendar day.
struct DailyChallenge: Equatable, Hashable {
    enum Goal: Equatable, Hashable {
        case reachScore(Int)
        case catchJewels(Int)
        case catchKind(JewelKind, Int)
        /// Reach the score without losing a life.
        case flawless(score: Int)
    }

    /// Local calendar day in `yyyy-MM-dd` form, e.g. "2026-10-26".
    let dateKey: String
    let seed: UInt64
    let goal: Goal
    let duration: TimeInterval

    static let standardDuration: TimeInterval = 60

    static func forDate(_ date: Date, calendar: Calendar = .current) -> DailyChallenge {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 2026
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        let key = String(format: "%04d-%02d-%02d", year, month, day)

        // Mix the date into a well-distributed seed.
        var mixer = SeededGenerator(seed: UInt64(year * 10_000 + month * 100 + day))
        let seed = mixer.next()
        var picker = SeededGenerator(seed: seed)

        let goal: Goal
        switch Int.random(in: 0..<4, using: &picker) {
        case 0:
            goal = .reachScore([600, 700, 800, 900].randomElement(using: &picker) ?? 700)
        case 1:
            goal = .catchJewels([25, 30, 35].randomElement(using: &picker) ?? 30)
        case 2:
            let kind = JewelKind.allCases.randomElement(using: &picker) ?? .ruby
            goal = .catchKind(kind, Self.kindTarget(for: kind))
        default:
            goal = .flawless(score: [350, 450, 550].randomElement(using: &picker) ?? 450)
        }
        return DailyChallenge(dateKey: key, seed: seed, goal: goal, duration: standardDuration)
    }

    private static func kindTarget(for kind: JewelKind) -> Int {
        switch kind {
        case .ruby: return 12
        case .sapphire: return 9
        case .emerald: return 7
        case .amethyst: return 5
        case .gold: return 3
        }
    }

    var title: String {
        switch goal {
        case .reachScore: return "Royal Sprint"
        case .catchJewels: return "Treasure Rush"
        case .catchKind(let kind, _): return "\(kind.displayName) Hunt"
        case .flawless: return "Flawless Court"
        }
    }

    var goalDescription: String {
        let seconds = Int(duration)
        switch goal {
        case .reachScore(let target):
            return "Score \(target.formatted()) points in \(seconds) seconds."
        case .catchJewels(let target):
            return "Catch \(target) jewels in \(seconds) seconds."
        case .catchKind(let kind, let target):
            return "Catch \(target) \(kind.displayName)\(target == 1 ? "" : "s") in \(seconds) seconds."
        case .flawless(let score):
            return "Score \(score.formatted()) points in \(seconds) seconds without losing a life."
        }
    }

    func isCompleted(by result: GameResult) -> Bool {
        progress(for: result) >= target
    }

    /// Progress toward the goal for a run, using the same units as `target`.
    func progress(for result: GameResult) -> Int {
        switch goal {
        case .reachScore: return result.score
        case .catchJewels: return result.jewelsCaught
        case .catchKind(let kind, _): return result.caught(kind)
        case .flawless: return result.scoreBeforeFirstLifeLost
        }
    }

    var target: Int {
        switch goal {
        case .reachScore(let target), .catchJewels(let target), .catchKind(_, let target):
            return target
        case .flawless(let score):
            return score
        }
    }
}
