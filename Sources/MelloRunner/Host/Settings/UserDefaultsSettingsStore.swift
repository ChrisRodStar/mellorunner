import Foundation

/// Persistent `UserDefaults`-backed implementation of `SettingsStore`.
public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    public let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public init?(suiteName: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.userDefaults = defaults
    }

    public func value(forKey key: String) -> (any Sendable)? {
        guard let obj = userDefaults.object(forKey: key) else { return nil }
        if let val = obj as? String { return val }
        if let val = obj as? Bool { return val }
        if let val = obj as? Int { return val }
        if let val = obj as? Double { return val }
        if let val = obj as? Float { return val }
        if let val = obj as? Data { return val }
        if let val = obj as? [String] { return val }
        return nil
    }

    public func set(_ value: (any Sendable)?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func removeValue(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}
