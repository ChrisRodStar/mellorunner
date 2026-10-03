import Foundation
import MelloRunner
import Testing

@Suite struct PostcardTests {
    // MARK: - VarInt & ZigZag Tests

    @Test("ZigZag encoding and decoding extremes")
    func zigZagEncodingAndDecodingExtremes() {
        let i16Cases: [Int16] = [0, 1, -1, 42, -42, 127, -128, .max, .min]
        for val in i16Cases {
            let encoded = VarInt.zigZagEncode(val)
            let decoded = VarInt.zigZagDecode(encoded)
            #expect(decoded == val)
        }

        let i32Cases: [Int32] = [0, 1, -1, 42, -42, 1000, -1000, .max, .min]
        for val in i32Cases {
            let encoded = VarInt.zigZagEncode(val)
            let decoded = VarInt.zigZagDecode(encoded)
            #expect(decoded == val)
        }

        let i64Cases: [Int64] = [0, 1, -1, 42, -42, 1_000_000, -1_000_000, .max, .min]
        for val in i64Cases {
            let encoded = VarInt.zigZagEncode(val)
            let decoded = VarInt.zigZagDecode(encoded)
            #expect(decoded == val)
        }
    }

    @Test("VarInt bounds and byte limits")
    func varIntBoundsAndByteLimits() throws {
        var buffer: [UInt8] = []

        // 0 encodes to 1 byte
        VarInt.encode(UInt32(0), into: &buffer)
        #expect(buffer == [0x00])

        // 127 encodes to 1 byte
        buffer.removeAll()
        VarInt.encode(UInt32(127), into: &buffer)
        #expect(buffer == [0x7F])

        // 128 encodes to 2 bytes: [0x80, 0x01]
        buffer.removeAll()
        VarInt.encode(UInt32(128), into: &buffer)
        #expect(buffer == [0x80, 0x01])

        // Decode round-trip
        var cursor = 0
        let decoded128 = try buffer.withUnsafeBytes { raw in
            try VarInt.decodeU32(from: raw, cursor: &cursor)
        }
        #expect(decoded128 == 128)
        #expect(cursor == 2)
    }

    @Test("VarInt overflow rejection")
    func varIntOverflowRejection() {
        // 6-byte varint sequence attempting to decode as u32
        let overflowU32Bytes: [UInt8] = [0x80, 0x80, 0x80, 0x80, 0x80, 0x01]
        overflowU32Bytes.withUnsafeBytes { raw in
            var cursor = 0
            #expect(throws: PostcardError.self) {
                try VarInt.decodeU32(from: raw, cursor: &cursor)
            }
        }

