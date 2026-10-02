import Foundation
import WasmKit
import os

/// Provides standard `std` and `env` host functions imported by WebAssembly source extensions.
public final class StandardImports: @unchecked Sendable {
    public let resourceStore: ResourceStore
    public var printHandler: (@Sendable (String) -> Void)?
    public var partialResultHandler: (@Sendable (Data) -> Void)?

    private let dateFormatterLock = OSAllocatedUnfairLock(initialState: [String: DateFormatter]())

    public init(
        resourceStore: ResourceStore = ResourceStore(),
        printHandler: (@Sendable (String) -> Void)? = nil,
        partialResultHandler: (@Sendable (Data) -> Void)? = nil
    ) {
        self.resourceStore = resourceStore
        self.printHandler = printHandler
        self.partialResultHandler = partialResultHandler
    }

    /// Generates WasmKit `Imports` for both the `std` and `env` namespaces.
    ///
    /// - Parameter store: The `WasmKit.Store` into which the functions will be allocated.
    /// - Returns: A populated `Imports` structure ready for module instantiation.
    public func makeImports(store: Store) -> Imports {
        var imports = Imports()

        // MARK: - "std" Namespace
        // 1. std.destroy(descriptor: i32)
        imports.define(
            module: "std",
            name: "destroy",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [])) { [weak self] _, args in
                guard let self else { return [] }
                self.destroy(descriptor: Int32(bitPattern: args[0].i32))
                return []
            }
        )

        // 2. std.buffer_len(descriptor: i32) -> i32
        imports.define(
            module: "std",
            name: "buffer_len",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: -1))] }
                let length = self.bufferLength(descriptor: Int32(bitPattern: args[0].i32))
                return [.i32(UInt32(bitPattern: length))]
            }
        )

        // 3. std.read_buffer(descriptor: i32, buffer: i32, size: i32) -> i32
        imports.define(
            module: "std",
            name: "read_buffer",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) { [weak self] caller, args in
                guard let self else { return [.i32(UInt32(bitPattern: -1))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                let bufferOffset = UInt(args[1].i32)
                let size = Int(args[2].i32)

                guard let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: -3))] // failedMemoryWrite
                }

                guard bufferOffset + UInt(size) <= memory.byteCount else {
                    return [.i32(UInt32(bitPattern: -3))] // failedMemoryWrite out of bounds
                }

                let resultCode: Int32 = memory.withUnsafeMutableBufferPointer(offset: bufferOffset, count: size) { destBuffer in
                    self.resourceStore.copyBytes(from: descriptor, to: destBuffer, count: size)
                }
                return [.i32(UInt32(bitPattern: resultCode))]
            }
        )

        // 4. std.current_date() -> f64
        imports.define(
            module: "std",
            name: "current_date",
            Function(store: store, type: FunctionType(parameters: [], results: [.f64])) { [weak self] _, _ in
                guard let self else { return [.f64((-1.0).bitPattern)] }
                let now = self.currentDate()
                return [.f64(now.bitPattern)]
            }
        )

        // 5. std.utc_offset() -> i64
        imports.define(
            module: "std",
            name: "utc_offset",
            Function(store: store, type: FunctionType(parameters: [], results: [.i64])) { [weak self] _, _ in
                guard let self else { return [.i64(0)] }
                let offset = self.utcOffset()
                return [.i64(UInt64(bitPattern: offset))]
            }
        )

        // 6. std.parse_date(stringPtr, stringLen, formatPtr, formatLen, localePtr, localeLen, tzPtr, tzLen) -> f64
        imports.define(
            module: "std",
            name: "parse_date",
            Function(
                store: store,
                type: FunctionType(
                    parameters: [.i32, .i32, .i32, .i32, .i32, .i32, .i32, .i32],
                    results: [.f64]
                )
            ) { [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.f64((-1.0).bitPattern)]
                }
                let dateString = self.readString(from: memory, offset: args[0].i32, length: args[1].i32)
                let formatString = self.readString(from: memory, offset: args[2].i32, length: args[3].i32)
                let localeString = self.readString(from: memory, offset: args[4].i32, length: args[5].i32)
                let tzString = self.readString(from: memory, offset: args[6].i32, length: args[7].i32)

                guard let dateString, let formatString else {
                    return [.f64((-4.0).bitPattern)]
                }

                let timestamp = self.parseDate(
                    string: dateString,
                    format: formatString,
                    localeIdentifier: localeString,
                    timeZoneIdentifier: tzString
                )
                return [.f64(timestamp.bitPattern)]
            }
        )

        // MARK: - "env" Namespace
        // 1. env.abort()
        imports.define(
            module: "env",
            name: "abort",
            Function(store: store, type: FunctionType(parameters: [], results: [])) { _, _ in
                []
            }
        )

        // 2. env.print(offset: i32, length: i32)
        imports.define(
            module: "env",
            name: "print",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [])) { [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else { return [] }
                if let message = self.readString(from: memory, offset: args[0].i32, length: args[1].i32) {
                    if let handler = self.printHandler {
                        handler(message)
                    } else {
                        print("[Wasm Extension] \(message)")
                    }
                }
                return []
            }
        )

        // 3. env.sleep(seconds: i32)
        imports.define(
            module: "env",
            name: "sleep",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [])) { _, args in
                let seconds = Double(args[0].i32)
                if seconds > 0 && seconds <= 5.0 {
                    Thread.sleep(forTimeInterval: seconds)
                }
                return []
            }
        )

        // 4. env.send_partial_result(valuePointer: i32)
        imports.define(
            module: "env",
            name: "send_partial_result",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [])) { [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else { return [] }
                let pointer = UInt(args[0].i32)
                guard pointer + 8 <= memory.byteCount else { return [] }

                let length: UInt32 = memory.withUnsafeBufferPointer(offset: pointer, count: 4) { raw in
                    raw.loadUnaligned(as: UInt32.self).littleEndian
                }
                guard length >= 8, pointer + UInt(length) <= memory.byteCount else { return [] }

                let payloadLength = Int(length - 8)
                let partialData: Data = memory.withUnsafeBufferPointer(offset: pointer + 8, count: payloadLength) { raw in
                    Data(raw)
                }
                self.partialResultHandler?(partialData)
                return []
            }
        )

        return imports
    }

    // MARK: - Standard Operations

    /// Release a stored buffer descriptor.
    public func destroy(descriptor: Int32) {
        resourceStore.remove(descriptor)
    }

    /// Return the byte length of a stored buffer, or `-1` if not found.
    public func bufferLength(descriptor: Int32) -> Int32 {
        resourceStore.length(of: descriptor)
    }

    /// Return the current UNIX epoch timestamp in seconds.
    public func currentDate() -> Double {
        Date.now.timeIntervalSince1970
    }

    /// Return the local time zone offset in seconds (negated per Aidoku convention).
    public func utcOffset() -> Int64 {
        -Int64(TimeZone.current.secondsFromGMT())
    }

    /// Parse a date string according to a date format and optional locale and time zone identifiers.
    public func parseDate(
        string: String,
        format: String,
        localeIdentifier: String? = nil,
        timeZoneIdentifier: String? = nil
    ) -> Double {
        let cacheKey = "\(format)|\(localeIdentifier ?? "")|\(timeZoneIdentifier ?? "")"
        let formatter = dateFormatterLock.withLock { cache -> DateFormatter in
            if let existing = cache[cacheKey] {
                return existing
            }
            let df = DateFormatter()
            df.dateFormat = format
            if let localeIdentifier, !localeIdentifier.isEmpty {
                if localeIdentifier == "current" {
                    df.locale = Locale.current
                } else {
                    df.locale = Locale(identifier: localeIdentifier)
                }
            } else {
                df.locale = Locale(identifier: "en_US_POSIX")
            }
            if let timeZoneIdentifier, !timeZoneIdentifier.isEmpty {
                if timeZoneIdentifier == "current" {
                    df.timeZone = TimeZone.current
                } else {
                    df.timeZone = TimeZone(identifier: timeZoneIdentifier)
                }
            } else {
                df.timeZone = TimeZone(secondsFromGMT: 0)
            }
            cache[cacheKey] = df
            return df
        }

        guard let date = formatter.date(from: string) else {
            return -5.0
        }
        return date.timeIntervalSince1970
    }

    // MARK: - Private Helpers

    private func getMemory(from caller: borrowing Caller) -> Memory? {
        guard let instance = caller.instance else { return nil }
        guard let exportValue = instance.export("memory") else { return nil }
        guard case .memory(let memory) = exportValue else { return nil }
        return memory
    }

    private func readString(from memory: Memory, offset: UInt32, length: UInt32) -> String? {
        guard length > 0 else { return "" }
        let uOffset = UInt(offset)
        let uLength = Int(length)
        guard uOffset + UInt(uLength) <= memory.byteCount else { return nil }
        return memory.withUnsafeBufferPointer(offset: uOffset, count: uLength) { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
    }
}
