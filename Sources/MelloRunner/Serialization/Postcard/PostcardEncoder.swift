import Foundation

/// Top-level Swift `Encoder` for serializing values into Postcard binary wire data.
public final class PostcardEncoder: Sendable {
    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let storage = EncoderStorage()
        let encoder = _PostcardEncoder(storage: storage, codingPath: [])
        try value.encode(to: encoder)
        return storage.writer.encodedData
    }
}

// MARK: - Internal Storage

private final class EncoderStorage {
    var writer = PostcardWriter()
}

// MARK: - Encoder Implementation

private struct _PostcardEncoder: Encoder {
    let storage: EncoderStorage
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        KeyedEncodingContainer(_PostcardKeyedEncoding<Key>(storage: storage, codingPath: codingPath))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        _PostcardUnkeyedEncoding(parentStorage: storage, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        _PostcardSingleValueEncoding(storage: storage, codingPath: codingPath)
    }
}

// MARK: - Keyed Container

private struct _PostcardKeyedEncoding<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let storage: EncoderStorage
    var codingPath: [CodingKey]

    mutating func encodeNil(forKey key: Key) throws {
        storage.writer.writeOptionTag(hasValue: false)
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        storage.writer.writeBool(value)
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        storage.writer.writeString(value)
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        storage.writer.writeF64(value)
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        storage.writer.writeF32(value)
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        storage.writer.writeI64(Int64(value))
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        storage.writer.writeI8(value)
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        storage.writer.writeI16(value)
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        storage.writer.writeI32(value)
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        storage.writer.writeI64(value)
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        storage.writer.writeU64(UInt64(value))
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        storage.writer.writeU8(value)
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        storage.writer.writeU16(value)
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        storage.writer.writeU32(value)
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        storage.writer.writeU64(value)
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        var path = codingPath
        path.append(key)
        let encoder = _PostcardEncoder(storage: storage, codingPath: path)
        try value.encode(to: encoder)
    }

    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            storage.writer.writeOptionTag(hasValue: true)
            try encode(value, forKey: key)
        } else {
            storage.writer.writeOptionTag(hasValue: false)
        }
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        var path = codingPath
        path.append(key)
        return KeyedEncodingContainer(_PostcardKeyedEncoding<NestedKey>(storage: storage, codingPath: path))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        var path = codingPath
        path.append(key)
        return _PostcardUnkeyedEncoding(parentStorage: storage, codingPath: path)
    }

    mutating func superEncoder() -> Encoder {
        _PostcardEncoder(storage: storage, codingPath: codingPath)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        var path = codingPath
        path.append(key)
        return _PostcardEncoder(storage: storage, codingPath: path)
    }
}

// MARK: - Unkeyed Container

private final class UnkeyedStaging {
    let parentStorage: EncoderStorage
    let elementsStorage = EncoderStorage()
    var count: Int = 0

    init(parentStorage: EncoderStorage) {
        self.parentStorage = parentStorage
    }

    deinit {
        parentStorage.writer.writeSequenceLength(count)
        parentStorage.writer.writeBytes(elementsStorage.writer.bytes)
    }
}

private struct _PostcardUnkeyedEncoding: UnkeyedEncodingContainer {
    private let staging: UnkeyedStaging
    var codingPath: [CodingKey]

    var count: Int {
        staging.count
    }

    init(parentStorage: EncoderStorage, codingPath: [CodingKey]) {
        self.staging = UnkeyedStaging(parentStorage: parentStorage)
        self.codingPath = codingPath
    }

    mutating func encodeNil() throws {
        staging.elementsStorage.writer.writeOptionTag(hasValue: false)
        staging.count += 1
    }

    mutating func encode(_ value: Bool) throws {
        staging.elementsStorage.writer.writeBool(value)
        staging.count += 1
    }

    mutating func encode(_ value: String) throws {
        staging.elementsStorage.writer.writeString(value)
        staging.count += 1
    }

    mutating func encode(_ value: Double) throws {
        staging.elementsStorage.writer.writeF64(value)
        staging.count += 1
    }

    mutating func encode(_ value: Float) throws {
        staging.elementsStorage.writer.writeF32(value)
        staging.count += 1
    }

