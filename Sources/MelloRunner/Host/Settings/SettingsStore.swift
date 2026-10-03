import Foundation

/// Protocol defining a thread-safe key-value store for source extension configuration and user settings.
public protocol SettingsStore: Sendable {
    /// Retrieves the object stored under the specified key.
    func value(forKey key: String) -> (any Sendable)?

    /// Sets or replaces the object stored under the specified key.
    func set(_ value: (any Sendable)?, forKey key: String)

    /// Removes the value associated with the specified key.
    func removeValue(forKey key: String)
}

extension SettingsStore {
    /// Removes the value associated with the specified key.
    public func removeValue(forKey key: String) {
        set(nil, forKey: key)
    }

    /// Registers a default value for the key if no value is currently stored.
    public func register(key: String, default defaultValue: any Sendable) {
        if value(forKey: key) == nil {
            set(defaultValue, forKey: key)
        }
    }

    /// Convenience typed accessor for boolean values.
    public func bool(forKey key: String) -> Bool? {
        value(forKey: key) as? Bool
    }

    /// Convenience typed accessor for integer values.
    public func int(forKey key: String) -> Int? {
        if let val = value(forKey: key) as? Int {
            return val
        }
        if let val = value(forKey: key) as? Int32 {
            return Int(val)
        }
        return nil
    }

    /// Convenience typed accessor for float values.
    public func float(forKey key: String) -> Float? {
        if let val = value(forKey: key) as? Float {
            return val
        }
        if let val = value(forKey: key) as? Double {
            return Float(val)
        }
        return nil
    }

    /// Convenience typed accessor for string values.
    public func string(forKey key: String) -> String? {
        value(forKey: key) as? String
    }

    /// Convenience typed accessor for string array values.
    public func stringArray(forKey key: String) -> [String]? {
        value(forKey: key) as? [String]
    }

    /// Convenience typed accessor for binary data values.
    public func data(forKey key: String) -> Data? {
        value(forKey: key) as? Data
    }
}
