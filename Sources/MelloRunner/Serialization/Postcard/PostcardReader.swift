import Foundation

/// Zero-copy, bounded deserializer for the Postcard binary wire format.
public struct PostcardReader {
    private let buffer: UnsafeRawBufferPointer
    public private(set) var cursor: Int
    public let maximumLength: Int

    /// Initialize a reader over a raw buffer pointer.
    /// - Parameters:
    ///   - buffer: The raw byte buffer to read from.
    ///   - maximumLength: The maximum allowed length for dynamic sequences and strings. Defaults to 16MB.
    public init(
        buffer: UnsafeRawBufferPointer,
        maximumLength: Int = 16 * 1024 * 1024
    ) {
        self.buffer = buffer
        self.cursor = 0
        self.maximumLength = maximumLength
    }

    /// Convenience scoped reader for `Data` instances.
    public static func read<R>(
        from data: Data,
        maximumLength: Int = 16 * 1024 * 1024,
        _ body: (inout PostcardReader) throws -> R
    ) rethrows -> R {
        try data.withUnsafeBytes { rawBuffer in
            var reader = PostcardReader(buffer: rawBuffer, maximumLength: maximumLength)
            return try body(&reader)
        }
    }

    // MARK: - State & Bounds

    public var isAtEnd: Bool {
        cursor >= buffer.count
    }

    public var remainingBytes: Int {
        max(0, buffer.count - cursor)
    }

    public mutating func verifyExhausted() throws(PostcardError) {
        guard isAtEnd else {
            throw PostcardError.trailingBytes(remaining: remainingBytes)
        }
    }

    // MARK: - Primitive Deserialization

    public mutating func readU8() throws(PostcardError) -> UInt8 {
        guard cursor < buffer.count else {
            throw PostcardError.unexpectedEndOfInput
        }
        let byte = buffer[cursor]
        cursor += 1
        return byte
    }

    public mutating func readI8() throws(PostcardError) -> Int8 {
        Int8(bitPattern: try readU8())
    }

    public mutating func readU16() throws(PostcardError) -> UInt16 {
        try VarInt.decodeU16(from: buffer, cursor: &cursor)
    }

    public mutating func readI16() throws(PostcardError) -> Int16 {
        VarInt.zigZagDecode(try readU16())
    }

    public mutating func readU32() throws(PostcardError) -> UInt32 {
        try VarInt.decodeU32(from: buffer, cursor: &cursor)
    }

    public mutating func readI32() throws(PostcardError) -> Int32 {
        VarInt.zigZagDecode(try readU32())
    }

    public mutating func readU64() throws(PostcardError) -> UInt64 {
        try VarInt.decodeU64(from: buffer, cursor: &cursor)
    }

    public mutating func readI64() throws(PostcardError) -> Int64 {
        VarInt.zigZagDecode(try readU64())
    }

    public mutating func readF32() throws(PostcardError) -> Float {
        guard cursor + 4 <= buffer.count else {
            throw PostcardError.unexpectedEndOfInput
        }
        let u0 = UInt32(buffer[cursor])
        let u1 = UInt32(buffer[cursor + 1]) << 8
        let u2 = UInt32(buffer[cursor + 2]) << 16
        let u3 = UInt32(buffer[cursor + 3]) << 24
        cursor += 4
        return Float(bitPattern: u0 | u1 | u2 | u3)
    }

    public mutating func readF64() throws(PostcardError) -> Double {
        guard cursor + 8 <= buffer.count else {
            throw PostcardError.unexpectedEndOfInput
        }
        var bits: UInt64 = 0
        for i in 0..<8 {
            bits |= UInt64(buffer[cursor + i]) << (i * 8)
        }
        cursor += 8
        return Double(bitPattern: bits)
    }

    public mutating func readBool() throws(PostcardError) -> Bool {
        let byte = try readU8()
        switch byte {
            case 0x00: return false
            case 0x01: return true
            default: throw PostcardError.invalidBooleanDiscriminant(byte)
        }
    }

    /// Reads an Option discriminant tag: returns `true` if Some, `false` if None.
    public mutating func readOptionTag() throws(PostcardError) -> Bool {
        let byte = try readU8()
        switch byte {
            case 0x00: return false
            case 0x01: return true
            default: throw PostcardError.invalidOptionDiscriminant(byte)
        }
    }

    // MARK: - Strings and Sequences

    public mutating func readSequenceLength() throws(PostcardError) -> Int {
        let lengthU64 = try readU64()
        guard lengthU64 <= UInt64(Int.max) else {
            throw PostcardError.excessiveLength(requested: Int.max, maximum: maximumLength)
        }
        let length = Int(lengthU64)
        guard length <= maximumLength else {
            throw PostcardError.excessiveLength(requested: length, maximum: maximumLength)
        }
        return length
    }

    /// Read raw bytes borrowed directly from the input buffer without allocation.
    public mutating func readBytes(count: Int) throws(PostcardError) -> UnsafeRawBufferPointer {
        guard count >= 0 else {
            throw PostcardError.unexpectedEndOfInput
        }
        guard cursor + count <= buffer.count else {
            throw PostcardError.unexpectedEndOfInput
        }
        guard let base = buffer.baseAddress else {
            throw PostcardError.unexpectedEndOfInput
        }
        let slice = UnsafeRawBufferPointer(start: base.advanced(by: cursor), count: count)
        cursor += count
        return slice
    }

    public mutating func readString() throws(PostcardError) -> String {
        let length = try readSequenceLength()
        guard length > 0 else { return "" }
        let slice = try readBytes(count: length)

        guard let string = String(bytes: slice, encoding: .utf8) else {
            throw PostcardError.invalidUTF8
        }
        return string
    }

    public mutating func readOptionalString() throws(PostcardError) -> String? {
        if try readOptionTag() {
            return try readString()
        } else {
            return nil
        }
    }
}
