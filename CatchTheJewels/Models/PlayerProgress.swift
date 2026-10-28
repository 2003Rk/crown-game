import Foundation

/// A compact summary of the most recent finished run, shown in the Play lobby.
struct RunRecord: Codable, Equatable {
    var mode: GameModeKind
    var score: Int
    var jewels: Int
    var maxCombo: Int
    var duration: TimeInterval
    var date: Date
}

/// Everything the game remembers about the player's progress, stored on device only.
/// Profile details (nickname, avatar) and preferences live in their own stores so a
/// progress reset never touches them.
struct PlayerProgress: Codable, Equatable {
    static let currentSchemaVersion = 2
    /// Daily records beyond this many entries are pruned to keep storage small.
    static let maxDailyRecords = 60

    /// Achievement IDs from earlier builds and their current equivalents.
    static let legacyAchievementIDs = [
        "firstSparkle": Achievement.firstCatch.rawValue,
        "treasureKeeper": Achievement.jewelCollector.rawValue,
        "royalTreasury": Achievement.royalCollector.rawValue,
        "devotedRoyal": Achievement.dedicatedPlayer.rawValue,
        "dailyDuty": Achievement.dailyChampion.rawValue,
    ]

    struct DailyRecord: Codable, Equatable {
        var bestScore: Int = 0
        var completed: Bool = false
    }

    var schemaVersion = PlayerProgress.currentSchemaVersion
    /// Best Classic Mode score.
    var bestScore = 0
    var bestTimeChallengeScore = 0
    /// Highest score in any single run, across all modes.
    var highestScore = 0
    var totalJewels = 0
    var gamesPlayed = 0
    /// Seconds of active play across all recorded runs (excludes countdowns and pauses).
    var totalPlayTime: TimeInterval = 0
    var bestCombo = 0
    var bestGoldInRun = 0
    /// Highest score reached in a run before losing the first life.
    var bestFlawlessScore = 0
    /// True once a timed run has been finished without losing a life.
    var hasSurvivedRun = false
    var dailyChallengesCompleted = 0
    var unlockedAchievements: [String: Date] = [:]
    /// Keyed by `DailyChallenge.dateKey`.
    var dailyRecords: [String: DailyRecord] = [:]
    var lastRun: RunRecord?
    /// Guards against recording the same run twice.
    var lastRecordedRunID: UUID?

    init() {}

