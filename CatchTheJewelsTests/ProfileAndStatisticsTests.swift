import XCTest
@testable import CatchTheJewels

@MainActor
final class ProfileAndStatisticsTests: XCTestCase {
    private func result(score: Int, jewels: Int, mode: GameMode = .classic, duration: TimeInterval = 42,
                        endReason: GameOverReason? = .outOfLives) -> GameResult {
        GameResult(mode: mode, score: score, jewelsCaught: jewels, caughtByKind: [:], maxCombo: 4,
                   livesLost: 3, bombsHit: 3, duration: duration, scoreBeforeFirstLifeLost: 0, endReason: endReason)
    }

    // MARK: - Profile

    func testNewPlayerDefaults() {
        let profile = PlayerProfileStore(store: InMemoryKeyValueStore())
        XCTAssertEqual(profile.nickname, "Royal Player")
        XCTAssertEqual(profile.avatar, .crown)
    }

    func testNicknameAndAvatarPersist() {
        let store = InMemoryKeyValueStore()
        let profile = PlayerProfileStore(store: store)
        profile.updateNickname("Queen Ruby")
        profile.avatar = .sapphire

        let reloaded = PlayerProfileStore(store: store)
        XCTAssertEqual(reloaded.nickname, "Queen Ruby")
        XCTAssertEqual(reloaded.avatar, .sapphire)
    }

    func testNicknameIsSanitised() {
        let profile = PlayerProfileStore(store: InMemoryKeyValueStore())
        profile.updateNickname("   King\n  Emerald   ")
        XCTAssertEqual(profile.nickname, "King Emerald")
        profile.updateNickname("   ")
        XCTAssertEqual(profile.nickname, PlayerProfileStore.defaultNickname, "Blank restores the default")
        profile.updateNickname(String(repeating: "A", count: 50))
        XCTAssertEqual(profile.nickname.count, PlayerProfileStore.maxNicknameLength)
    }

    func testInvalidStoredProfileFallsBackToDefaults() {
        let store = InMemoryKeyValueStore([
            PlayerProfileStore.Key.nickname: 42,
            PlayerProfileStore.Key.avatar: "dragon",
        ])
        let profile = PlayerProfileStore(store: store)
        XCTAssertEqual(profile.nickname, PlayerProfileStore.defaultNickname)
        XCTAssertEqual(profile.avatar, .crown)
    }

    // MARK: - Statistics

    func testStatisticsAccumulateConsistently() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        progress.record(result(score: 400, jewels: 20, duration: 50))
        progress.record(result(score: 650, jewels: 30, mode: .timeChallenge, duration: 60, endReason: .timeUp))
        progress.record(result(score: 300, jewels: 10, duration: 25))

