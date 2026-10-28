import XCTest
@testable import CatchTheJewels

@MainActor
final class PersistenceTests: XCTestCase {
    private func result(score: Int = 0, jewels: Int = 0, mode: GameMode = .classic, gold: Int = 0,
                        maxCombo: Int = 0, livesLost: Int = 3, flawless: Int = 0) -> GameResult {
        GameResult(mode: mode, score: score, jewelsCaught: jewels,
                   caughtByKind: gold > 0 ? [.gold: gold] : [:],
                   maxCombo: maxCombo, livesLost: livesLost, bombsHit: livesLost,
                   duration: 30, scoreBeforeFirstLifeLost: flawless, endReason: .outOfLives)
    }

    // MARK: - Settings

    func testSettingsDefaults() {
        let settings = SettingsStore(store: InMemoryKeyValueStore())
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertTrue(settings.soundEffectsEnabled)
        XCTAssertTrue(settings.musicEnabled)
        XCTAssertTrue(settings.hapticsEnabled)
        XCTAssertFalse(settings.reduceMotion)
        XCTAssertFalse(settings.largerCatcher)
        XCTAssertFalse(settings.tiltControlsEnabled)
        XCTAssertEqual(settings.controlSensitivity, SettingsStore.defaultSensitivity)
    }

    func testSettingsPersistAcrossLaunches() {
        let store = InMemoryKeyValueStore()
        let first = SettingsStore(store: store)
        first.soundEffectsEnabled = false
        first.musicEnabled = false
        first.hapticsEnabled = false
        first.reduceMotion = true
        first.largerCatcher = true
        first.tiltControlsEnabled = true
        first.controlSensitivity = 1.5

        let second = SettingsStore(store: store)
        XCTAssertFalse(second.soundEffectsEnabled)
        XCTAssertFalse(second.musicEnabled)
        XCTAssertFalse(second.hapticsEnabled)
        XCTAssertTrue(second.reduceMotion)
        XCTAssertTrue(second.largerCatcher)
        XCTAssertTrue(second.tiltControlsEnabled)
        XCTAssertEqual(second.controlSensitivity, 1.5)
    }

    func testSensitivityIsClamped() {
        let store = InMemoryKeyValueStore()
        let settings = SettingsStore(store: store)
        settings.controlSensitivity = 10
        XCTAssertEqual(settings.effectiveSensitivity, SettingsStore.sensitivityRange.upperBound)
        XCTAssertEqual(SettingsStore(store: store).controlSensitivity, SettingsStore.sensitivityRange.upperBound)

        store.set(Double.nan, forKey: SettingsStore.Key.sensitivity)
        XCTAssertEqual(SettingsStore(store: store).controlSensitivity, SettingsStore.defaultSensitivity)
    }

    func testWrongTypedSettingsFallBackToDefaults() {
        let store = InMemoryKeyValueStore([
            SettingsStore.Key.soundEffects: "yes",
            SettingsStore.Key.sensitivity: "fast",
        ])
        let settings = SettingsStore(store: store)
        XCTAssertTrue(settings.soundEffectsEnabled)
        XCTAssertEqual(settings.controlSensitivity, SettingsStore.defaultSensitivity)
    }

    // MARK: - Onboarding

    func testOnboardingCompletionPersistsAndCanBeReset() {
        let store = InMemoryKeyValueStore()
        let settings = SettingsStore(store: store)
        settings.hasCompletedOnboarding = true
        XCTAssertTrue(SettingsStore(store: store).hasCompletedOnboarding)

        settings.resetTutorial()
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertFalse(SettingsStore(store: store).hasCompletedOnboarding)
    }

    func testSkipOnboardingLaunchOptionMarksComplete() {
        let model = AppModel(store: InMemoryKeyValueStore(), launchOptions: LaunchOptions.parse(["-skipOnboarding"]))
        XCTAssertTrue(model.settings.hasCompletedOnboarding)
    }

    // MARK: - High score

    func testHighScorePersistsAndOnlyIncreases() {
        let store = InMemoryKeyValueStore()
        let progress = ProgressStore(store: store)

        let first = progress.record(result(score: 500, jewels: 20))
        XCTAssertTrue(first.isNewBest)
        XCTAssertEqual(first.previousBest, 0)

        let second = progress.record(result(score: 300, jewels: 10))
        XCTAssertFalse(second.isNewBest)
        XCTAssertEqual(second.previousBest, 500)

        let reloaded = ProgressStore(store: store)
        XCTAssertEqual(reloaded.progress.bestScore, 500)
        XCTAssertEqual(reloaded.progress.totalJewels, 30)
        XCTAssertEqual(reloaded.progress.gamesPlayed, 2)
    }

