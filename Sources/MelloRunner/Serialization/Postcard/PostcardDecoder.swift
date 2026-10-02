import Foundation

/// Top-level Swift `Decoder` for deserializing Postcard binary wire data.
public final class PostcardDecoder: Sendable {
    public let maximumLength: Int

    public init(maximumLength: Int = 16 * 1024 * 1024) {
        self.maximumLength = maximumLength
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try data.withUnsafeBytes { rawBuffer in
            try decode(type, from: rawBuffer)
        }
    }

    public func decode<T: Decodable>(_ type: T.Type, from buffer: UnsafeRawBufferPointer) throws -> T {
        let storage = DecoderStorage(buffer: buffer, maximumLength: maximumLength)
        let decoder = _PostcardDecoder(storage: storage, codingPath: [])
        let value = try T(from: decoder)
        try storage.reader.verifyExhausted()
        return value
    }
}

// MARK: - Internal Storage

private final class DecoderStorage {
    var reader: PostcardReader

    init(buffer: UnsafeRawBufferPointer, maximumLength: Int) {
        self.reader = PostcardReader(buffer: buffer, maximumLength: maximumLength)
    }

    func decodeNil() throws -> Bool {
        do {
            let isSome = try reader.readOptionTag()
            return !isSome
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid option discriminant: \(error)")
            )
        }
    }
}

// MARK: - Decoder Implementation

private struct _PostcardDecoder: Decoder {
    let storage: DecoderStorage
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(_PostcardKeyedDecoding<Key>(storage: storage, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let count: Int
        do {
            count = try storage.reader.readSequenceLength()
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: codingPath, debugDescription: "Failed to read sequence length: \(error)")
            )
        }
        return _PostcardUnkeyedDecoding(storage: storage, codingPath: codingPath, count: count)
    }

    func singleValueContainer() -> SingleValueDecodingContainer {
        _PostcardSingleValueDecoding(storage: storage, codingPath: codingPath)
    }
}

// MARK: - Keyed Container

private struct _PostcardKeyedDecoding<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let storage: DecoderStorage
    var codingPath: [CodingKey]
    var allKeys: [Key] { [] }

    func contains(_ key: Key) -> Bool {
        // Postcard is a schema-driven positional binary format; fields are present unless EOF
        !storage.reader.isAtEnd
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        try storage.decodeNil()
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try mapError(key: key) { try storage.reader.readBool() }
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try mapError(key: key) { try storage.reader.readString() }
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try mapError(key: key) { try storage.reader.readF64() }
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try mapError(key: key) { try storage.reader.readF32() }
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try mapError(key: key) { Int(try storage.reader.readI64()) }
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try mapError(key: key) { try storage.reader.readI8() }
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try mapError(key: key) { try storage.reader.readI16() }
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try mapError(key: key) { try storage.reader.readI32() }
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try mapError(key: key) { try storage.reader.readI64() }
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try mapError(key: key) { UInt(try storage.reader.readU64()) }
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try mapError(key: key) { try storage.reader.readU8() }
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try mapError(key: key) { try storage.reader.readU16() }
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try mapError(key: key) { try storage.reader.readU32() }
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try mapError(key: key) { try storage.reader.readU64() }
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        var path = codingPath
        path.append(key)
        let decoder = _PostcardDecoder(storage: storage, codingPath: path)
        return try T(from: decoder)
    }

    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        let isNil = try decodeNil(forKey: key)
        return isNil ? nil : try decode(type, forKey: key)
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        var path = codingPath
        path.append(key)
        return KeyedDecodingContainer(_PostcardKeyedDecoding<NestedKey>(storage: storage, codingPath: path))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        var path = codingPath
        path.append(key)
        let count = try mapError(key: key) { try storage.reader.readSequenceLength() }
        return _PostcardUnkeyedDecoding(storage: storage, codingPath: path, count: count)
    }

    func superDecoder() throws -> Decoder {
        _PostcardDecoder(storage: storage, codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        var path = codingPath
        path.append(key)
        return _PostcardDecoder(storage: storage, codingPath: path)
    }

    private func mapError<R>(key: Key, _ operation: () throws -> R) throws -> R {
        do {
            return try operation()
        } catch {
            var path = codingPath
            path.append(key)
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: path, debugDescription: "\(error)")
            )
        }
    }
}

// MARK: - Unkeyed Container

