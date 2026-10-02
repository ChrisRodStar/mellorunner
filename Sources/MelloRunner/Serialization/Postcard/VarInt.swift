import Foundation

/// Fast, bounded VarInt (LEB128) and ZigZag codec conforming to the Postcard wire specification.
public enum VarInt {
    // MARK: - ZigZag Encoding & Decoding

    @inline(__always)
    public static func zigZagEncode(_ n: Int16) -> UInt16 {
        (UInt16(bitPattern: n) &<< 1) ^ UInt16(bitPattern: n >> 15)
    }

    @inline(__always)
    public static func zigZagDecode(_ n: UInt16) -> Int16 {
        Int16(bitPattern: (n >> 1) ^ (~(n & 1) &+ 1))
    }

    @inline(__always)
    public static func zigZagEncode(_ n: Int32) -> UInt32 {
        (UInt32(bitPattern: n) &<< 1) ^ UInt32(bitPattern: n >> 31)
    }

    @inline(__always)
    public static func zigZagDecode(_ n: UInt32) -> Int32 {
        Int32(bitPattern: (n >> 1) ^ (~(n & 1) &+ 1))
    }

    @inline(__always)
    public static func zigZagEncode(_ n: Int64) -> UInt64 {
        (UInt64(bitPattern: n) &<< 1) ^ UInt64(bitPattern: n >> 63)
    }

    @inline(__always)
    public static func zigZagDecode(_ n: UInt64) -> Int64 {
        Int64(bitPattern: (n >> 1) ^ (~(n & 1) &+ 1))
    }

    // MARK: - VarInt Encoding

    public static func encode(_ value: UInt16, into buffer: inout [UInt8]) {
        var val = value
        while val >= 0x80 {
            buffer.append(UInt8(val & 0x7F) | 0x80)
            val >>= 7
        }
        buffer.append(UInt8(val))
    }

    public static func encode(_ value: UInt32, into buffer: inout [UInt8]) {
        var val = value
        while val >= 0x80 {
            buffer.append(UInt8(val & 0x7F) | 0x80)
            val >>= 7
        }
        buffer.append(UInt8(val))
    }

    public static func encode(_ value: UInt64, into buffer: inout [UInt8]) {
        var val = value
        while val >= 0x80 {
            buffer.append(UInt8(val & 0x7F) | 0x80)
            val >>= 7
        }
        buffer.append(UInt8(val))
    }

    // MARK: - VarInt Decoding

    public static func decodeU16(
        from buffer: UnsafeRawBufferPointer,
        cursor: inout Int
    ) throws(PostcardError) -> UInt16 {
        var result: UInt16 = 0
        var shift: UInt16 = 0

        for _ in 0..<3 {
            guard cursor < buffer.count else {
                throw PostcardError.unexpectedEndOfInput
            }
            let byte = buffer[cursor]
            cursor += 1

            let data = UInt16(byte & 0x7F)
            if shift == 14 && (byte & 0x7C) != 0 {
                throw PostcardError.varIntOverflow("u16 exceeds 16 bits")
            }
            result |= data << shift

            if (byte & 0x80) == 0 {
                return result
            }
            shift += 7
        }

        throw PostcardError.invalidVarInt("u16 exceeds 3 bytes limit")
    }

    public static func decodeU32(
        from buffer: UnsafeRawBufferPointer,
        cursor: inout Int
    ) throws(PostcardError) -> UInt32 {
        var result: UInt32 = 0
        var shift: UInt32 = 0

        for _ in 0..<5 {
            guard cursor < buffer.count else {
                throw PostcardError.unexpectedEndOfInput
            }
            let byte = buffer[cursor]
            cursor += 1

            let data = UInt32(byte & 0x7F)
            if shift == 28 && (byte & 0x70) != 0 {
                throw PostcardError.varIntOverflow("u32 exceeds 32 bits")
            }
            result |= data << shift

            if (byte & 0x80) == 0 {
                return result
            }
            shift += 7
        }

        throw PostcardError.invalidVarInt("u32 exceeds 5 bytes limit")
    }

    public static func decodeU64(
        from buffer: UnsafeRawBufferPointer,
        cursor: inout Int
    ) throws(PostcardError) -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0

        for _ in 0..<10 {
            guard cursor < buffer.count else {
                throw PostcardError.unexpectedEndOfInput
            }
            let byte = buffer[cursor]
            cursor += 1

            let data = UInt64(byte & 0x7F)
            if shift == 63 && (byte & 0x7E) != 0 {
                throw PostcardError.varIntOverflow("u64 exceeds 64 bits")
            }
            result |= data << shift

            if (byte & 0x80) == 0 {
                return result
            }
            shift += 7
        }

        throw PostcardError.invalidVarInt("u64 exceeds 10 bytes limit")
    }
}
