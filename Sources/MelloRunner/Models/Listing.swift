import Foundation

/// Type of manga listing provided by a source extension.
public enum ListingKind: UInt8, Sendable, Codable, CaseIterable {
    case `default` = 0
    case list = 1
}

/// Represents an exploration category or listing (e.g. Popular, Latest, Top Rated).
public struct Listing: Sendable, Hashable, Identifiable {
    /// Unique identifier for the listing.
    public var id: String

    /// User-facing display title of the listing.
    public var name: String

    /// Category or display style of the listing.
    public var kind: ListingKind

    public init(id: String, name: String, kind: ListingKind = .default) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

extension Listing: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? id
        self.kind = (try? container.decode(ListingKind.self, forKey: .kind)) ?? .default
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
    }
}
