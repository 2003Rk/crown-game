import XCTest
@testable import CatchTheJewels

@MainActor
final class AchievementAndDailyTests: XCTestCase {
    private func result(score: Int = 0, jewels: Int = 0, mode: GameMode = .classic, byKind: [JewelKind: Int] = [:],
                        maxCombo: Int = 0, livesLost: Int = 3, flawless: Int = 0,
                        endReason: GameOverReason? = .outOfLives, duration: TimeInterval = 60) -> GameResult {
        GameResult(mode: mode, score: score, jewelsCaught: jewels, caughtByKind: byKind,
                   maxCombo: maxCombo, livesLost: livesLost, bombsHit: livesLost,
                   duration: duration, scoreBeforeFirstLifeLost: flawless, endReason: endReason)
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    // MARK: - Required achievements

    func testRequiredAchievementsExist() {
        let required: [Achievement] = [.firstCatch, .jewelCollector, .royalCollector, .scoreStarter,
                                       .highScorer, .survivor, .dailyChampion, .dedicatedPlayer]
        XCTAssertEqual(Array(Achievement.allCases.prefix(8)), required, "Required achievements are listed first")
        XCTAssertEqual(Achievement.firstCatch.title, "First Catch")
        XCTAssertEqual(Achievement.jewelCollector.title, "Jewel Collector")
        XCTAssertEqual(Achievement.royalCollector.title, "Royal Collector")
        XCTAssertEqual(Achievement.scoreStarter.title, "Score Starter")
        XCTAssertEqual(Achievement.highScorer.title, "High Scorer")
        XCTAssertEqual(Achievement.survivor.title, "Survivor")
        XCTAssertEqual(Achievement.dailyChampion.title, "Daily Champion")
        XCTAssertEqual(Achievement.dedicatedPlayer.title, "Dedicated Player")
    }

    func testFirstCatch() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        XCTAssertTrue(progress.record(result(jewels: 0)).newlyUnlocked.isEmpty)
        XCTAssertTrue(progress.record(result(score: 10, jewels: 1)).newlyUnlocked.contains(.firstCatch))
        XCTAssertTrue(progress.progress.isUnlocked(.firstCatch))
    }

