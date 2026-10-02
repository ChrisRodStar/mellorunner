import Foundation
import os

/// Thread-safe in-memory key-value store for isolated execution, deterministic testing, and high-throughput benchmarks.
public final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private let lock: OSAllocatedUnfairLock<[String: any Sendable]>

    public init(initialValues: [String: any Sendable] = [:]) {
        self.lock = OSAllocatedUnfairLock(initialState: initialValues)
    }

    public func value(forKey key: String) -> (any Sendable)? {
        let boxed = lock.withLock { storage in
            storage[key]
        }
        return boxed
    }

    public func set(_ value: (any Sendable)?, forKey key: String) {
        lock.withLock { (storage: inout [String: any Sendable]) -> Void in
            if let value {
                storage[key] = value
            } else {
                storage.removeValue(forKey: key)
            }
        }
    }

    public func removeValue(forKey key: String) {
        lock.withLock { (storage: inout [String: any Sendable]) -> Void in
            storage.removeValue(forKey: key)
        }
    }

    /// Clears all keys stored in the in-memory dictionary.
    public func removeAll() {
        lock.withLock { storage in
            storage.removeAll(keepingCapacity: false)
        }
    }

    /// Snapshot dictionary of all currently stored key-value pairs.
    public var allValues: [String: any Sendable] {
        lock.withLock { storage in
            storage
        }
    }
}
