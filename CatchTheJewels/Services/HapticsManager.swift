import UIKit

/// Subtle haptic feedback that respects the player's Haptics setting.
@MainActor
final class HapticsManager {
    enum Event {
        case catchJewel
        case catchRare
        case hazard
        case bonus
        case gameOver
        case celebration
        case selection
    }

    private let settings: SettingsStore
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func prepare() {
        guard settings.hapticsEnabled else { return }
        light.prepare()
        medium.prepare()
        notification.prepare()
    }

    func play(_ event: Event) {
        guard settings.hapticsEnabled else { return }
        switch event {
        case .catchJewel: light.impactOccurred(intensity: 0.6)
        case .catchRare: medium.impactOccurred(intensity: 0.8)
        case .hazard: notification.notificationOccurred(.error)
        case .bonus: notification.notificationOccurred(.success)
        case .gameOver: notification.notificationOccurred(.warning)
        case .celebration: notification.notificationOccurred(.success)
        case .selection: selection.selectionChanged()
        }
    }
}
