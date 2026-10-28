import Foundation
import Observation

/// Player preferences, persisted on device. Every property writes through
/// immediately so nothing is lost if the app is terminated.
@MainActor
@Observable
final class SettingsStore {
    enum Key {
        static let onboardingCompleted = "settings.onboardingCompleted"
        static let soundEffects = "settings.soundEffects"
        static let music = "settings.music"
        static let haptics = "settings.haptics"
        static let reduceMotion = "settings.reduceMotion"
        static let largerCatcher = "settings.largerCatcher"
        static let tiltControls = "settings.tiltControls"
        static let sensitivity = "settings.controlSensitivity"
    }

    static let sensitivityRange: ClosedRange<Double> = 0.5...2.0
    static let defaultSensitivity = 1.0

    var hasCompletedOnboarding: Bool { didSet { store.set(hasCompletedOnboarding, forKey: Key.onboardingCompleted) } }
    var soundEffectsEnabled: Bool { didSet { store.set(soundEffectsEnabled, forKey: Key.soundEffects) } }
    var musicEnabled: Bool { didSet { store.set(musicEnabled, forKey: Key.music) } }
    var hapticsEnabled: Bool { didSet { store.set(hapticsEnabled, forKey: Key.haptics) } }
    /// In-app override; the system Reduce Motion setting is always honoured as well.
    var reduceMotion: Bool { didSet { store.set(reduceMotion, forKey: Key.reduceMotion) } }
    var largerCatcher: Bool { didSet { store.set(largerCatcher, forKey: Key.largerCatcher) } }
    var tiltControlsEnabled: Bool { didSet { store.set(tiltControlsEnabled, forKey: Key.tiltControls) } }
    /// Multiplier applied to drag and tilt movement. Persisted and read back clamped
    /// to `sensitivityRange`; use `effectiveSensitivity` when applying it.
    var controlSensitivity: Double {
        didSet { store.set(Self.clampSensitivity(controlSensitivity), forKey: Key.sensitivity) }
    }

    var effectiveSensitivity: Double { Self.clampSensitivity(controlSensitivity) }

    @ObservationIgnored private let store: KeyValueStore

    init(store: KeyValueStore) {
        self.store = store
        hasCompletedOnboarding = store.typedValue(forKey: Key.onboardingCompleted) ?? false
        soundEffectsEnabled = store.typedValue(forKey: Key.soundEffects) ?? true
        musicEnabled = store.typedValue(forKey: Key.music) ?? true
        hapticsEnabled = store.typedValue(forKey: Key.haptics) ?? true
        reduceMotion = store.typedValue(forKey: Key.reduceMotion) ?? false
        largerCatcher = store.typedValue(forKey: Key.largerCatcher) ?? false
        tiltControlsEnabled = store.typedValue(forKey: Key.tiltControls) ?? false
        let storedSensitivity: Double = store.typedValue(forKey: Key.sensitivity) ?? Self.defaultSensitivity
        controlSensitivity = Self.clampSensitivity(storedSensitivity)
    }

    /// Shows the onboarding again on the next pass through the root view.
    func resetTutorial() {
        hasCompletedOnboarding = false
    }

    static func clampSensitivity(_ value: Double) -> Double {
        guard value.isFinite else { return defaultSensitivity }
        return min(sensitivityRange.upperBound, max(sensitivityRange.lowerBound, value))
    }
}
