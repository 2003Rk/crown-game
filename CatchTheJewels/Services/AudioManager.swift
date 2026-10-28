import AVFoundation
import os

/// Plays sound effects and background music.
///
/// Uses the `.ambient` audio session category, so the game is silenced by the
/// Ring/Silent switch and mixes politely with audio from other apps.
@MainActor
final class AudioManager {
    enum Effect: String, CaseIterable {
        case ruby, sapphire, emerald, amethyst, gold
        case bomb, heart, countdown, start, gameOver, newBest, achievement, tap

        static func forJewel(_ kind: JewelKind) -> Effect {
            switch kind {
            case .ruby: return .ruby
            case .sapphire: return .sapphire
            case .emerald: return .emerald
            case .amethyst: return .amethyst
            case .gold: return .gold
            }
        }

        var fileName: String { "sfx_\(rawValue)" }
    }

    private static let voicesPerEffect = 3
    private static let musicVolume: Float = 0.45

    private let settings: SettingsStore
    private let logger = Logger(subsystem: "CatchTheJewels", category: "Audio")
    private var pools: [Effect: [AVAudioPlayer]] = [:]
    private var nextVoice: [Effect: Int] = [:]
    private var music: AVAudioPlayer?
    private var musicRequested = false
    private var isPrepared = false

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Configures the session and preloads effects. Safe to call repeatedly.
    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Audio session setup failed: \(error.localizedDescription)")
        }
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.fileName, withExtension: "caf") else {
                logger.error("Missing sound \(effect.fileName)")
                continue
            }
            pools[effect] = (0..<Self.voicesPerEffect).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
    }

    func play(_ effect: Effect) {
        guard settings.soundEffectsEnabled else { return }
        prepare()
        guard let pool = pools[effect], !pool.isEmpty else { return }
        let index = (nextVoice[effect] ?? 0) % pool.count
        nextVoice[effect] = index + 1
        let player = pool[index]
        player.currentTime = 0
        player.play()
    }

    // MARK: - Music

    func startMusic() {
        musicRequested = true
        refreshMusic()
    }

    func pauseMusic() {
        musicRequested = false
        music?.pause()
    }

    func stopMusic() {
        musicRequested = false
        music?.stop()
        music?.currentTime = 0
    }

    /// Re-applies the music preference, e.g. after it changes in Settings.
    func refreshMusic() {
        guard musicRequested, settings.musicEnabled else {
            music?.pause()
            return
        }
        prepare()
        if music == nil {
            guard let url = Bundle.main.url(forResource: "music_royal_loop", withExtension: "m4a") else {
                logger.error("Missing music loop")
                return
            }
            music = try? AVAudioPlayer(contentsOf: url)
            music?.numberOfLoops = -1
            music?.volume = Self.musicVolume
            music?.prepareToPlay()
        }
        if music?.isPlaying == false {
            music?.play()
        }
    }
}
