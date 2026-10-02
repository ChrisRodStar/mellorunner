import Foundation

/// Fast serializer for the Postcard binary wire format.
public struct PostcardWriter: Sendable {
    public private(set) var bytes: [UInt8]

    public init(capacity: Int = 128) {
        self.bytes = []
        self.bytes.reserveCapacity(capacity)
    }

    public var encodedData: Data {
        Data(bytes)
    }

    // MARK: - Primitives

    public mutating func writeU8(_ value: UInt8) {
        bytes.append(value)
    }

    public mutating func writeI8(_ value: Int8) {
        bytes.append(UInt8(bitPattern: value))
    }

    public mutating func writeU16(_ value: UInt16) {
        VarInt.encode(value, into: &bytes)
    }

    public mutating func writeI16(_ value: Int16) {
        VarInt.encode(VarInt.zigZagEncode(value), into: &bytes)
    }

    public mutating func writeU32(_ value: UInt32) {
        VarInt.encode(value, into: &bytes)
    }

    public mutating func writeI32(_ value: Int32) {
        VarInt.encode(VarInt.zigZagEncode(value), into: &bytes)
    }

    public mutating func writeU64(_ value: UInt64) {
        VarInt.encode(value, into: &bytes)
    }

    public mutating func writeI64(_ value: Int64) {
        VarInt.encode(VarInt.zigZagEncode(value), into: &bytes)
    }

    public mutating func writeF32(_ value: Float) {
        let bits = value.bitPattern
        bytes.append(UInt8(truncatingIfNeeded: bits))
        bytes.append(UInt8(truncatingIfNeeded: bits >> 8))
        bytes.append(UInt8(truncatingIfNeeded: bits >> 16))
        bytes.append(UInt8(truncatingIfNeeded: bits >> 24))
    }

    public mutating func writeF64(_ value: Double) {
        let bits = value.bitPattern
        for i in 0..<8 {
            bytes.append(UInt8(truncatingIfNeeded: bits >> (i * 8)))
        }
    }

    public mutating func writeBool(_ value: Bool) {
        bytes.append(value ? 0x01 : 0x00)
    }

    public mutating func writeOptionTag(hasValue: Bool) {
        bytes.append(hasValue ? 0x01 : 0x00)
    }

    public mutating func writeSequenceLength(_ count: Int) {
        precondition(count >= 0, "Sequence length must be non-negative")
        writeU64(UInt64(count))
    }

    public mutating func writeString(_ string: String) {
        let utf8 = string.utf8
        writeSequenceLength(utf8.count)
        bytes.append(contentsOf: utf8)
    }

    public mutating func writeOptionalString(_ string: String?) {
        if let string {
            writeOptionTag(hasValue: true)
            writeString(string)
        } else {
            writeOptionTag(hasValue: false)
        }
    }

    public mutating func writeBytes<C: Collection>(_ data: C) where C.Element == UInt8 {
        bytes.append(contentsOf: data)
    }
}