    func testZeroScoreIsNeverANewBest() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        XCTAssertFalse(progress.record(result(score: 0)).isNewBest)
    }

    func testDailyRunsDoNotChangeClassicBest() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        let challenge = DailyChallenge.forDate(Date())
        progress.record(result(score: 900, jewels: 40, mode: .daily(challenge)))
        XCTAssertEqual(progress.progress.bestScore, 0)
        XCTAssertEqual(progress.dailyRecord(for: challenge).bestScore, 900)
        XCTAssertEqual(progress.bestScore(for: .daily(challenge)), 900)
        XCTAssertEqual(progress.progress.totalJewels, 40, "Daily jewels still count toward totals")
    }

    func testCorruptedProgressFallsBackToDefaults() {
        let store = InMemoryKeyValueStore([ProgressStore.storageKey: Data("not json".utf8)])
        let progress = ProgressStore(store: store)
        XCTAssertEqual(progress.progress, PlayerProgress())

        progress.record(result(score: 120, jewels: 4))
        XCTAssertEqual(ProgressStore(store: store).progress.bestScore, 120, "Recovers and saves normally")
    }

    func testPartialAndInvalidProgressIsRepaired() throws {
        let json = #"{"bestScore": 750, "totalJewels": -5, "totalPlayTime": "x", "unlockedAchievements": {"firstSparkle": 0, "bogus": 0}}"#
        let store = InMemoryKeyValueStore([ProgressStore.storageKey: Data(json.utf8)])
        let progress = ProgressStore(store: store).progress
        XCTAssertEqual(progress.bestScore, 750)
        XCTAssertEqual(progress.highestScore, 750, "Highest score is at least the best classic score")
        XCTAssertEqual(progress.totalJewels, 0)
        XCTAssertEqual(progress.gamesPlayed, 0)
        XCTAssertEqual(progress.totalPlayTime, 0)
        XCTAssertTrue(progress.isUnlocked(.firstCatch), "Legacy IDs are migrated")
        XCTAssertEqual(progress.unlockedAchievements.count, 1)
    }

    func testResetAllErasesProgress() {
        let store = InMemoryKeyValueStore()
        let progress = ProgressStore(store: store)
        progress.record(result(score: 999, jewels: 120))
        progress.resetAll()
        XCTAssertEqual(progress.progress, PlayerProgress())
        XCTAssertEqual(ProgressStore(store: store).progress, PlayerProgress())
    }

    func testDailyRecordsArePruned() {
        var progress = PlayerProgress()
        for day in 1...90 {
            progress.dailyRecords[String(format: "2026-%02d-%02d", (day - 1) / 28 + 1, (day - 1) % 28 + 1)] = .init(bestScore: day, completed: false)
        }
        progress.pruneDailyRecords()
        XCTAssertEqual(progress.dailyRecords.count, PlayerProgress.maxDailyRecords)
        XCTAssertNil(progress.dailyRecords["2026-01-01"], "Oldest records are dropped first")
        XCTAssertNotNil(progress.dailyRecords["2026-04-06"])
    }

    // MARK: - Ranks

    func testPlayerRanks() {
        XCTAssertEqual(PlayerRank.rank(forTotalJewels: 0).title, "Squire")
        XCTAssertEqual(PlayerRank.rank(forTotalJewels: 0).level, 1)
        XCTAssertEqual(PlayerRank.rank(forTotalJewels: 99).title, "Squire")
        XCTAssertEqual(PlayerRank.rank(forTotalJewels: 100).title, "Knight")
        XCTAssertEqual(PlayerRank.rank(forTotalJewels: 10_000).title, "Monarch")
        XCTAssertNil(PlayerRank.rank(forTotalJewels: 10_000).nextThreshold)
        XCTAssertEqual(PlayerRank.rank(forTotalJewels: 200).progress(totalJewels: 200), 0.5, accuracy: 1e-9)
        XCTAssertEqual(PlayerRank.rank(forTotalJewels: 10_000).progress(totalJewels: 10_000), 1)
        XCTAssertEqual(PlayerRank.rank(forTotalJewels: -10).title, "Squire")
    }

    // MARK: - Launch options

    func testLaunchOptionParsing() {
        let options = LaunchOptions.parse(["app", "-resetState", "-skipSplash", "-scenario", "bombsOnly", "-initialTab", "profile"])
        XCTAssertTrue(options.resetState)
        XCTAssertTrue(options.skipSplash)
        XCTAssertFalse(options.skipOnboarding)
        XCTAssertEqual(options.scenario, .bombsOnly)
        XCTAssertEqual(options.initialTab, .profile)
        XCTAssertNil(LaunchOptions.parse(["app", "-initialTab", "settings"]).initialTab, "Unknown tabs are ignored")

        let defaults = LaunchOptions.parse(["app", "-scenario"])
        XCTAssertEqual(defaults.scenario, .standard)
        XCTAssertNil(defaults.initialTab)
    }
}
