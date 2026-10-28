import Foundation
import Observation
import UIKit

/// Values the SwiftUI HUD displays. Kept separate from the session so SwiftUI only
/// re-renders when something visible changes, not on every frame.
struct HUDState: Equatable {
    var score = 0
    var lives = 3
    var maxLives = 3
    var multiplier = 1
    var countdown = 3
    var secondsRemaining: Int?
    var level = 1
}

enum GamePhase: Equatable {
    case countdown
    case playing
    case paused
    case gameOver
}

/// Owns one run: the rules (`GameSession`), the SpriteKit scene, and feedback.
/// The scene drives time; SwiftUI drives pause, restart and exit.
@MainActor
@Observable
final class GameController {
    let mode: GameMode
    private(set) var hud = HUDState()
    private(set) var phase: GamePhase = .countdown
    private(set) var summary: RunSummary?
    private(set) var comboBanner: Int?
    /// Achievement currently announced in the HUD.
    private(set) var achievementToast: Achievement?

    /// Called whenever achievements unlock, so other screens can celebrate them.
    @ObservationIgnored var onAchievementsUnlocked: (([Achievement]) -> Void)?

    @ObservationIgnored private(set) var session: GameSession
    @ObservationIgnored let scene: GameScene
    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored private let progress: ProgressStore
    @ObservationIgnored private let audio: AudioManager
    @ObservationIgnored private let haptics: HapticsManager
    @ObservationIgnored private let scenario: GameScenario
    @ObservationIgnored private var isTornDown = false
    @ObservationIgnored private var unlockedThisRun: [Achievement] = []
    @ObservationIgnored private var queuedToasts: [Achievement] = []

    init(mode: GameMode,
         settings: SettingsStore,
         progress: ProgressStore,
         audio: AudioManager,
         haptics: HapticsManager,
         scenario: GameScenario = .standard) {
        self.mode = mode
        self.settings = settings
        self.progress = progress
        self.audio = audio
        self.haptics = haptics
        self.scenario = scenario
        session = GameSession(mode: mode)
        scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.controller = self
        scene.resetRun(seed: Self.seed(for: mode), scenario: scenario)
        syncHUD()
        audio.prepare()
        haptics.prepare()
    }

    private static func seed(for mode: GameMode) -> UInt64 {
        switch mode {
        case .classic, .timeChallenge: return UInt64.random(in: UInt64.min...UInt64.max)
        case .daily(let challenge): return challenge.seed
        }
    }

    // MARK: - Queries used by the scene

    /// The scene advances time only while counting down or playing.
    var acceptsTime: Bool {
        session.state == .countdown || session.state == .playing
    }

    var isPlaying: Bool { session.state == .playing }

    var reduceMotion: Bool {
        settings.reduceMotion || UIAccessibility.isReduceMotionEnabled
    }

    // MARK: - Scene callbacks

    func advance(by delta: TimeInterval) {
        for event in session.advance(by: delta) {
            switch event {
            case .countdown:
                audio.play(.countdown)
            case .started:
                audio.play(.start)
                audio.startMusic()
                haptics.play(.selection)
            case .gameOver:
                finishRun()
            }
        }
        syncHUD()
    }

    func register(_ kind: FallingObjectKind) -> CatchOutcome {
        let previousMultiplier = session.multiplier
        let outcome = session.register(kind)
        switch outcome {
        case .jewel(let jewel, _, let multiplier):
            audio.play(.forJewel(jewel))
            haptics.play(jewel == .gold || jewel == .amethyst ? .catchRare : .catchJewel)
            if multiplier > previousMultiplier {
                comboBanner = multiplier
            }
        case .bomb:
            audio.play(.bomb)
            haptics.play(.hazard)
            comboBanner = nil
        case .lifeRestored, .heartBonus:
            audio.play(.heart)
            haptics.play(.bonus)
        case .bombBlocked, .ignored:
            break
        }
        if case .jewel = outcome {
            unlockLiveAchievements()
        } else if case .heartBonus = outcome {
            unlockLiveAchievements()
        }
        if session.isGameOver, phase != .gameOver {
            finishRun()
        }
        syncHUD()
        return outcome
    }