private struct _PostcardUnkeyedDecoding: UnkeyedDecodingContainer {
    let storage: DecoderStorage
    var codingPath: [CodingKey]
    let count: Int?
    var currentIndex: Int = 0

    var isAtEnd: Bool {
        guard let count else { return storage.reader.isAtEnd }
        return currentIndex >= count
    }

    private func mapElementError<R>(_ operation: () throws -> R) throws -> R {
        do {
            return try operation()
        } catch {
            let indexKey = IndexKey(intValue: currentIndex)!
            var path = codingPath
            path.append(indexKey)
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: path, debugDescription: "\(error)")
            )
        }
    }

    mutating func decodeNil() throws -> Bool {
        let isNil = try mapElementError { try storage.decodeNil() }
        if isNil {
            currentIndex += 1
        }
        return isNil
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        let value = try mapElementError { try storage.reader.readBool() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: String.Type) throws -> String {
        let value = try mapElementError { try storage.reader.readString() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
        let value = try mapElementError { try storage.reader.readF64() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: Float.Type) throws -> Float {
        let value = try mapElementError { try storage.reader.readF32() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: Int.Type) throws -> Int {
        let value = try mapElementError { Int(try storage.reader.readI64()) }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        let value = try mapElementError { try storage.reader.readI8() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        let value = try mapElementError { try storage.reader.readI16() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        let value = try mapElementError { try storage.reader.readI32() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        let value = try mapElementError { try storage.reader.readI64() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
        let value = try mapElementError { UInt(try storage.reader.readU64()) }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        let value = try mapElementError { try storage.reader.readU8() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        let value = try mapElementError { try storage.reader.readU16() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        let value = try mapElementError { try storage.reader.readU32() }
        currentIndex += 1
        return value
    }

    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        let value = try mapElementError { try storage.reader.readU64() }
        currentIndex += 1
        return value
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let indexKey = IndexKey(intValue: currentIndex)!
        var path = codingPath
        path.append(indexKey)
        let decoder = _PostcardDecoder(storage: storage, codingPath: path)
        currentIndex += 1
        return try T(from: decoder)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let indexKey = IndexKey(intValue: currentIndex)!
        var path = codingPath
        path.append(indexKey)
        currentIndex += 1
        return KeyedDecodingContainer(_PostcardKeyedDecoding<NestedKey>(storage: storage, codingPath: path))
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let indexKey = IndexKey(intValue: currentIndex)!
        var path = codingPath
        path.append(indexKey)
        let nestedCount = try storage.reader.readSequenceLength()
        currentIndex += 1
        return _PostcardUnkeyedDecoding(storage: storage, codingPath: path, count: nestedCount)
    }

    mutating func superDecoder() throws -> Decoder {
        let indexKey = IndexKey(intValue: currentIndex)!
        var path = codingPath
        path.append(indexKey)
        currentIndex += 1
        return _PostcardDecoder(storage: storage, codingPath: path)
    }
}

// MARK: - Single Value Container

private struct _PostcardSingleValueDecoding: SingleValueDecodingContainer {
    let storage: DecoderStorage
    var codingPath: [CodingKey]

    func decodeNil() -> Bool {
        (try? storage.decodeNil()) ?? true
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        try mapError { try storage.reader.readBool() }
    }

    func decode(_ type: String.Type) throws -> String {
        try mapError { try storage.reader.readString() }
    }

    func decode(_ type: Double.Type) throws -> Double {
        try mapError { try storage.reader.readF64() }
    }

    func decode(_ type: Float.Type) throws -> Float {
        try mapError { try storage.reader.readF32() }
    }

    func decode(_ type: Int.Type) throws -> Int {
        try mapError { Int(try storage.reader.readI64()) }
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        try mapError { try storage.reader.readI8() }
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        try mapError { try storage.reader.readI16() }
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        try mapError { try storage.reader.readI32() }
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        try mapError { try storage.reader.readI64() }
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        try mapError { UInt(try storage.reader.readU64()) }
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try mapError { try storage.reader.readU8() }
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try mapError { try storage.reader.readU16() }
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try mapError { try storage.reader.readU32() }
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try mapError { try storage.reader.readU64() }
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let decoder = _PostcardDecoder(storage: storage, codingPath: codingPath)
        return try T(from: decoder)
    }

    private func mapError<R>(_ operation: () throws -> R) throws -> R {
        do {
            return try operation()
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: codingPath, debugDescription: "\(error)")
            )
        }
    }
}

private struct IndexKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
