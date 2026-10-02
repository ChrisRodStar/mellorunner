import Foundation

/// Value assigned to an active search filter when executing a search query against a source extension.
public enum FilterValue: Sendable, Hashable, Identifiable {
    case text(id: String, value: String)
    case sort(SortFilterValue)
    case check(id: String, value: Int)
    case select(id: String, value: String)
    case multiselect(id: String, included: [String], excluded: [String])
    case range(id: String, from: Float?, to: Float?)

    public var id: String {
        switch self {
            case .text(let id, _): id
            case .sort(let value): value.id
            case .check(let id, _): id
            case .select(let id, _): id
            case .multiselect(let id, _, _): id
            case .range(let id, _, _): id
        }
    }
}

/// Value parameters for a sort filter.
public struct SortFilterValue: Sendable, Equatable, Hashable {
    public let id: String
    public let index: Int32
    public let ascending: Bool

    public init(id: String, index: Int, ascending: Bool) {
        self.id = id
        self.index = Int32(index)
        self.ascending = ascending
    }

    public init(id: String, index: Int32, ascending: Bool) {
        self.id = id
        self.index = index
        self.ascending = ascending
    }
}

extension FilterValue: Codable {
    private enum FilterType: UInt8 {
        case text = 0
        case sort = 1
        case check = 2
        case select = 3
        case multiselect = 4
        case range = 5
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case index
        case value
        case ascending
        case included
        case excluded
        case from
        case to
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeRaw = try container.decode(UInt8.self, forKey: .type)
        guard let type = FilterType(rawValue: typeRaw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown filter value type: \(typeRaw)"
            )
        }

        switch type {
            case .text:
                let id = try container.decode(String.self, forKey: .id)
                let value = try container.decode(String.self, forKey: .value)
                self = .text(id: id, value: value)
            case .sort:
                let id = try container.decode(String.self, forKey: .id)
                let index = try container.decode(Int32.self, forKey: .index)
                let ascending = try container.decode(Bool.self, forKey: .ascending)
                self = .sort(SortFilterValue(id: id, index: index, ascending: ascending))
            case .check:
                let id = try container.decode(String.self, forKey: .id)
                let value = try container.decode(Int.self, forKey: .value)
                self = .check(id: id, value: value)
            case .select:
                let id = try container.decode(String.self, forKey: .id)
                let value = try container.decode(String.self, forKey: .value)
                self = .select(id: id, value: value)
            case .multiselect:
                let id = try container.decode(String.self, forKey: .id)
                let included = try container.decode([String].self, forKey: .included)
                let excluded = try container.decode([String].self, forKey: .excluded)
                self = .multiselect(id: id, included: included, excluded: excluded)
            case .range:
                let id = try container.decode(String.self, forKey: .id)
                let from = try container.decodeIfPresent(Float.self, forKey: .from)
                let to = try container.decodeIfPresent(Float.self, forKey: .to)
                self = .range(id: id, from: from, to: to)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .text(let id, let value):
                try container.encode(FilterType.text.rawValue, forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(value, forKey: .value)
            case .sort(let value):
                try container.encode(FilterType.sort.rawValue, forKey: .type)
                try container.encode(value.id, forKey: .id)
                try container.encode(value.index, forKey: .index)
                try container.encode(value.ascending, forKey: .ascending)
            case .check(let id, let value):
                try container.encode(FilterType.check.rawValue, forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(value, forKey: .value)
            case .select(let id, let value):
                try container.encode(FilterType.select.rawValue, forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(value, forKey: .value)
            case .multiselect(let id, let included, let excluded):
                try container.encode(FilterType.multiselect.rawValue, forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(included, forKey: .included)
                try container.encode(excluded, forKey: .excluded)
            case .range(let id, let from, let to):
                try container.encode(FilterType.range.rawValue, forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encodeIfPresent(from, forKey: .from)
                try container.encodeIfPresent(to, forKey: .to)
        }
    }
}