    /// Tolerant decoding: any missing or unreadable field falls back to its default
    /// instead of discarding the player's whole save.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        schemaVersion = value(.schemaVersion, Self.currentSchemaVersion)
        bestScore = value(.bestScore, 0)
        bestTimeChallengeScore = value(.bestTimeChallengeScore, 0)
        highestScore = value(.highestScore, 0)
        totalJewels = value(.totalJewels, 0)
        gamesPlayed = value(.gamesPlayed, 0)
        totalPlayTime = value(.totalPlayTime, 0)
        bestCombo = value(.bestCombo, 0)
        bestGoldInRun = value(.bestGoldInRun, 0)
        bestFlawlessScore = value(.bestFlawlessScore, 0)
        hasSurvivedRun = value(.hasSurvivedRun, false)
        dailyChallengesCompleted = value(.dailyChallengesCompleted, 0)
        unlockedAchievements = value(.unlockedAchievements, [:])
        dailyRecords = value(.dailyRecords, [:])
        lastRun = value(.lastRun, nil)
        lastRecordedRunID = value(.lastRecordedRunID, nil)
    }

    // MARK: - Queries

    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlockedAchievements[achievement.rawValue] != nil
    }

    var unlockedCount: Int {
        Achievement.allCases.filter(isUnlocked).count
    }

    /// 0...1 share of all achievements unlocked.
    var completionFraction: Double {
        Double(unlockedCount) / Double(max(1, Achievement.allCases.count))
    }

    /// The most recently unlocked achievement, if any.
    var latestAchievement: (achievement: Achievement, date: Date)? {
        unlockedAchievements
            .compactMap { key, date in Achievement(rawValue: key).map { ($0, date) } }
            .max { $0.1 < $1.1 }
            .map { (achievement: $0.0, date: $0.1) }
    }

    /// The locked achievement the player is closest to earning.
    var nextAchievement: Achievement? {
        Achievement.allCases
            .filter { !isUnlocked($0) }
            .max { $0.fractionComplete(self) < $1.fractionComplete(self) }
    }

    var rank: PlayerRank { PlayerRank.rank(forTotalJewels: totalJewels) }

    // MARK: - Updating

    /// Folds a run's statistics into lifetime progress.
    ///
    /// - Parameter completed: `false` while the run is still in progress (used to
    ///   unlock achievements mid-run without counting the game or its play time).
    func merging(_ run: GameResult, completed: Bool) -> PlayerProgress {
        var copy = self
        copy.totalJewels += run.jewelsCaught
        copy.highestScore = max(copy.highestScore, run.score)
        copy.bestCombo = max(copy.bestCombo, run.maxCombo)
        copy.bestGoldInRun = max(copy.bestGoldInRun, run.caught(.gold))
        copy.bestFlawlessScore = max(copy.bestFlawlessScore, run.scoreBeforeFirstLifeLost)
        guard completed else { return copy }
        copy.gamesPlayed += 1
        copy.totalPlayTime += max(0, run.duration)
        if run.survivedWithoutLosingLife { copy.hasSurvivedRun = true }
        switch run.mode {
        case .classic: copy.bestScore = max(copy.bestScore, run.score)
        case .timeChallenge: copy.bestTimeChallengeScore = max(copy.bestTimeChallengeScore, run.score)
        case .daily: break
        }
        return copy
    }

    /// Achievements earned by this progress that aren't yet marked unlocked.
    var pendingAchievements: [Achievement] {
        Achievement.allCases.filter { !isUnlocked($0) && $0.isEarned(self) }
    }

    /// Repairs impossible values (e.g. negatives from a corrupted file) and migrates old IDs.
    func sanitized() -> PlayerProgress {
        var copy = self
        copy.schemaVersion = Self.currentSchemaVersion
        copy.bestScore = max(0, bestScore)
        copy.bestTimeChallengeScore = max(0, bestTimeChallengeScore)
        copy.highestScore = max(0, highestScore, bestScore, bestTimeChallengeScore)
        copy.totalJewels = max(0, totalJewels)
        copy.gamesPlayed = max(0, gamesPlayed)
        copy.totalPlayTime = totalPlayTime.isFinite ? max(0, totalPlayTime) : 0
        copy.bestCombo = max(0, bestCombo)
        copy.bestGoldInRun = max(0, bestGoldInRun)
        copy.bestFlawlessScore = max(0, bestFlawlessScore)
        copy.dailyChallengesCompleted = max(0, dailyChallengesCompleted)

        var achievements: [String: Date] = [:]
        for (key, date) in unlockedAchievements {
            let id = Self.legacyAchievementIDs[key] ?? key
            guard Achievement(rawValue: id) != nil else { continue }
            achievements[id] = min(date, achievements[id] ?? date)
        }
        copy.unlockedAchievements = achievements
        return copy
    }

    mutating func pruneDailyRecords() {
        guard dailyRecords.count > Self.maxDailyRecords else { return }
        // yyyy-MM-dd keys sort chronologically as strings.
        let keep = Set(dailyRecords.keys.sorted().suffix(Self.maxDailyRecords))
        dailyRecords = dailyRecords.filter { keep.contains($0.key) }
    }
}

/// Player level, earned by collecting jewels across all runs.
struct PlayerRank: Equatable {
    let level: Int
    let title: String
    let threshold: Int
    let nextThreshold: Int?

    static let tiers: [(title: String, threshold: Int)] = [
        ("Squire", 0),
        ("Knight", 100),
        ("Baron", 300),
        ("Count", 750),
        ("Duke", 1_500),
        ("Prince", 3_000),
        ("Monarch", 6_000),
    ]

    static func rank(forTotalJewels jewels: Int) -> PlayerRank {
        let total = max(0, jewels)
        let index = tiers.lastIndex { total >= $0.threshold } ?? 0
        let next = index + 1 < tiers.count ? tiers[index + 1].threshold : nil
        return PlayerRank(level: index + 1, title: tiers[index].title, threshold: tiers[index].threshold, nextThreshold: next)
    }

    /// 0...1 progress toward the next rank (1 at the top rank).
    func progress(totalJewels: Int) -> Double {
        guard let next = nextThreshold else { return 1 }
        let span = Double(next - threshold)
        return min(1, max(0, Double(totalJewels - threshold) / span))
    }
}
