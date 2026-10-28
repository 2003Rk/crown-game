import XCTest
@testable import CatchTheJewels

final class GameSessionTests: XCTestCase {
    /// A classic session advanced past its countdown.
    private func playingSession(_ mode: GameMode = .classic) -> GameSession {
        var session = GameSession(mode: mode)
        session.advance(by: session.config.countdownDuration)
        XCTAssertEqual(session.state, .playing)
        return session
    }

    // MARK: - Jewel values

    func testJewelScoreValues() {
        XCTAssertEqual(JewelKind.ruby.points, 10)
        XCTAssertEqual(JewelKind.sapphire.points, 15)
        XCTAssertEqual(JewelKind.emerald.points, 20)
        XCTAssertEqual(JewelKind.amethyst.points, 30)
        XCTAssertEqual(JewelKind.gold.points, 50)
    }

    func testRarerJewelsAreWorthMoreAndSpawnLess() {
        let kinds = JewelKind.allCases
        for (lower, higher) in zip(kinds, kinds.dropFirst()) {
            XCTAssertLessThan(lower.points, higher.points)
            XCTAssertGreaterThan(lower.spawnWeight, higher.spawnWeight)
        }
    }

    func testEveryJewelHasDistinctShapeDescription() {
        XCTAssertEqual(Set(JewelKind.allCases.map(\.shapeDescription)).count, JewelKind.allCases.count)
    }

    // MARK: - Countdown