        let stats = progress.progress
        XCTAssertEqual(stats.gamesPlayed, 3)
        XCTAssertEqual(stats.totalJewels, 60)
        XCTAssertEqual(stats.bestScore, 400, "Classic best ignores other modes")
        XCTAssertEqual(stats.bestTimeChallengeScore, 650)
        XCTAssertEqual(stats.highestScore, 650, "Highest single run spans all modes")
        XCTAssertEqual(stats.totalPlayTime, 135, accuracy: 1e-9)
        XCTAssertEqual(stats.lastRun?.score, 300)
        XCTAssertEqual(stats.lastRun?.mode, .classic)
        XCTAssertEqual(stats.lastRun?.jewels, 10)
    }

    func testSameRunIsNeverCountedTwice() {
        let progress = ProgressStore(store: InMemoryKeyValueStore())
        let run = result(score: 200, jewels: 12)
        XCTAssertTrue(progress.record(run).wasRecorded)
        let duplicate = progress.record(run)
        XCTAssertFalse(duplicate.wasRecorded)
        XCTAssertTrue(duplicate.newlyUnlocked.isEmpty)
        XCTAssertEqual(progress.progress.gamesPlayed, 1)
        XCTAssertEqual(progress.progress.totalJewels, 12)
    }

    func testTimeChallengeBestPersists() {
        let store = InMemoryKeyValueStore()
        let progress = ProgressStore(store: store)
        let first = progress.record(result(score: 500, jewels: 25, mode: .timeChallenge, endReason: .timeUp))
        XCTAssertTrue(first.isNewBest)
        let second = progress.record(result(score: 450, jewels: 20, mode: .timeChallenge, endReason: .timeUp))
        XCTAssertFalse(second.isNewBest)
        XCTAssertEqual(second.previousBest, 500)
        XCTAssertEqual(ProgressStore(store: store).bestScore(for: .timeChallenge), 500)
    }

    func testResetClearsOnlyGameProgress() {
        let store = InMemoryKeyValueStore()
        let model = AppModel(store: store)
        model.profile.updateNickname("Duke Amethyst")
        model.profile.avatar = .amethyst
        model.settings.soundEffectsEnabled = false
        model.settings.hasCompletedOnboarding = true
        model.progress.record(result(score: 900, jewels: 40))

        model.progress.resetAll()

        let reloaded = AppModel(store: store)
        XCTAssertEqual(reloaded.progress.progress, PlayerProgress())
        XCTAssertEqual(reloaded.profile.nickname, "Duke Amethyst")
        XCTAssertEqual(reloaded.profile.avatar, .amethyst)
        XCTAssertFalse(reloaded.settings.soundEffectsEnabled)
        XCTAssertTrue(reloaded.settings.hasCompletedOnboarding)
    }

    func testPlayTimeFormatting() {
        XCTAssertEqual(ProfileView.formatPlayTime(0), "0m 00s")
        XCTAssertEqual(ProfileView.formatPlayTime(245), "4m 05s")
        XCTAssertEqual(ProfileView.formatPlayTime(7_980), "2h 13m")
        XCTAssertEqual(ProfileView.formatPlayTime(-5), "0m 00s")
        XCTAssertEqual(ProfileView.formatPlayTime(.nan), "0m 00s")
    }

    // MARK: - Navigation

    func testTabsAndPlayLobbyNavigation() {
        let model = AppModel(store: InMemoryKeyValueStore())
        XCTAssertEqual(AppTab.allCases, [.home, .play, .achievements, .profile])
        XCTAssertEqual(model.selectedTab, .home)

        model.openPlay()
        XCTAssertEqual(model.selectedTab, .play)
        XCTAssertFalse(model.isGamePresented, "Opening Play never starts a run")

        model.select(.home)
        model.openPlay(mode: .daily)
        XCTAssertEqual(model.selectedTab, .play)
        XCTAssertEqual(model.selectedMode, .daily)

        for tab in AppTab.allCases {
            model.select(tab)
            XCTAssertEqual(model.selectedTab, tab)
        }
    }

    func testStartSelectedModeLaunchesThatMode() {
        let model = AppModel(store: InMemoryKeyValueStore())
        model.settings.soundEffectsEnabled = false
        model.settings.musicEnabled = false
        model.settings.hapticsEnabled = false

        model.selectedMode = .timeChallenge
        model.startSelectedMode()
        XCTAssertTrue(model.isGamePresented)
        XCTAssertEqual(model.game?.mode, .timeChallenge)
        model.exitGame(.finish)

        model.selectedMode = .daily
        model.startSelectedMode()
        XCTAssertEqual(model.game?.mode.dailyChallenge, model.todaysChallenge)
        model.exitGame(.finish)
        XCTAssertEqual(model.selectedTab, .home)
    }

    func testFinishedRunUpdatesSharedStatisticsAndAchievements() {
        let model = AppModel(store: InMemoryKeyValueStore())
        model.settings.soundEffectsEnabled = false
        model.settings.musicEnabled = false
        model.settings.hapticsEnabled = false

        model.startGame(.timeChallenge)
        guard let game = model.game else { return XCTFail("No game") }
        game.advance(by: 3)
        for _ in 0..<6 { _ = game.register(.jewel(.ruby)) }
        XCTAssertEqual(game.achievementToast, .firstCatch, "Unlocks are announced mid-run")
        XCTAssertTrue(model.recentlyUnlocked.contains(.firstCatch))
        for _ in 0..<60 { game.advance(by: 1) }

        XCTAssertEqual(game.phase, .gameOver)
        XCTAssertEqual(game.summary?.newlyUnlocked.contains(.firstCatch), true, "Game over lists mid-run unlocks")
        XCTAssertEqual(model.progress.progress.gamesPlayed, 1)
        XCTAssertEqual(model.progress.progress.totalJewels, 6)
        XCTAssertEqual(model.progress.progress.bestTimeChallengeScore, 60)
        XCTAssertTrue(model.progress.progress.isUnlocked(.survivor))

        model.markAchievementsSeen()
        XCTAssertTrue(model.recentlyUnlocked.isEmpty)
    }
}
