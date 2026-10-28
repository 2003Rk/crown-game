import Foundation

/// Minimal storage abstraction so stores can be backed by `UserDefaults` in the app
/// and by memory in tests and previews.
protocol KeyValueStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension KeyValueStore {
    /// Returns the stored value only if it exists and has the expected type.
    func typedValue<T>(forKey key: String, as type: T.Type = T.self) -> T? {
        object(forKey: key) as? T
    }
}

extension UserDefaults: KeyValueStore {}

final class InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: Any]

    init(_ initial: [String: Any] = [:]) {
        storage = initial
    }

    func object(forKey key: String) -> Any? {
        storage[key]
    }

    func set(_ value: Any?, forKey key: String) {
        storage[key] = value
    }

    func removeObject(forKey key: String) {
        storage[key] = nil
    }
}
