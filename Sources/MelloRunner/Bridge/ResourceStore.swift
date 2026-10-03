import Foundation
import os

/// Box wrapper allowing host objects (such as HTML DOM nodes, network requests, and JSContexts) to be retained across thread boundaries under lock.
public final class UncheckedSendableBox: @unchecked Sendable {
    public var value: Any
    public init(_ value: Any) {
        self.value = value
    }
}

/// Thread-safe storage managing outbound host buffer descriptors (`[Int32: Data]`) passed into the WebAssembly guest.
public final class ResourceStore: @unchecked Sendable {
    private struct State: @unchecked Sendable {
        var resources: [Int32: Data] = [:]
        var objects: [Int32: any Sendable] = [:]
        var nextDescriptor: Int32 = 1
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())

    public init() {}

    /// Stores data and returns a unique positive 32-bit integer descriptor.
    ///
    /// - Parameter data: The raw byte buffer to store.
    /// - Returns: A positive `Int32` descriptor handle identifying the buffer.
    @discardableResult
    public func store(_ data: Data) -> Int32 {
        lock.withLock { state in
            let descriptor = state.nextDescriptor
            state.resources[descriptor] = data
            // Advance descriptor, wrapping around positive values if needed
            if state.nextDescriptor == Int32.max {
                state.nextDescriptor = 1
            } else {
                state.nextDescriptor += 1
            }
            return descriptor
        }
    }

    /// Stores a string by encoding it as UTF-8 bytes and returns its descriptor.
    ///
    /// - Parameter string: The string to store.
    /// - Returns: A positive `Int32` descriptor handle identifying the string bytes.
    @discardableResult
    public func store(string: String) -> Int32 {
        store(Data(string.utf8))
    }

    /// Stores an arbitrary host object reference and returns a unique positive descriptor.
    ///
    /// - Parameter object: The host object reference to retain.
    /// - Returns: A positive `Int32` descriptor handle.
    @discardableResult
    public func storeObject(_ object: Any) -> Int32 {
        let box = UncheckedSendableBox(object)
        return lock.withLock { state in
            let descriptor = state.nextDescriptor
            state.objects[descriptor] = box
            if state.nextDescriptor == Int32.max {
                state.nextDescriptor = 1
            } else {
                state.nextDescriptor += 1
            }
            return descriptor
        }
    }

    /// Stores both raw data buffer and an associated host object under the same descriptor.
    ///
    /// - Parameters:
    ///   - data: The raw byte buffer to store.
    ///   - object: The associated host object reference to retain.
    /// - Returns: A positive `Int32` descriptor handle identifying the resource and object.
    @discardableResult
    public func store(data: Data, object: Any) -> Int32 {
        let box = UncheckedSendableBox(object)
        return lock.withLock { state in
            let descriptor = state.nextDescriptor
            state.resources[descriptor] = data
            state.objects[descriptor] = box
            if state.nextDescriptor == Int32.max {
                state.nextDescriptor = 1
            } else {
                state.nextDescriptor += 1
            }
            return descriptor
        }
    }

    /// Fetches an object reference associated with a descriptor, cast to type `T`.
    ///
    /// - Parameter descriptor: The descriptor handle to look up.
    /// - Returns: The stored object cast to `T`, or `nil` if missing or type mismatch.
    public func fetchObject<T>(_ descriptor: Int32) -> T? {
        let box = lock.withLock { state in
            state.objects[descriptor] as? UncheckedSendableBox
        }
        return box?.value as? T
    }

    /// Replaces or updates the object stored at an existing descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: The descriptor handle.
    ///   - object: The updated object value.
    public func setObject(_ descriptor: Int32, _ object: Any) {
        let box = UncheckedSendableBox(object)
        lock.withLock { state in
            state.objects[descriptor] = box
        }
    }

    /// Fetches the data buffer associated with a descriptor without removing it.
    ///
    /// - Parameter descriptor: The descriptor handle to look up.
    /// - Returns: The stored `Data`, or `nil` if the descriptor is invalid or has been destroyed.
    public func fetch(_ descriptor: Int32) -> Data? {
        lock.withLock { state in
            state.resources[descriptor]
        }
    }

    /// Returns the length in bytes of the buffer associated with the descriptor.
    ///
    /// - Parameter descriptor: The descriptor handle to look up.
    /// - Returns: The byte length if found, or `-1` if the descriptor is invalid.
    public func length(of descriptor: Int32) -> Int32 {
        lock.withLock { state in
            guard let data = state.resources[descriptor] else {
                return -1
            }
            return Int32(truncatingIfNeeded: data.count)
        }
    }

    /// Copies bytes from the stored buffer into the destination buffer.
    ///
    /// - Parameters:
    ///   - descriptor: The descriptor handle.
    ///   - destination: A mutable pointer to write into.
    ///   - count: The number of bytes to copy.
    /// - Returns: `0` on success, `-1` if invalid descriptor, `-2` if `count > data.count`.
    public func copyBytes(from descriptor: Int32, to destination: UnsafeMutableRawBufferPointer, count: Int) -> Int32 {
        guard let data = fetch(descriptor) else {
            return -1
        }
        guard count <= data.count else {
            return -2
        }
        guard let base = destination.baseAddress else {
            return -1
        }
        data.withUnsafeBytes { rawBuffer in
            guard let srcBase = rawBuffer.baseAddress else { return }
            base.copyMemory(from: srcBase, byteCount: count)
        }
        return 0
    }

    /// Removes and releases the buffer or object associated with the descriptor.
    ///
    /// - Parameter descriptor: The descriptor handle to remove.
    /// - Returns: The removed `Data`, or `nil` if it was not found as a data buffer.
    @discardableResult
    public func remove(_ descriptor: Int32) -> Data? {
        lock.withLock { state in
            state.objects.removeValue(forKey: descriptor)
            return state.resources.removeValue(forKey: descriptor)
        }
    }

    /// Returns the number of currently active resource descriptors.
    public var count: Int {
        lock.withLock { state in
            state.resources.count + state.objects.count
        }
    }

    /// Clears and releases all stored resource descriptors and objects.
    public func removeAll() {
        lock.withLock { state in
            state.resources.removeAll(keepingCapacity: false)
            state.objects.removeAll(keepingCapacity: false)
            state.nextDescriptor = 1
        }
    }
}
