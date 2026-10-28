import Foundation

/// A storable identifier for each kind of run.
enum GameModeKind: String, Codable, CaseIterable, Identifiable {
    case classic
    case timeChallenge
    case daily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic Mode"
        case .timeChallenge: return "Time Challenge"
        case .daily: return "Daily Challenge"
        }
    }
}

/// Which kind of run is being played.
enum GameMode: Equatable {
    /// Play until all lives are lost; difficulty keeps rising.
    case classic
    /// Score as much as possible before the countdown ends.
    case timeChallenge
    /// Today's timed challenge with a fixed, date-derived spawn sequence.
    case daily(DailyChallenge)

    static let timeChallengeDuration: TimeInterval = 60

    var kind: GameModeKind {
        switch self {
        case .classic: return .classic
        case .timeChallenge: return .timeChallenge
        case .daily: return .daily
        }
    }

    var title: String { kind.title }

    var config: GameConfig {
        switch self {
        case .classic: return GameConfig()
        case .timeChallenge: return GameConfig(timeLimit: Self.timeChallengeDuration)
        case .daily(let challenge): return GameConfig(timeLimit: challenge.duration)
        }
    }

    var isTimed: Bool { config.timeLimit != nil }

    var dailyChallenge: DailyChallenge? {
        if case .daily(let challenge) = self { return challenge }
        return nil
    }
}

/// Rule constants for a run.
struct GameConfig: Equatable {
    var maxLives = 3
    var countdownDuration: TimeInterval = 3
    /// When set, the run ends once this much play time has elapsed.
    var timeLimit: TimeInterval?
    /// After losing a life the catcher is briefly protected so one cluster of bombs
    /// can't wipe out several lives at once.
    var invulnerabilityDuration: TimeInterval = 1.2
    /// Points awarded for a heart caught at full health.
    var heartBonusPoints = 100
    /// Consecutive catches needed to raise the multiplier by one step.
    var comboStep = 10
    var maxMultiplier = 4
}

enum GameOverReason: Equatable {
    case outOfLives
    case timeUp
}

/// What happened when the catcher touched an object.
enum CatchOutcome: Equatable {
    case jewel(JewelKind, points: Int, multiplier: Int)
    case bomb(livesRemaining: Int)
    /// A bomb touched the catcher during the post-hit protection window.
    case bombBlocked
    case lifeRestored(lives: Int)
    case heartBonus(points: Int)
    /// The run isn't in the playing state, so nothing changed.
    case ignored
}

/// State transitions reported by `GameSession.advance(by:)`.
enum SessionEvent: Equatable {
    case countdown(Int)
    case started
    case gameOver(GameOverReason)
}

/// The complete, deterministic rules of one run. Contains no rendering or timing
/// code: the scene feeds it elapsed time and catches, and it reports outcomes.
struct GameSession {
    enum State: Equatable {
        case countdown
        case playing
        case paused
        case gameOver(GameOverReason)
    }

    let mode: GameMode
    let config: GameConfig
    /// Unique per run, so a finished run can never be recorded twice.
    let runID = UUID()

    private(set) var state: State = .countdown
    private(set) var score = 0
    private(set) var lives: Int
    private(set) var combo = 0
    private(set) var maxCombo = 0
    private(set) var jewelsCaught = 0
    private(set) var caughtByKind: [JewelKind: Int] = [:]
    private(set) var livesLost = 0
    private(set) var bombsHit = 0
    /// Seconds of active play (excludes countdown and pauses).
    private(set) var elapsed: TimeInterval = 0
    private(set) var countdownRemaining: TimeInterval
    private(set) var invulnerabilityRemaining: TimeInterval = 0
    /// The highest score reached before the first life was lost.
    private(set) var scoreBeforeFirstLifeLost = 0

    private var stateBeforePause: State = .countdown

    init(mode: GameMode) {
        self.mode = mode
        config = mode.config
        lives = config.maxLives
        countdownRemaining = config.countdownDuration
    }

    // MARK: - Derived values

    var multiplier: Int {
        min(config.maxMultiplier, 1 + combo / config.comboStep)
    }

    var difficulty: Difficulty {
        DifficultyCurve.difficulty(at: elapsed)
    }

    var timeRemaining: TimeInterval? {
        config.timeLimit.map { max(0, $0 - elapsed) }
    }

    var isInvulnerable: Bool { invulnerabilityRemaining > 0 }

