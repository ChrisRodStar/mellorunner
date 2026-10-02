import Foundation

/// Filter specification defined by a source extension to customize exploration and search queries.
public struct Filter: Sendable, Hashable, Identifiable {
    /// Unique identifier for the filter.
    public var id: String

    /// User-facing display title for the filter.
    public var title: String?

    /// Whether this filter should be hidden from the primary search header UI.
    public var hideFromHeader: Bool?

    /// The specific type and configuration parameters of the filter.
    public var value: Value

    public var idValue: String { id }

    public enum Value: Sendable, Hashable {
        case text(placeholder: String?)
        case sort(canAscend: Bool = true, options: [String], defaultValue: SortDefault?)
        case check(name: String?, canExclude: Bool = false, defaultValue: Bool?)
        case select(SelectFilter)
        case multiselect(MultiSelectFilter)
        case note(String)
        case range(min: Float?, max: Float?, decimal: Bool = false)
    }

    /// Default selection for a sort filter.
    public struct SortDefault: Sendable, Codable, Hashable {
        public let index: Int
        public let ascending: Bool

        public init(index: Int, ascending: Bool) {
            self.index = index
            self.ascending = ascending
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.index = try container.decode(Int.self, forKey: .index)
            self.ascending = (try? container.decode(Bool.self, forKey: .ascending)) ?? false
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(index, forKey: .index)
            try container.encode(ascending, forKey: .ascending)
        }

        enum CodingKeys: String, CodingKey {
            case index
            case ascending
        }
    }

    public init(
        id: String,
        title: String? = nil,
        hideFromHeader: Bool? = nil,
        value: Value
    ) {
        self.id = id
        self.title = title
        self.hideFromHeader = hideFromHeader
        self.value = value
    }
}

/// Single-choice selection filter configuration.
public struct SelectFilter: Sendable, Hashable {
    public var isGenre: Bool
    public var usesTagStyle: Bool
    public var options: [String]
    public var ids: [String]?
    public var defaultValue: String?

    public init(
        isGenre: Bool = false,
        usesTagStyle: Bool? = nil,
        options: [String],
        ids: [String]? = nil,
        defaultValue: String? = nil
    ) {
        self.isGenre = isGenre
        self.usesTagStyle = usesTagStyle ?? isGenre
        self.options = options
        self.ids = ids
        self.defaultValue = defaultValue
    }
}

extension SelectFilter: Codable {
    private enum CodingKeys: String, CodingKey {
        case isGenre
        case canExclude
        case usesTagStyle
        case options
        case ids
        case defaultValue = "default"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isGenre = (try? container.decodeIfPresent(Bool.self, forKey: .isGenre)) ?? false
        self.usesTagStyle = (try? container.decodeIfPresent(Bool.self, forKey: .usesTagStyle)) ?? isGenre
        self.options = try container.decode([String].self, forKey: .options)
        self.ids = try container.decodeIfPresent([String].self, forKey: .ids)
        self.defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(isGenre as Bool?, forKey: .isGenre)
        try container.encodeIfPresent(usesTagStyle as Bool?, forKey: .usesTagStyle)
        try container.encode(options, forKey: .options)
        try container.encodeIfPresent(ids, forKey: .ids)
        try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
    }
}

/// Multi-choice selection filter configuration, supporting inclusion and exclusion.
public struct MultiSelectFilter: Sendable, Hashable {
    public var isGenre: Bool
    public var canExclude: Bool
    public var usesTagStyle: Bool
    public var options: [String]
    public var ids: [String]?
    public var defaultIncluded: [String]?
    public var defaultExcluded: [String]?

    public init(
        isGenre: Bool = false,
        canExclude: Bool = false,
        usesTagStyle: Bool? = nil,
        options: [String],
        ids: [String]? = nil,
        defaultIncluded: [String]? = nil,
        defaultExcluded: [String]? = nil
    ) {
        self.isGenre = isGenre
        self.canExclude = canExclude
        self.usesTagStyle = usesTagStyle ?? isGenre
        self.options = options
        self.ids = ids
        self.defaultIncluded = defaultIncluded
        self.defaultExcluded = defaultExcluded
    }
}

