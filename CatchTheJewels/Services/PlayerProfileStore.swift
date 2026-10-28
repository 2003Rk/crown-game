import Foundation
import Observation

/// Bundled avatars the player can choose from. All are drawn by `ArtworkPainter`.
enum PlayerAvatar: String, CaseIterable, Identifiable {
    case crown
    case ruby
    case sapphire
    case emerald
    case amethyst
    case goldStar

    var id: String { rawValue }

    var artwork: ArtworkKind {
        switch self {
        case .crown: return .crownEmblem
        case .ruby: return .jewel(.ruby)
        case .sapphire: return .jewel(.sapphire)
        case .emerald: return .jewel(.emerald)
        case .amethyst: return .jewel(.amethyst)
        case .goldStar: return .jewel(.gold)
        }
    }

    var displayName: String {
        switch self {
        case .crown: return "Crown"
        case .ruby: return "Ruby"
        case .sapphire: return "Sapphire"
        case .emerald: return "Emerald"
        case .amethyst: return "Amethyst"
        case .goldStar: return "Gold Star"
        }
    }
}

/// The local player profile. Not an account: nothing here leaves the device.
@MainActor
@Observable
final class PlayerProfileStore {
    enum Key {
        static let nickname = "profile.nickname"
        static let avatar = "profile.avatar"
    }

    static let defaultNickname = "Royal Player"
    static let maxNicknameLength = 20

    private(set) var nickname: String
    var avatar: PlayerAvatar {
        didSet { store.set(avatar.rawValue, forKey: Key.avatar) }
    }

    @ObservationIgnored private let store: KeyValueStore

    init(store: KeyValueStore) {
        self.store = store
        nickname = Self.sanitize(store.typedValue(forKey: Key.nickname) ?? "") ?? Self.defaultNickname
        avatar = (store.typedValue(forKey: Key.avatar) as String?).flatMap(PlayerAvatar.init(rawValue:)) ?? .crown
    }

    /// Saves a new nickname. Blank input restores the default; long input is trimmed.
    func updateNickname(_ raw: String) {
        nickname = Self.sanitize(raw) ?? Self.defaultNickname
        store.set(nickname, forKey: Key.nickname)
    }

    /// Trims whitespace and newlines, collapses inner runs of spaces and caps the
    /// length. Returns nil when nothing usable remains.
    static func sanitize(_ raw: String) -> String? {
        let words = raw.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let joined = words.joined(separator: " ")
        guard !joined.isEmpty else { return nil }
        return String(joined.prefix(maxNicknameLength))
    }
}