    mutating func encode(_ value: Int) throws {
        staging.elementsStorage.writer.writeI64(Int64(value))
        staging.count += 1
    }

    mutating func encode(_ value: Int8) throws {
        staging.elementsStorage.writer.writeI8(value)
        staging.count += 1
    }

    mutating func encode(_ value: Int16) throws {
        staging.elementsStorage.writer.writeI16(value)
        staging.count += 1
    }

    mutating func encode(_ value: Int32) throws {
        staging.elementsStorage.writer.writeI32(value)
        staging.count += 1
    }

    mutating func encode(_ value: Int64) throws {
        staging.elementsStorage.writer.writeI64(value)
        staging.count += 1
    }

    mutating func encode(_ value: UInt) throws {
        staging.elementsStorage.writer.writeU64(UInt64(value))
        staging.count += 1
    }

    mutating func encode(_ value: UInt8) throws {
        staging.elementsStorage.writer.writeU8(value)
        staging.count += 1
    }

    mutating func encode(_ value: UInt16) throws {
        staging.elementsStorage.writer.writeU16(value)
        staging.count += 1
    }

    mutating func encode(_ value: UInt32) throws {
        staging.elementsStorage.writer.writeU32(value)
        staging.count += 1
    }

    mutating func encode(_ value: UInt64) throws {
        staging.elementsStorage.writer.writeU64(value)
        staging.count += 1
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let indexKey = IndexKey(intValue: staging.count)!
        var path = codingPath
        path.append(indexKey)
        let encoder = _PostcardEncoder(storage: staging.elementsStorage, codingPath: path)
        try value.encode(to: encoder)
        staging.count += 1
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<
        NestedKey
    > {
        let indexKey = IndexKey(intValue: staging.count)!
        var path = codingPath
        path.append(indexKey)
        staging.count += 1
        return KeyedEncodingContainer(
            _PostcardKeyedEncoding<NestedKey>(storage: staging.elementsStorage, codingPath: path))
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let indexKey = IndexKey(intValue: staging.count)!
        var path = codingPath
        path.append(indexKey)
        staging.count += 1
        return _PostcardUnkeyedEncoding(parentStorage: staging.elementsStorage, codingPath: path)
    }

    mutating func superEncoder() -> Encoder {
        let indexKey = IndexKey(intValue: staging.count)!
        var path = codingPath
        path.append(indexKey)
        staging.count += 1
        return _PostcardEncoder(storage: staging.elementsStorage, codingPath: path)
    }
}

// MARK: - Single Value Container

private struct _PostcardSingleValueEncoding: SingleValueEncodingContainer {
    let storage: EncoderStorage
    var codingPath: [CodingKey]

    mutating func encodeNil() throws {
        storage.writer.writeOptionTag(hasValue: false)
    }

    mutating func encode(_ value: Bool) throws {
        storage.writer.writeBool(value)
    }

    mutating func encode(_ value: String) throws {
        storage.writer.writeString(value)
    }

    mutating func encode(_ value: Double) throws {
        storage.writer.writeF64(value)
    }

    mutating func encode(_ value: Float) throws {
        storage.writer.writeF32(value)
    }

    mutating func encode(_ value: Int) throws {
        storage.writer.writeI64(Int64(value))
    }

    mutating func encode(_ value: Int8) throws {
        storage.writer.writeI8(value)
    }

    mutating func encode(_ value: Int16) throws {
        storage.writer.writeI16(value)
    }

    mutating func encode(_ value: Int32) throws {
        storage.writer.writeI32(value)
    }

    mutating func encode(_ value: Int64) throws {
        storage.writer.writeI64(value)
    }

    mutating func encode(_ value: UInt) throws {
        storage.writer.writeU64(UInt64(value))
    }

    mutating func encode(_ value: UInt8) throws {
        storage.writer.writeU8(value)
    }

    mutating func encode(_ value: UInt16) throws {
        storage.writer.writeU16(value)
    }

    mutating func encode(_ value: UInt32) throws {
        storage.writer.writeU32(value)
    }

    mutating func encode(_ value: UInt64) throws {
        storage.writer.writeU64(value)
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let encoder = _PostcardEncoder(storage: storage, codingPath: codingPath)
        try value.encode(to: encoder)
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