    func testCountdownStartsTheRun() {
        var session = GameSession(mode: .classic)
        XCTAssertEqual(session.state, .countdown)
        XCTAssertEqual(session.countdownNumber, 3)

        XCTAssertEqual(session.advance(by: 1.0), [.countdown(2)])
        XCTAssertEqual(session.advance(by: 1.0), [.countdown(1)])
        XCTAssertEqual(session.advance(by: 1.0), [.started])
        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.elapsed, 0, "Countdown time doesn't count as play time")
    }

    func testCatchesAreIgnoredDuringCountdown() {
        var session = GameSession(mode: .classic)
        XCTAssertEqual(session.register(.jewel(.gold)), .ignored)
        XCTAssertEqual(session.score, 0)
    }

    // MARK: - Scoring

    func testCatchingJewelAddsItsPoints() {
        var session = playingSession()
        XCTAssertEqual(session.register(.jewel(.emerald)), .jewel(.emerald, points: 20, multiplier: 1))
        XCTAssertEqual(session.score, 20)
        XCTAssertEqual(session.jewelsCaught, 1)
        XCTAssertEqual(session.caughtByKind[.emerald], 1)
    }

    func testComboMultiplierRisesEveryTenCatchesUpToFour() {
        var session = playingSession()
        for _ in 0..<9 { _ = session.register(.jewel(.ruby)) }
        XCTAssertEqual(session.multiplier, 1)
        XCTAssertEqual(session.score, 90)

        // The 10th consecutive catch is the first one doubled.
        XCTAssertEqual(session.register(.jewel(.ruby)), .jewel(.ruby, points: 20, multiplier: 2))
        XCTAssertEqual(session.score, 110)

        for _ in 0..<50 { _ = session.register(.jewel(.ruby)) }
        XCTAssertEqual(session.multiplier, 4, "Multiplier caps at ×4")
        XCTAssertEqual(session.maxCombo, 60)
    }

    func testMissedJewelResetsComboButNotLives() {
        var session = playingSession()
        for _ in 0..<12 { _ = session.register(.jewel(.ruby)) }
        XCTAssertEqual(session.multiplier, 2)

        XCTAssertTrue(session.registerMiss(.jewel(.sapphire)))
        XCTAssertEqual(session.combo, 0)
        XCTAssertEqual(session.multiplier, 1)
        XCTAssertEqual(session.lives, 3)
        XCTAssertEqual(session.maxCombo, 12, "Best combo is remembered")
    }

    func testMissedBombDoesNothing() {
        var session = playingSession()
        _ = session.register(.jewel(.ruby))
        XCTAssertFalse(session.registerMiss(.bomb))
        XCTAssertEqual(session.combo, 1)
    }

    // MARK: - Lives

    func testBombCostsALifeAndResetsCombo() {
        var session = playingSession()
        for _ in 0..<5 { _ = session.register(.jewel(.ruby)) }
        XCTAssertEqual(session.register(.bomb), .bomb(livesRemaining: 2))
        XCTAssertEqual(session.lives, 2)
        XCTAssertEqual(session.combo, 0)
        XCTAssertEqual(session.livesLost, 1)
    }

    func testBombsAreBlockedDuringInvulnerability() {
        var session = playingSession()
        _ = session.register(.bomb)
        XCTAssertTrue(session.isInvulnerable)
        XCTAssertEqual(session.register(.bomb), .bombBlocked)
        XCTAssertEqual(session.lives, 2)

        session.advance(by: session.config.invulnerabilityDuration + 0.01)
        XCTAssertFalse(session.isInvulnerable)
        XCTAssertEqual(session.register(.bomb), .bomb(livesRemaining: 1))
    }

    func testLosingAllLivesEndsTheRun() {
        var session = playingSession()
        for expected in [2, 1, 0] {
            XCTAssertEqual(session.register(.bomb), .bomb(livesRemaining: expected))
            session.advance(by: session.config.invulnerabilityDuration + 0.01)
        }
        XCTAssertEqual(session.state, .gameOver(.outOfLives))
        XCTAssertTrue(session.isGameOver)
        XCTAssertEqual(session.result.endReason, .outOfLives)

        // Nothing changes after game over.
        XCTAssertEqual(session.register(.jewel(.gold)), .ignored)
        XCTAssertEqual(session.advance(by: 1), [])
    }

    func testHeartRestoresLifeOrAwardsBonus() {
        var session = playingSession()
        XCTAssertEqual(session.register(.heart), .heartBonus(points: 100))
        XCTAssertEqual(session.lives, 3)
        XCTAssertEqual(session.score, 100)

        _ = session.register(.bomb)
        XCTAssertEqual(session.register(.heart), .lifeRestored(lives: 3))
        XCTAssertEqual(session.lives, 3, "Lives never exceed the maximum")
    }

    func testScoreBeforeFirstLifeLostTracksFlawlessScore() {
        var session = playingSession()
        for _ in 0..<5 { _ = session.register(.jewel(.gold)) }
        XCTAssertEqual(session.scoreBeforeFirstLifeLost, 250)
        _ = session.register(.bomb)
        for _ in 0..<5 { _ = session.register(.jewel(.gold)) }
        XCTAssertEqual(session.scoreBeforeFirstLifeLost, 250)
        XCTAssertEqual(session.score, 500)
    }

    // MARK: - Time

    func testTimedRunEndsWhenTimeExpires() {
        let challenge = DailyChallenge.forDate(Date(timeIntervalSince1970: 1_800_000_000))
        var session = playingSession(.daily(challenge))
        XCTAssertEqual(session.timeRemaining, challenge.duration)

        session.advance(by: challenge.duration - 1)
        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.timeRemaining ?? -1, 1, accuracy: 0.0001)

        XCTAssertEqual(session.advance(by: 2), [.gameOver(.timeUp)])
        XCTAssertEqual(session.state, .gameOver(.timeUp))
        XCTAssertEqual(session.elapsed, challenge.duration)
        XCTAssertEqual(session.timeRemaining, 0)
    }

    func testClassicRunHasNoTimeLimit() {
        var session = playingSession()
        XCTAssertNil(session.timeRemaining)
        session.advance(by: 10_000)
        XCTAssertEqual(session.state, .playing)
    }

    func testInvalidTimeDeltasAreIgnored() {
        var session = playingSession()
        session.advance(by: -1)
        session.advance(by: .nan)
        session.advance(by: .infinity)
        XCTAssertEqual(session.elapsed, 0)
    }

    // MARK: - Pause

    func testPauseFreezesTimeAndCatches() {
        var session = playingSession()
        session.advance(by: 5)
        session.pause()
        XCTAssertEqual(session.state, .paused)

        session.advance(by: 30)
        XCTAssertEqual(session.elapsed, 5)
        XCTAssertEqual(session.register(.jewel(.ruby)), .ignored)

        session.resume()
        XCTAssertEqual(session.state, .playing)
    }

    func testPauseDuringCountdownResumesCountdown() {
        var session = GameSession(mode: .classic)
        session.advance(by: 1)
        session.pause()
        session.resume()
        XCTAssertEqual(session.state, .countdown)
        XCTAssertEqual(session.countdownNumber, 2)
    }

    func testPauseAfterGameOverHasNoEffect() {
        var session = playingSession()
        for _ in 0..<3 {
            _ = session.register(.bomb)
            session.advance(by: 2)
        }
        session.pause()
        XCTAssertEqual(session.state, .gameOver(.outOfLives))
    }

    // MARK: - Result

    func testResultSummarisesTheRun() {
        var session = playingSession()
        _ = session.register(.jewel(.gold))
        _ = session.register(.jewel(.gold))
        _ = session.register(.jewel(.ruby))
        session.advance(by: 4)
        let result = session.result
        XCTAssertEqual(result.score, 110)
        XCTAssertEqual(result.jewelsCaught, 3)
        XCTAssertEqual(result.caught(.gold), 2)
        XCTAssertEqual(result.caught(.amethyst), 0)
        XCTAssertEqual(result.maxCombo, 3)
        XCTAssertEqual(result.duration, 4, accuracy: 0.0001)
        XCTAssertNil(result.endReason)
    }
}