    func testJewelCollectorAndRoyalCollector() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        progress.record(result(jewels: 60))
        XCTAssertFalse(progress.progress.isUnlocked(.jewelCollector))
        XCTAssertTrue(progress.record(result(jewels: 40)).newlyUnlocked.contains(.jewelCollector))
        XCTAssertFalse(progress.progress.isUnlocked(.royalCollector))
        progress.record(result(jewels: 399))
        XCTAssertFalse(progress.progress.isUnlocked(.royalCollector))
        progress.record(result(jewels: 1))
        XCTAssertTrue(progress.progress.isUnlocked(.royalCollector))
    }

    func testScoreStarterAndHighScorerAreSingleRun() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        progress.record(result(score: 99, jewels: 5))
        progress.record(result(score: 99, jewels: 5))
        XCTAssertFalse(progress.progress.isUnlocked(.scoreStarter), "Scores don't add up across runs")
        progress.record(result(score: 100, jewels: 5))
        XCTAssertTrue(progress.progress.isUnlocked(.scoreStarter))
        XCTAssertFalse(progress.progress.isUnlocked(.highScorer))
        progress.record(result(score: 500, jewels: 20, mode: .timeChallenge, endReason: .timeUp))
        XCTAssertTrue(progress.progress.isUnlocked(.highScorer), "Any mode counts")
    }

    func testSurvivorRequiresFinishingATimedRunWithoutLosingALife() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        progress.record(result(score: 300, jewels: 15, livesLost: 0, endReason: nil))
        XCTAssertFalse(progress.progress.isUnlocked(.survivor), "An unfinished run doesn't count")
        progress.record(result(score: 300, jewels: 15, mode: .timeChallenge, livesLost: 1, endReason: .timeUp))
        XCTAssertFalse(progress.progress.isUnlocked(.survivor))
        let summary = progress.record(result(score: 300, jewels: 15, mode: .timeChallenge, livesLost: 0, endReason: .timeUp))
        XCTAssertTrue(summary.newlyUnlocked.contains(.survivor))
    }

    func testDedicatedPlayerAfterTenGames() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        for _ in 0..<9 { progress.record(result()) }
        XCTAssertFalse(progress.progress.isUnlocked(.dedicatedPlayer))
        progress.record(result())
        XCTAssertTrue(progress.progress.isUnlocked(.dedicatedPlayer))
    }

    func testAchievementsUnlockOnlyOnce() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        let firstDate = date(2026, 1, 1)
        XCTAssertTrue(progress.record(result(score: 10, jewels: 1), at: firstDate).newlyUnlocked.contains(.firstCatch))
        XCTAssertFalse(progress.record(result(score: 10, jewels: 1), at: date(2026, 2, 1)).newlyUnlocked.contains(.firstCatch))
        XCTAssertEqual(progress.progress.unlockedAchievements[Achievement.firstCatch.rawValue], firstDate, "Unlock date isn't overwritten")
    }

    func testBonusAchievements() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        progress.record(result(score: 5_200, jewels: 150, byKind: [.gold: 10], maxCombo: 20, flawless: 1_000))
        for achievement: Achievement in [.crownJewel, .sovereign, .chainOfGems, .midasTouch, .flawlessReign] {
            XCTAssertTrue(progress.progress.isUnlocked(achievement), achievement.title)
        }
    }

    func testMidRunUnlocksPersistWithoutCountingTheRun() {
        let store = InMemoryKeyValueStore()
        let progress = ProgressStore(store: store)
        let inProgress = result(score: 120, jewels: 3, endReason: nil)
        let unlocked = progress.unlockAchievements(duringRun: inProgress)
        XCTAssertEqual(Set(unlocked), [.firstCatch, .scoreStarter])
        XCTAssertEqual(progress.progress.gamesPlayed, 0)
        XCTAssertEqual(progress.progress.totalJewels, 0, "Statistics wait for the run to finish")
        XCTAssertTrue(ProgressStore(store: store).progress.isUnlocked(.firstCatch), "Unlocks are saved immediately")
        XCTAssertTrue(progress.unlockAchievements(duringRun: inProgress).isEmpty, "No duplicates")

        let summary = progress.record(result(score: 120, jewels: 3))
        XCTAssertFalse(summary.newlyUnlocked.contains(.firstCatch))
        XCTAssertEqual(progress.progress.totalJewels, 3)
    }

    func testAchievementProgressForProgressBars() {
        var progress = PlayerProgress()
        progress.totalJewels = 42
        XCTAssertEqual(Achievement.jewelCollector.displayProgress(progress).current, 42)
        XCTAssertEqual(Achievement.jewelCollector.displayProgress(progress).target, 100)
        progress.totalJewels = 5_000
        XCTAssertEqual(Achievement.jewelCollector.displayProgress(progress).current, 100, "Capped at target")
        progress.highestScore = 250
        XCTAssertEqual(Achievement.highScorer.fractionComplete(progress), 0.5, accuracy: 1e-9)
    }

    func testCompletionAndHighlights() {
        var progress = PlayerProgress()
        XCTAssertEqual(progress.completionFraction, 0)
        XCTAssertNil(progress.latestAchievement)
        XCTAssertNotNil(progress.nextAchievement)

        progress.unlockedAchievements = [Achievement.firstCatch.rawValue: date(2026, 1, 1),
                                         Achievement.scoreStarter.rawValue: date(2026, 3, 1)]
        XCTAssertEqual(progress.unlockedCount, 2)
        XCTAssertEqual(progress.completionFraction, 2.0 / Double(Achievement.allCases.count), accuracy: 1e-9)
        XCTAssertEqual(progress.latestAchievement?.achievement, .scoreStarter)
        XCTAssertFalse(progress.nextAchievement.map(progress.isUnlocked) ?? true)
    }

    func testAchievementsHaveUniqueTitles() {
        XCTAssertEqual(Set(Achievement.allCases.map(\.title)).count, Achievement.allCases.count)
    }

    // MARK: - Daily challenge

    func testDailyChallengeIsStableForADate() {
        let morning = DailyChallenge.forDate(date(2026, 10, 26, hour: 1), calendar: calendar())
        let evening = DailyChallenge.forDate(date(2026, 10, 26, hour: 23), calendar: calendar())
        XCTAssertEqual(morning, evening)
        XCTAssertEqual(morning.dateKey, "2026-10-26")
        XCTAssertEqual(morning.duration, DailyChallenge.standardDuration)
    }

    func testDailyChallengeVariesAcrossDays() {
        let challenges = (1...28).map { DailyChallenge.forDate(date(2026, 2, $0), calendar: calendar()) }
        XCTAssertEqual(Set(challenges.map(\.dateKey)).count, 28)
        XCTAssertEqual(Set(challenges.map(\.seed)).count, 28)
        XCTAssertGreaterThan(Set(challenges.map(\.goal)).count, 3, "Goals vary from day to day")
    }

    func testDailyChallengeUsesLocalCalendarDay() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        // 2026-10-26 20:00 UTC is already 2026-10-27 in Tokyo.
        let instant = date(2026, 10, 26, hour: 20)
        XCTAssertEqual(DailyChallenge.forDate(instant, calendar: calendar()).dateKey, "2026-10-26")
        XCTAssertEqual(DailyChallenge.forDate(instant, calendar: tokyo).dateKey, "2026-10-27")
    }

    func testDailyGoalEvaluation() {
        func challenge(_ goal: DailyChallenge.Goal) -> DailyChallenge {
            DailyChallenge(dateKey: "2026-10-26", seed: 1, goal: goal, duration: 60)
        }
        let run = result(score: 800, jewels: 30, byKind: [.ruby: 12, .gold: 2], flawless: 500)

        XCTAssertTrue(challenge(.reachScore(800)).isCompleted(by: run))
        XCTAssertFalse(challenge(.reachScore(801)).isCompleted(by: run))
        XCTAssertTrue(challenge(.catchJewels(30)).isCompleted(by: run))
        XCTAssertFalse(challenge(.catchJewels(31)).isCompleted(by: run))
        XCTAssertTrue(challenge(.catchKind(.ruby, 12)).isCompleted(by: run))
        XCTAssertFalse(challenge(.catchKind(.gold, 3)).isCompleted(by: run))
        XCTAssertTrue(challenge(.flawless(score: 500)).isCompleted(by: run))
        XCTAssertFalse(challenge(.flawless(score: 550)).isCompleted(by: run))
        XCTAssertEqual(challenge(.catchKind(.gold, 3)).progress(for: run), 2)
    }

    func testDailyCompletionIsRecordedOnceAndRewardedOnce() {
        let store = InMemoryKeyValueStore()
        let progress = ProgressStore(store: store)
        let challenge = DailyChallenge(dateKey: "2026-10-26", seed: 1, goal: .reachScore(500), duration: 60)

        let miss = progress.record(result(score: 300, jewels: 15, mode: .daily(challenge), endReason: .timeUp))
        XCTAssertEqual(miss.dailyCompleted, false)
        XCTAssertFalse(progress.dailyRecord(for: challenge).completed)

        let win = progress.record(result(score: 600, jewels: 25, mode: .daily(challenge), endReason: .timeUp))
        XCTAssertEqual(win.dailyCompleted, true)
        XCTAssertTrue(win.dailyCompletedForFirstTime)
        XCTAssertTrue(win.newlyUnlocked.contains(.dailyChampion))

        let again = progress.record(result(score: 700, jewels: 30, mode: .daily(challenge), endReason: .timeUp))
        XCTAssertFalse(again.dailyCompletedForFirstTime)
        XCTAssertEqual(progress.progress.dailyChallengesCompleted, 1, "Each day counts once")

        let reloaded = ProgressStore(store: store)
        XCTAssertTrue(reloaded.dailyRecord(for: challenge).completed)
        XCTAssertEqual(reloaded.dailyRecord(for: challenge).bestScore, 700)
    }

    func testClassicRunsReportNoDailyResult() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        XCTAssertNil(progress.record(result(score: 100, jewels: 5)).dailyCompleted)
    }

    func testDailyDevotionAfterSevenDays() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        for day in 1...7 {
            let challenge = DailyChallenge(dateKey: "2026-10-0\(day)", seed: UInt64(day), goal: .catchJewels(1), duration: 60)
            progress.record(result(score: 10, jewels: 1, mode: .daily(challenge), endReason: .timeUp))
        }
        XCTAssertEqual(progress.progress.dailyChallengesCompleted, 7)
        XCTAssertTrue(progress.progress.isUnlocked(.dailyDevotion))
    }

    func testTimedModesUseTheirDurationAsTimeLimit() {
        let challenge = DailyChallenge.forDate(Date())
        XCTAssertEqual(GameMode.daily(challenge).config.timeLimit, challenge.duration)
        XCTAssertEqual(GameMode.timeChallenge.config.timeLimit, GameMode.timeChallengeDuration)
        XCTAssertNil(GameMode.classic.config.timeLimit)
        XCTAssertEqual(GameMode.timeChallenge.config.maxLives, 3)
    }
}