extension MultiSelectFilter: Codable {
    private enum CodingKeys: String, CodingKey {
        case isGenre
        case canExclude
        case usesTagStyle
        case options
        case ids
        case defaultIncluded
        case defaultExcluded
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isGenre = (try? container.decodeIfPresent(Bool.self, forKey: .isGenre)) ?? false
        self.canExclude = (try? container.decodeIfPresent(Bool.self, forKey: .canExclude)) ?? false
        self.usesTagStyle = (try? container.decodeIfPresent(Bool.self, forKey: .usesTagStyle)) ?? isGenre
        self.options = try container.decode([String].self, forKey: .options)
        self.ids = try container.decodeIfPresent([String].self, forKey: .ids)
        self.defaultIncluded = try container.decodeIfPresent([String].self, forKey: .defaultIncluded)
        self.defaultExcluded = try container.decodeIfPresent([String].self, forKey: .defaultExcluded)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(isGenre as Bool?, forKey: .isGenre)
        try container.encodeIfPresent(canExclude as Bool?, forKey: .canExclude)
        try container.encodeIfPresent(usesTagStyle as Bool?, forKey: .usesTagStyle)
        try container.encode(options, forKey: .options)
        try container.encodeIfPresent(ids, forKey: .ids)
        try container.encodeIfPresent(defaultIncluded, forKey: .defaultIncluded)
        try container.encodeIfPresent(defaultExcluded, forKey: .defaultExcluded)
    }
}

extension Filter: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case title
        case hideFromHeader
        case placeholder
        case canAscend
        case options
        case defaultValue = "default"
        case isGenre
        case canExclude
        case usesTagStyle
        case ids
        case text
        case name
        case min
        case max
        case decimal
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(String.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.hideFromHeader = try container.decodeIfPresent(Bool.self, forKey: .hideFromHeader)

        let type = try container.decode(String.self, forKey: .type)
        self.id = id ?? title ?? type

        switch type {
            case "text":
                let placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
                self.value = .text(placeholder: placeholder)
            case "sort":
                let canAscend = (try? container.decodeIfPresent(Bool.self, forKey: .canAscend)) ?? true
                let options = try container.decode([String].self, forKey: .options)
                let defaultValue = try container.decodeIfPresent(SortDefault.self, forKey: .defaultValue)
                self.value = .sort(canAscend: canAscend, options: options, defaultValue: defaultValue)
            case "check":
                let name = try container.decodeIfPresent(String.self, forKey: .name)
                let canExclude = (try? container.decodeIfPresent(Bool.self, forKey: .canExclude)) ?? false
                let defaultValue = try container.decodeIfPresent(Bool.self, forKey: .defaultValue)
                self.value = .check(name: name, canExclude: canExclude, defaultValue: defaultValue)
            case "select":
                self.value = .select(try SelectFilter(from: decoder))
            case "multi-select":
                self.value = .multiselect(try MultiSelectFilter(from: decoder))
            case "note":
                let text = try container.decode(String.self, forKey: .text)
                self.value = .note(text)
            case "range":
                let min = try container.decodeIfPresent(Float.self, forKey: .min)
                let max = try container.decodeIfPresent(Float.self, forKey: .max)
                let decimal = (try? container.decodeIfPresent(Bool.self, forKey: .decimal)) ?? false
                self.value = .range(min: min, max: max, decimal: decimal)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown filter type: \(type)"
                )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(hideFromHeader, forKey: .hideFromHeader)

        switch value {
            case .text(let placeholder):
                try container.encode("text", forKey: .type)
                try container.encodeIfPresent(placeholder, forKey: .placeholder)
            case .sort(let canAscend, let options, let defaultValue):
                try container.encode("sort", forKey: .type)
                try container.encodeIfPresent(canAscend as Bool?, forKey: .canAscend)
                try container.encode(options, forKey: .options)
                try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
            case .check(let name, let canExclude, let defaultValue):
                try container.encode("check", forKey: .type)
                try container.encodeIfPresent(name, forKey: .name)
                try container.encodeIfPresent(canExclude as Bool?, forKey: .canExclude)
                try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
            case .select(let filter):
                try container.encode("select", forKey: .type)
                try filter.encode(to: encoder)
            case .multiselect(let filter):
                try container.encode("multi-select", forKey: .type)
                try filter.encode(to: encoder)
            case .note(let note):
                try container.encode("note", forKey: .type)
                try container.encode(note, forKey: .text)
            case .range(let min, let max, let decimal):
                try container.encode("range", forKey: .type)
                try container.encodeIfPresent(min, forKey: .min)
                try container.encodeIfPresent(max, forKey: .max)
                try container.encodeIfPresent(decimal as Bool?, forKey: .decimal)
        }
    }
}
