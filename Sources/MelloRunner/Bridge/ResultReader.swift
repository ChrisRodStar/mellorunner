import Foundation
import WasmKit

/// Utilities for decoding guest return pointers, extracting Postcard payloads, and releasing guest memory.
public enum ResultReader {

    /// Reads and returns the raw Postcard payload from a guest return pointer, freeing the guest buffer upon extraction.
    ///
    /// - Parameters:
    ///   - result: The `Int32` return value from a guest WebAssembly function invocation.
    ///   - memory: The guest `Memory` instance.
    ///   - freeResult: An optional closure to invoke the guest's `free_result` export.
    /// - Returns: The extracted payload `Data`.
    /// - Throws: `BridgeError` if the result code indicates an error or if the memory header is invalid.
    public static func readResultData(
        result: Int32,
        memory: Memory,
        freeResult: ((Int32) throws -> Void)? = nil
    ) throws -> Data {
        // 1. Handle negative error codes
        if result < 0 {
            switch result {
            case -2: throw BridgeError.unimplemented
            case -3: throw BridgeError.networkError
            case -4: throw BridgeError.htmlError
            case -5: throw BridgeError.jsError
            case -6: throw BridgeError.canvasError
            case -7: throw BridgeError.utf8Error
            case -8: throw BridgeError.jsonParseError
            case -9: throw BridgeError.deserializeError
            default: throw BridgeError.unknownGuestErrorCode(result)
            }
        }

        let pointer = UInt(result)
        let memorySize = memory.byteCount

        // 2. Validate that the pointer can at least accommodate the 4-byte length header
        guard pointer + 4 <= memorySize else {
            throw BridgeError.invalidResultPointer(result)
        }

        let totalLength: UInt32 = memory.withUnsafeBufferPointer(offset: pointer, count: 4) { rawBuffer in
            rawBuffer.loadUnaligned(as: UInt32.self).littleEndian
        }

        // 3. Handle guest error message string (encoded with totalLength == UInt32.max)
        if totalLength == UInt32.max {
            defer {
                try? freeResult?(result)
            }

            guard pointer + 12 <= memorySize else {
                throw BridgeError.corruptedResultHeader("Insufficient memory to read error message header")
            }

            let stringTotalLength: UInt32 = memory.withUnsafeBufferPointer(offset: pointer + 8, count: 4) { rawBuffer in
                rawBuffer.loadUnaligned(as: UInt32.self).littleEndian
            }

            guard stringTotalLength >= 12 else {
                throw BridgeError.corruptedResultHeader("Invalid string total length: \(stringTotalLength)")
            }

            let stringLength = Int(stringTotalLength - 12)
            guard pointer + 12 + UInt(stringLength) <= memorySize else {
                throw BridgeError.corruptedResultHeader("Error message exceeds linear memory bounds")
            }

            let message = memory.withUnsafeBufferPointer(offset: pointer + 12, count: stringLength) { rawBuffer in
                String(decoding: rawBuffer, as: UTF8.self)
            }
            throw BridgeError.guestError(message)
        }

        // 4. Validate header length
        guard totalLength >= 8 else {
            throw BridgeError.corruptedResultHeader("Allocated length \(totalLength) is smaller than 8-byte header")
        }

        let payloadLength = Int(totalLength - 8)
        guard pointer + 8 + UInt(payloadLength) <= memorySize else {
            throw BridgeError.corruptedResultHeader("Payload length \(payloadLength) exceeds linear memory bounds")
        }

        // 5. Extract payload and free guest memory
        defer {
            try? freeResult?(result)
        }

        let payloadData: Data = memory.withUnsafeBufferPointer(offset: pointer + 8, count: payloadLength) { rawBuffer in
            Data(rawBuffer)
        }

        return payloadData
    }

    /// Reads, frames, and deserializes a Postcard-encoded value from a guest return pointer.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode into.
    ///   - result: The `Int32` return value from a guest function invocation.
    ///   - memory: The guest `Memory` instance.
    ///   - freeResult: An optional closure to invoke the guest's `free_result` export.
    ///   - decoder: The `PostcardDecoder` to use (defaults to a standard instance).
    /// - Returns: The deserialized instance of `T`.
    public static func decodeResult<T: Decodable>(
        _ type: T.Type,
        result: Int32,
        memory: Memory,
        freeResult: ((Int32) throws -> Void)? = nil,
        decoder: PostcardDecoder = PostcardDecoder()
    ) throws -> T {
        let data = try readResultData(result: result, memory: memory, freeResult: freeResult)
        return try decoder.decode(type, from: data)
    }
}