        // 5th byte of u32 has bits 4..6 set (which overflow 32 bits)
        let bitOverflowU32: [UInt8] = [0x80, 0x80, 0x80, 0x80, 0x70]
        bitOverflowU32.withUnsafeBytes { raw in
            var cursor = 0
            #expect(throws: PostcardError.self) {
                try VarInt.decodeU32(from: raw, cursor: &cursor)
            }
        }
    }

    // MARK: - PostcardReader & PostcardWriter Primitives

    @Test("Primitive types round-trip through Writer and Reader")
    func primitiveTypesRoundTrip() throws {
        var writer = PostcardWriter()
        writer.writeU8(255)
        writer.writeI8(-128)
        writer.writeU16(65535)
        writer.writeI16(-32768)
        writer.writeU32(4_000_000_000)
        writer.writeI32(-2_000_000_000)
        writer.writeU64(18_000_000_000_000_000_000)
        writer.writeI64(-9_000_000_000_000_000_000)
        writer.writeF32(3.14159)
        writer.writeF64(2.718281828459)
        writer.writeBool(true)
        writer.writeBool(false)
        writer.writeOptionTag(hasValue: true)
        writer.writeString("Hello Postcard!")
        writer.writeOptionTag(hasValue: false)

        let data = writer.encodedData

        try PostcardReader.read(from: data) { reader in
            #expect(try reader.readU8() == 255)
            #expect(try reader.readI8() == -128)
            #expect(try reader.readU16() == 65535)
            #expect(try reader.readI16() == -32768)
            #expect(try reader.readU32() == 4_000_000_000)
            #expect(try reader.readI32() == -2_000_000_000)
            #expect(try reader.readU64() == 18_000_000_000_000_000_000)
            #expect(try reader.readI64() == -9_000_000_000_000_000_000)
            #expect(abs(try reader.readF32() - 3.14159) < 0.0001)
            #expect(abs(try reader.readF64() - 2.718281828459) < 0.00000001)
            #expect(try reader.readBool() == true)
            #expect(try reader.readBool() == false)
            #expect(try reader.readOptionTag() == true)
            #expect(try reader.readString() == "Hello Postcard!")
            #expect(try reader.readOptionTag() == false)
            try reader.verifyExhausted()
        }
    }

    @Test("Reject invalid boolean discriminants")
    func rejectInvalidBooleanDiscriminants() {
        let invalidBoolData = Data([0x02])
        #expect(throws: PostcardError.invalidBooleanDiscriminant(0x02)) {
            try PostcardReader.read(from: invalidBoolData) { reader in
                _ = try reader.readBool()
            }
        }
    }

    @Test("Reject invalid option discriminants")
    func rejectInvalidOptionDiscriminants() {
        let invalidOptionData = Data([0xFF])
        #expect(throws: PostcardError.invalidOptionDiscriminant(0xFF)) {
            try PostcardReader.read(from: invalidOptionData) { reader in
                _ = try reader.readOptionTag()
            }
        }
    }

    @Test("Reject malformed UTF-8 in strings")
    func rejectMalformedUTF8InStrings() {
        var writer = PostcardWriter()
        // Write string length 2, but follow with invalid UTF-8 bytes [0xFF, 0xFF]
        writer.writeSequenceLength(2)
        writer.writeU8(0xFF)
        writer.writeU8(0xFF)

        #expect(throws: PostcardError.invalidUTF8) {
            try PostcardReader.read(from: writer.encodedData) { reader in
                _ = try reader.readString()
            }
        }
    }

    @Test("Enforce maximum length limits")
    func enforceMaximumLengthLimits() {
        var writer = PostcardWriter()
        writer.writeSequenceLength(1024)

        #expect(throws: PostcardError.self) {
            try PostcardReader.read(from: writer.encodedData, maximumLength: 100) { reader in
                _ = try reader.readString()
            }
        }
    }

    @Test("Detect trailing bytes")
    func detectTrailingBytes() {
        let data = Data([0x01, 0x02, 0x03])
        #expect(throws: PostcardError.trailingBytes(remaining: 2)) {
            try PostcardReader.read(from: data) { reader in
                _ = try reader.readU8()
                try reader.verifyExhausted()
            }
        }
    }

    // MARK: - Codable Tests (PostcardDecoder & PostcardEncoder)

    private struct MangaPayload: Codable, Equatable {
        let id: String
        let title: String
        let chapterCount: Int32
        let score: Float
        let isCompleted: Bool
        let author: String?
        let tags: [String]
    }

    @Test("Codable struct round-trip with optional and array fields")
    func codableStructRoundTrip() throws {
        let original = MangaPayload(
            id: "manga-123",
            title: "Mello's Adventure",
            chapterCount: 54,
            score: 9.85,
            isCompleted: false,
            author: "Christopher",
            tags: ["Action", "Adventure", "Fantasy"]
        )

        let encoder = PostcardEncoder()
        let encodedData = try encoder.encode(original)

        let decoder = PostcardDecoder()
        let decoded = try decoder.decode(MangaPayload.self, from: encodedData)

        #expect(decoded == original)
    }

    @Test("Codable struct with nil optional field")
    func codableStructWithNilOptionalField() throws {
        let original = MangaPayload(
            id: "manga-456",
            title: "Unknown Author Manga",
            chapterCount: 1,
            score: 5.0,
            isCompleted: true,
            author: nil,
            tags: []
        )

        let encoder = PostcardEncoder()
        let encodedData = try encoder.encode(original)

        let decoder = PostcardDecoder()
        let decoded = try decoder.decode(MangaPayload.self, from: encodedData)

        #expect(decoded == original)
        #expect(decoded.author == nil)
        #expect(decoded.tags.isEmpty)
    }

    @Test("Codable top-level array of structs")
    func codableTopLevelArrayOfStructs() throws {
        let items = [
            MangaPayload(
                id: "1", title: "One", chapterCount: 10, score: 7.0, isCompleted: true, author: "A", tags: ["T1"]),
            MangaPayload(
                id: "2", title: "Two", chapterCount: 20, score: 8.0, isCompleted: false, author: nil,
                tags: ["T2", "T3"]),
        ]

        let encoder = PostcardEncoder()
        let data = try encoder.encode(items)

        let decoder = PostcardDecoder()
        let decoded = try decoder.decode([MangaPayload].self, from: data)

        #expect(decoded == items)
    }

    @Test("Codable nested arrays and optional elements")
    func codableNestedArraysAndOptionalElements() throws {
        let nested = [[1, 2], [3, 4, 5], []]
        let encoder = PostcardEncoder()
        let data = try encoder.encode(nested)

        let decoder = PostcardDecoder()
        let decoded = try decoder.decode([[Int]].self, from: data)
        #expect(decoded == nested)
    }

    @Test("Postcard Rust test vectors exact byte wire compatibility")
    func postcardRustTestVectorsCompatibility() throws {
        // Rust postcard wire format test vectors:
        // 1. bool true -> [0x01], false -> [0x00]
        let trueBytes = try PostcardEncoder().encode(true)
        #expect(trueBytes == Data([0x01]))
        let falseBytes = try PostcardEncoder().encode(false)
        #expect(falseBytes == Data([0x00]))

        // 2. u8: 42 -> [0x2A]
        let u8Bytes = try PostcardEncoder().encode(UInt8(42))
        #expect(u8Bytes == Data([0x2A]))

        // 3. u16: 300 (0x012C -> LEB128: [0xAC, 0x02])
        let u16Bytes = try PostcardEncoder().encode(UInt16(300))
        #expect(u16Bytes == Data([0xAC, 0x02]))

        // 4. i16: -42 (ZigZag: (-42 * -2) - 1 = 83 -> 0x53)
        let i16Bytes = try PostcardEncoder().encode(Int16(-42))
        #expect(i16Bytes == Data([0x53]))

        // 5. String: "hello" -> [0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F]
        let strBytes = try PostcardEncoder().encode("hello")
        #expect(strBytes == Data([0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F]))

        // 6. [u8]: [10, 20, 30] -> length 3 (0x03) followed by elements
        let sliceBytes = try PostcardEncoder().encode([UInt8(10), UInt8(20), UInt8(30)])
        #expect(sliceBytes == Data([0x03, 10, 20, 30]))

        // Verify decoding from exact bytes matches
        let dec = PostcardDecoder()
        #expect(try dec.decode(Bool.self, from: Data([0x01])) == true)
        #expect(try dec.decode(UInt16.self, from: Data([0xAC, 0x02])) == 300)
        #expect(try dec.decode(Int16.self, from: Data([0x53])) == -42)
        #expect(try dec.decode(String.self, from: Data([0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F])) == "hello")
        #expect(try dec.decode([UInt8].self, from: Data([0x03, 10, 20, 30])) == [10, 20, 30])
    }
}