    func registerMiss(_ kind: FallingObjectKind) {
        if session.registerMiss(kind) {
            comboBanner = nil
        }
        syncHUD()
    }

    func clearComboBanner() {
        comboBanner = nil
    }

    /// Hides the current achievement toast and shows the next one, if queued.
    func dismissAchievementToast() {
        achievementToast = queuedToasts.isEmpty ? nil : queuedToasts.removeFirst()
    }

    private func unlockLiveAchievements() {
        let unlocked = progress.unlockAchievements(duringRun: session.result)
        guard !unlocked.isEmpty else { return }
        unlockedThisRun += unlocked
        announce(unlocked)
    }

    private func announce(_ achievements: [Achievement]) {
        audio.play(.achievement)
        haptics.play(.celebration)
        onAchievementsUnlocked?(achievements)
        queuedToasts += achievements
        if achievementToast == nil { dismissAchievementToast() }
    }

    // MARK: - Player controls

    func pause() {
        guard phase == .countdown || phase == .playing else { return }
        session.pause()
        scene.isPaused = true
        audio.pauseMusic()
        syncHUD()
    }

    func resume() {
        guard phase == .paused else { return }
        session.resume()
        scene.isPaused = false
        if session.state == .playing {
            audio.startMusic()
        }
        syncHUD()
    }

    /// Discards the current run and starts a fresh one with the same mode.
    func restart() {
        session = GameSession(mode: mode)
        summary = nil
        comboBanner = nil
        achievementToast = nil
        queuedToasts.removeAll()
        unlockedThisRun.removeAll()
        scene.resetRun(seed: Self.seed(for: mode), scenario: scenario)
        scene.isPaused = false
        audio.stopMusic()
        syncHUD()
    }

    /// Called when the game screen leaves the hierarchy while a run is active.
    func suspend() {
        pause()
    }

    /// Releases the scene and stops audio and sensors. The controller can't be reused afterwards.
    func tearDown() {
        guard !isTornDown else { return }
        isTornDown = true
        audio.stopMusic()
        scene.tearDown()
    }

    /// Re-applies settings that may have changed from the pause menu.
    func settingsDidChange() {
        audio.refreshMusic()
        scene.applySettings()
    }

    // MARK: - Private

    private func finishRun() {
        guard summary == nil else { return }
        audio.stopMusic()
        let recorded = progress.record(session.result)
        // The game-over card lists everything earned this run, including mid-run unlocks.
        summary = RunSummary(result: recorded.result,
                             previousBest: recorded.previousBest,
                             isNewBest: recorded.isNewBest,
                             newlyUnlocked: unlockedThisRun + recorded.newlyUnlocked,
                             dailyCompleted: recorded.dailyCompleted,
                             dailyCompletedForFirstTime: recorded.dailyCompletedForFirstTime,
                             wasRecorded: recorded.wasRecorded)
        scene.runDidEnd()
        achievementToast = nil
        queuedToasts.removeAll()
        if recorded.isNewBest || recorded.dailyCompletedForFirstTime {
            audio.play(.newBest)
            haptics.play(.celebration)
        } else {
            audio.play(.gameOver)
            haptics.play(.gameOver)
        }
        if !recorded.newlyUnlocked.isEmpty {
            audio.play(.achievement)
            onAchievementsUnlocked?(recorded.newlyUnlocked)
        }
    }

    private func syncHUD() {
        var next = hud
        next.score = session.score
        next.lives = session.lives
        next.maxLives = session.config.maxLives
        next.multiplier = session.multiplier
        next.countdown = session.countdownNumber
        next.secondsRemaining = session.timeRemaining.map { Int($0.rounded(.up)) }
        next.level = session.difficulty.level + 1
        if next != hud { hud = next }

        let nextPhase: GamePhase
        switch session.state {
        case .countdown: nextPhase = .countdown
        case .playing: nextPhase = .playing
        case .paused: nextPhase = .paused
        case .gameOver: nextPhase = summary == nil ? phase : .gameOver
        }
        if nextPhase != phase { phase = nextPhase }
    }
}
