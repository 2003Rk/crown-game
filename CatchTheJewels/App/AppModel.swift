import Foundation
import Observation

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case play
    case achievements
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .play: return "Play"
        case .achievements: return "Achievements"
        case .profile: return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .play: return "gamecontroller.fill"
        case .achievements: return "trophy.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

/// App-wide navigation and game lifecycle — the single source of truth for which
/// tab is shown, which mode is selected in the lobby and which run is active.
/// Owns the shared services and makes sure at most one run exists at a time.
@MainActor
@Observable
final class AppModel {
    private(set) var selectedTab: AppTab
    /// The mode highlighted in the Play lobby.
    var selectedMode: GameModeKind = .classic
    var isGamePresented = false
    var isSettingsPresented = false
    private(set) var game: GameController?
    /// Achievements unlocked since the player last viewed the Achievements tab.
    private(set) var recentlyUnlocked: Set<Achievement> = []

    let settings: SettingsStore
    let progress: ProgressStore
    let profile: PlayerProfileStore
    @ObservationIgnored let audio: AudioManager
    @ObservationIgnored let haptics: HapticsManager
    @ObservationIgnored let launchOptions: LaunchOptions

    init(store: KeyValueStore, launchOptions: LaunchOptions = LaunchOptions()) {
        self.launchOptions = launchOptions
        settings = SettingsStore(store: store)
        progress = ProgressStore(store: store)
        profile = PlayerProfileStore(store: store)
        audio = AudioManager(settings: settings)
        haptics = HapticsManager(settings: settings)
        selectedTab = launchOptions.initialTab ?? .home
        if launchOptions.skipOnboarding {
            settings.hasCompletedOnboarding = true
        }
    }

    /// Today's challenge, based on the device's local date.
    var todaysChallenge: DailyChallenge {
        DailyChallenge.forDate(Date())
    }

    /// A paused run the player left via Home, ready to resume.
    var suspendedGame: GameController? {
        guard let game, !isGamePresented, game.phase != .gameOver else { return nil }
        return game
    }

    // MARK: - Navigation

    func select(_ tab: AppTab) {
        guard selectedTab != tab else { return }
        haptics.play(.selection)
        selectedTab = tab
    }

    /// Opens the Play lobby with a mode highlighted. Never starts a run by itself.
    func openPlay(mode: GameModeKind? = nil) {
        if let mode { selectedMode = mode }
        select(.play)
    }

    func markAchievementsSeen() {
        recentlyUnlocked.removeAll()
    }

    // MARK: - Game lifecycle

    func mode(for kind: GameModeKind) -> GameMode {
        switch kind {
        case .classic: return .classic
        case .timeChallenge: return .timeChallenge
        case .daily: return .daily(todaysChallenge)
        }
    }

    func startSelectedMode() {
        startGame(mode(for: selectedMode))
    }

    func startGame(_ mode: GameMode) {
        // Ignore repeated taps while a game is already on screen.
        guard !isGamePresented else { return }
        game?.tearDown()
        let controller = GameController(mode: mode, settings: settings, progress: progress,
                                        audio: audio, haptics: haptics, scenario: launchOptions.scenario)
        controller.onAchievementsUnlocked = { [weak self] achievements in
            self?.recentlyUnlocked.formUnion(achievements)
        }
        game = controller
        selectedMode = mode.kind
        isGamePresented = true
    }

    func resumeSuspendedGame() {
        guard !isGamePresented, suspendedGame != nil else { return }
        isGamePresented = true
    }

    func abandonSuspendedGame() {
        guard suspendedGame != nil else { return }
        game?.tearDown()
        game = nil
    }

    func exitGame(_ exit: GameExit) {
        switch exit {
        case .suspend:
            game?.suspend()
        case .finish:
            game?.tearDown()
            game = nil
        }
        isGamePresented = false
        selectedTab = .home
    }

    /// Called if the full-screen cover is dismissed by the system rather than a button.
    func gameCoverDismissed() {
        if let game, game.phase == .gameOver {
            game.tearDown()
            self.game = nil
        }
    }
}