    var isGameOver: Bool {
        if case .gameOver = state { return true }
        return false
    }

    /// Whole seconds left in the countdown, for display (3, 2, 1).
    var countdownNumber: Int {
        max(0, Int(countdownRemaining.rounded(.up)))
    }

    // MARK: - Time

    @discardableResult
    mutating func advance(by rawDelta: TimeInterval) -> [SessionEvent] {
        guard rawDelta.isFinite, rawDelta > 0 else { return [] }
        let delta = rawDelta
        var events: [SessionEvent] = []

        switch state {
        case .countdown:
            let before = countdownNumber
            countdownRemaining = max(0, countdownRemaining - delta)
            if countdownRemaining == 0 {
                state = .playing
                events.append(.started)
            } else if countdownNumber != before {
                events.append(.countdown(countdownNumber))
            }

        case .playing:
            elapsed += delta
            invulnerabilityRemaining = max(0, invulnerabilityRemaining - delta)
            if let limit = config.timeLimit, elapsed >= limit {
                elapsed = limit
                state = .gameOver(.timeUp)
                events.append(.gameOver(.timeUp))
            }

        case .paused, .gameOver:
            break
        }
        return events
    }

    // MARK: - Catching

    mutating func register(_ kind: FallingObjectKind) -> CatchOutcome {
        guard state == .playing else { return .ignored }

        switch kind {
        case .jewel(let jewel):
            combo += 1
            maxCombo = max(maxCombo, combo)
            let currentMultiplier = multiplier
            let points = jewel.points * currentMultiplier
            jewelsCaught += 1
            caughtByKind[jewel, default: 0] += 1
            addScore(points)
            return .jewel(jewel, points: points, multiplier: currentMultiplier)

        case .bomb:
            guard !isInvulnerable else { return .bombBlocked }
            lives = max(0, lives - 1)
            livesLost += 1
            bombsHit += 1
            combo = 0
            invulnerabilityRemaining = config.invulnerabilityDuration
            if lives == 0 {
                state = .gameOver(.outOfLives)
            }
            return .bomb(livesRemaining: lives)

        case .heart:
            if lives < config.maxLives {
                lives += 1
                return .lifeRestored(lives: lives)
            }
            addScore(config.heartBonusPoints)
            return .heartBonus(points: config.heartBonusPoints)
        }
    }

    /// A jewel reached the bottom uncaught. Breaks the combo; never costs a life.
    /// Returns `true` if a combo was broken.
    @discardableResult
    mutating func registerMiss(_ kind: FallingObjectKind) -> Bool {
        guard state == .playing, case .jewel = kind else { return false }
        let hadCombo = combo > 0
        combo = 0
        return hadCombo
    }

    // MARK: - Pause

    mutating func pause() {
        switch state {
        case .countdown, .playing:
            stateBeforePause = state
            state = .paused
        case .paused, .gameOver:
            break
        }
    }

    mutating func resume() {
        guard state == .paused else { return }
        state = stateBeforePause
    }

    // MARK: - Result

    var result: GameResult {
        GameResult(
            runID: runID,
            mode: mode,
            score: score,
            jewelsCaught: jewelsCaught,
            caughtByKind: caughtByKind,
            maxCombo: maxCombo,
            livesLost: livesLost,
            bombsHit: bombsHit,
            duration: elapsed,
            scoreBeforeFirstLifeLost: scoreBeforeFirstLifeLost,
            endReason: endReason
        )
    }

    var endReason: GameOverReason? {
        if case .gameOver(let reason) = state { return reason }
        return nil
    }

    private mutating func addScore(_ points: Int) {
        score += points
        if livesLost == 0 {
            scoreBeforeFirstLifeLost = score
        }
    }
}

/// The statistics of a finished run.
struct GameResult: Equatable {
    var runID = UUID()
    var mode: GameMode
    var score: Int
    var jewelsCaught: Int
    var caughtByKind: [JewelKind: Int]
    var maxCombo: Int
    var livesLost: Int
    var bombsHit: Int
    var duration: TimeInterval
    var scoreBeforeFirstLifeLost: Int
    /// Nil if the run was recorded before it ended.
    var endReason: GameOverReason?

    func caught(_ kind: JewelKind) -> Int {
        caughtByKind[kind] ?? 0
    }

    /// A timed run that ran out the clock without losing a single life.
    var survivedWithoutLosingLife: Bool {
        endReason == .timeUp && livesLost == 0
    }
}
