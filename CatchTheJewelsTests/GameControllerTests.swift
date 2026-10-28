import XCTest
@testable import CatchTheJewels

/// Integration tests for the controller that ties rules, persistence and the scene together.
@MainActor
final class GameControllerTests: XCTestCase {
    private var model: AppModel!

    override func setUp() async throws {
        let store = InMemoryKeyValueStore()
        model = AppModel(store: store, launchOptions: LaunchOptions())
        model.settings.soundEffectsEnabled = false
        model.settings.musicEnabled = false
        model.settings.hapticsEnabled = false
    }

    override func tearDown() async throws {
        model.game?.tearDown()
        model = nil
    }

    private func makeController(_ mode: GameMode = .classic) -> GameController {
        GameController(mode: mode, settings: model.settings, progress: model.progress,
                       audio: model.audio, haptics: model.haptics)
    }

    func testCountdownThenPlaying() {
        let controller = makeController()
        XCTAssertEqual(controller.phase, .countdown)
        XCTAssertEqual(controller.hud.countdown, 3)
        controller.advance(by: 3)
        XCTAssertEqual(controller.phase, .playing)
        XCTAssertEqual(controller.hud.lives, 3)
        controller.tearDown()
    }

    func testHUDTracksScoreAndLives() {
        let controller = makeController()
        controller.advance(by: 3)
        _ = controller.register(.jewel(.gold))
        XCTAssertEqual(controller.hud.score, 50)
        _ = controller.register(.bomb)
        XCTAssertEqual(controller.hud.lives, 2)
        controller.tearDown()
    }

    func testPauseAndResume() {
        let controller = makeController()
        controller.advance(by: 3)
        controller.pause()
        XCTAssertEqual(controller.phase, .paused)
        XCTAssertFalse(controller.acceptsTime)
        controller.advance(by: 10)
        XCTAssertEqual(controller.session.elapsed, 0, "No time passes while paused")
        controller.resume()
        XCTAssertEqual(controller.phase, .playing)
        XCTAssertTrue(controller.acceptsTime)
        controller.tearDown()
    }

    func testGameOverRecordsRunExactlyOnce() {
        let controller = makeController()
        controller.advance(by: 3)
        _ = controller.register(.jewel(.amethyst))
        for _ in 0..<3 {
            _ = controller.register(.bomb)
            controller.advance(by: 2)
        }
        XCTAssertEqual(controller.phase, .gameOver)
        XCTAssertEqual(controller.summary?.result.score, 30)
        XCTAssertEqual(controller.summary?.isNewBest, true)
        XCTAssertEqual(model.progress.progress.gamesPlayed, 1)
        XCTAssertEqual(model.progress.progress.bestScore, 30)

        controller.advance(by: 5)
        _ = controller.register(.bomb)
        XCTAssertEqual(model.progress.progress.gamesPlayed, 1)
        controller.tearDown()
    }

    func testRestartStartsAFreshRun() {
        let controller = makeController()
        controller.advance(by: 3)
        _ = controller.register(.jewel(.gold))
        controller.pause()
        controller.restart()
        XCTAssertEqual(controller.phase, .countdown)
        XCTAssertEqual(controller.hud.score, 0)
        XCTAssertEqual(controller.hud.lives, 3)
        XCTAssertNil(controller.summary)
        XCTAssertEqual(model.progress.progress.gamesPlayed, 0, "Restarted runs aren't recorded")
        controller.tearDown()
    }

    func testDailyRunEndsOnTimeAndRecordsChallenge() {
        let challenge = DailyChallenge(dateKey: "2026-10-26", seed: 5, goal: .catchJewels(2), duration: 60)
        let controller = makeController(.daily(challenge))
        controller.advance(by: 3)
        _ = controller.register(.jewel(.ruby))
        _ = controller.register(.jewel(.ruby))
        XCTAssertEqual(controller.hud.secondsRemaining, 60)
        for _ in 0..<60 { controller.advance(by: 1.0) }
        XCTAssertEqual(controller.phase, .gameOver)
        XCTAssertEqual(controller.summary?.result.endReason, .timeUp)
        XCTAssertEqual(controller.summary?.dailyCompleted, true)
        XCTAssertTrue(model.progress.dailyRecord(for: challenge).completed)
        controller.tearDown()
    }

    func testComboBannerAppearsWhenMultiplierRises() {
        let controller = makeController()
        controller.advance(by: 3)
        for _ in 0..<9 { _ = controller.register(.jewel(.ruby)) }
        XCTAssertNil(controller.comboBanner)
        _ = controller.register(.jewel(.ruby))
        XCTAssertEqual(controller.comboBanner, 2)
        controller.registerMiss(.jewel(.ruby))
        XCTAssertNil(controller.comboBanner)
        controller.tearDown()
    }

    // MARK: - App model

    func testAppModelPreventsDoubleStart() {
        model.startGame(.classic)
        let first = model.game
        model.startGame(.classic)
        XCTAssertTrue(model.game === first, "A second start while presented is ignored")
        XCTAssertTrue(model.isGamePresented)
    }

    func testSuspendAndResumeRun() {
        model.startGame(.classic)
        model.game?.advance(by: 3)
        model.exitGame(.suspend)
        XCTAssertFalse(model.isGamePresented)
        XCTAssertEqual(model.selectedTab, .home)
        XCTAssertNotNil(model.suspendedGame)
        XCTAssertEqual(model.suspendedGame?.phase, .paused)

        model.resumeSuspendedGame()
        XCTAssertTrue(model.isGamePresented)
        XCTAssertNil(model.suspendedGame)
    }

    func testAbandonSuspendedRun() {
        model.startGame(.classic)
        model.exitGame(.suspend)
        model.abandonSuspendedGame()
        XCTAssertNil(model.game)
        XCTAssertNil(model.suspendedGame)
    }

    func testFinishClearsGame() {
        model.startGame(.classic)
        model.exitGame(.finish)
        XCTAssertNil(model.game)
        XCTAssertFalse(model.isGamePresented)
    }

    func testStartingNewGameReplacesSuspendedRun() {
        model.startGame(.classic)
        let first = model.game
        model.exitGame(.suspend)
        model.startGame(.daily(model.todaysChallenge))
        XCTAssertFalse(model.game === first)
        XCTAssertNotNil(model.game?.mode.dailyChallenge)
    }
}
