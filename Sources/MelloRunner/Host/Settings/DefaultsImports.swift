import Foundation
import WasmKit

/// Provides `defaults` host functions imported by WebAssembly source extensions to read and write key-value settings.
public final class DefaultsImports: @unchecked Sendable {
    public enum DefaultsResult: Int32 {
        case success = 0
        case invalidKey = -1
        case invalidValue = -2
        case failedEncoding = -3
        case failedDecoding = -4
    }

    public enum DefaultKind: UInt8 {
        case data = 0
        case bool = 1
        case int = 2
        case float = 3
        case string = 4
        case stringArray = 5
        case null = 6
    }

    public let resourceStore: ResourceStore
    public let settingsStore: any SettingsStore
    public let namespace: String

    public init(
        resourceStore: ResourceStore,
        settingsStore: any SettingsStore,
        namespace: String = ""
    ) {
        self.resourceStore = resourceStore
        self.settingsStore = settingsStore
        self.namespace = namespace
    }

    private func getMemory(from caller: borrowing Caller) -> Memory? {
        guard let instance = caller.instance else { return nil }
        guard let exportValue = instance.export("memory") else { return nil }
        guard case .memory(let memory) = exportValue else { return nil }
        return memory
    }

    private func readString(from memory: Memory, offset: UInt32, length: UInt32) -> String? {
        if length == 0 { return "" }
        let uOffset = UInt(offset)
        let uLength = Int(length)
        guard uOffset + UInt(uLength) <= memory.byteCount else { return nil }
        return memory.withUnsafeBufferPointer(offset: uOffset, count: uLength) { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
    }

    private func resolvedKey(_ key: String) -> String {
        namespace.isEmpty ? key : "\(namespace).\(key)"
    }

    /// Registers the `defaults` module functions into the given WasmKit `Imports`.
    public func register(into imports: inout Imports, store: Store) {
        // 1. defaults.get(key_pointer: i32, length: i32) -> i32 (descriptor)
        imports.define(
            module: "defaults",
            name: "get",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: DefaultsResult.invalidKey.rawValue))]
                }
                guard let key = self.readString(from: memory, offset: args[0].i32, length: args[1].i32) else {
                    return [.i32(UInt32(bitPattern: DefaultsResult.invalidKey.rawValue))]
                }

                let fullKey = self.resolvedKey(key)
                guard let object = self.settingsStore.value(forKey: fullKey) else {
                    return [.i32(UInt32(bitPattern: DefaultsResult.invalidValue.rawValue))]
                }

                do {
                    let encoder = PostcardEncoder()
                    let data: Data =
                        switch object {
                            case let val as Bool:
                                try encoder.encode(val)
                            case let val as Int32:
                                try encoder.encode(val)
                            case let val as Int:
                                try encoder.encode(Int32(truncatingIfNeeded: val))
                            case let val as Float:
                                try encoder.encode(val)
                            case let val as Double:
                                try encoder.encode(Float(val))
                            case let val as String:
                                try encoder.encode(val)
                            case let val as [String]:
                                try encoder.encode(val)
                            case let val as Data:
                                val
                            default:
                                throw BridgeError.deserializeError
                        }
                    let desc = self.resourceStore.store(data)
                    return [.i32(UInt32(bitPattern: desc))]
                } catch {
                    return [.i32(UInt32(bitPattern: DefaultsResult.failedEncoding.rawValue))]
                }
            }
        )

        // 2. defaults.set(key_pointer: i32, length: i32, value_kind: i32, value_pointer: i32) -> i32
        imports.define(
            module: "defaults",
            name: "set",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: DefaultsResult.invalidKey.rawValue))]
                }
                guard let key = self.readString(from: memory, offset: args[0].i32, length: args[1].i32) else {
                    return [.i32(UInt32(bitPattern: DefaultsResult.invalidKey.rawValue))]
                }

                guard let valueKind = DefaultKind(rawValue: UInt8(truncatingIfNeeded: args[2].i32)) else {
                    return [.i32(UInt32(bitPattern: DefaultsResult.invalidValue.rawValue))]
                }

                let valuePointer = UInt(args[3].i32)
                guard valuePointer + 4 <= memory.byteCount else {
                    return [.i32(UInt32(bitPattern: DefaultsResult.failedDecoding.rawValue))]
                }

                let totalLength: UInt32 = memory.withUnsafeBufferPointer(offset: valuePointer, count: 4) { raw in
                    raw.loadUnaligned(as: UInt32.self).littleEndian
                }
                let payloadLength = totalLength >= 8 ? Int(totalLength - 8) : 0
                guard valuePointer + 8 + UInt(payloadLength) <= memory.byteCount else {
                    return [.i32(UInt32(bitPattern: DefaultsResult.failedDecoding.rawValue))]
                }

                let data = memory.withUnsafeBufferPointer(offset: valuePointer + 8, count: payloadLength) { raw in
                    Data(raw)
                }

                let fullKey = self.resolvedKey(key)
                let decoder = PostcardDecoder()

                do {
                    let object: (any Sendable)? =
                        switch valueKind {
                            case .data:
                                data
                            case .bool:
                                try decoder.decode(Bool.self, from: data)
                            case .int:
                                Int(try decoder.decode(Int32.self, from: data))
                            case .float:
                                try decoder.decode(Float.self, from: data)
                            case .string:
                                try decoder.decode(String.self, from: data)
                            case .stringArray:
                                try decoder.decode([String].self, from: data)
                            case .null:
                                nil
                        }

                    self.settingsStore.set(object, forKey: fullKey)
                    return [.i32(UInt32(bitPattern: DefaultsResult.success.rawValue))]
                } catch {
                    return [.i32(UInt32(bitPattern: DefaultsResult.failedDecoding.rawValue))]
                }
            }
        )
    }

    /// Creates and returns a populated `Imports` instance containing the `defaults` module.
    public func makeImports(store: Store) -> Imports {
        var imports = Imports()
        register(into: &imports, store: store)
        return imports
    }
}
