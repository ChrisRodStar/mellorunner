import Foundation
import os

/// Thread-safe storage managing outbound host buffer descriptors (`[Int32: Data]`) passed into the WebAssembly guest.
public final class ResourceStore: @unchecked Sendable {
    private struct State {
        var resources: [Int32: Data] = [:]
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

    /// Removes and releases the buffer associated with the descriptor.
    ///
    /// - Parameter descriptor: The descriptor handle to remove.
    /// - Returns: The removed `Data`, or `nil` if it was not found.
    @discardableResult
    public func remove(_ descriptor: Int32) -> Data? {
        lock.withLock { state in
            state.resources.removeValue(forKey: descriptor)
        }
    }

    /// Returns the number of currently active resource descriptors.
    public var count: Int {
        lock.withLock { state in
            state.resources.count
        }
    }

    /// Clears and releases all stored resource descriptors.
    public func removeAll() {
        lock.withLock { state in
            state.resources.removeAll(keepingCapacity: false)
            state.nextDescriptor = 1
        }
    }
}
