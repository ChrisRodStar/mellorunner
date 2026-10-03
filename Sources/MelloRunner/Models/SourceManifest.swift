import Foundation

/// Content rating classification declared by a source extension.
public enum SourceContentRating: Int, Sendable, Codable, CaseIterable {
    case safe = 0
    case containsNsfw = 1
    case primarilyNsfw = 2
}

/// Language selection style supported by an extension.
public enum LanguageSelectType: String, Sendable, Codable {
    case single
    case multiple
}

/// Source-level configuration parameters declared in `source.json`.
public struct SourceConfiguration: Sendable, Codable, Hashable {
    public var languageSelectType: LanguageSelectType?
    public var supportsArtistSearch: Bool?
    public var supportsAuthorSearch: Bool?
    public var supportsTagSearch: Bool?
    public var allowsBaseUrlSelect: Bool?
    public var breakingChangeVersion: Int?
    public var hidesFiltersWhileSearching: Bool?
    public var maximumParallelRequests: Int?

    public init(
        languageSelectType: LanguageSelectType? = nil,
        supportsArtistSearch: Bool? = nil,
        supportsAuthorSearch: Bool? = nil,
        supportsTagSearch: Bool? = nil,
        allowsBaseUrlSelect: Bool? = nil,
        breakingChangeVersion: Int? = nil,
        hidesFiltersWhileSearching: Bool? = nil,
        maximumParallelRequests: Int? = nil
    ) {
        self.languageSelectType = languageSelectType
        self.supportsArtistSearch = supportsArtistSearch
        self.supportsAuthorSearch = supportsAuthorSearch
        self.supportsTagSearch = supportsTagSearch
        self.allowsBaseUrlSelect = allowsBaseUrlSelect
        self.breakingChangeVersion = breakingChangeVersion
        self.hidesFiltersWhileSearching = hidesFiltersWhileSearching
        self.maximumParallelRequests = maximumParallelRequests
    }
}

/// Metadata identifying a source extension declared in `source.json`.
public struct SourceInfo: Sendable, Codable, Hashable {
    public let id: String
    public let name: String
    public let altNames: [String]?
    public let version: Int
    public let url: String?
    public let urls: [String]?
    public let contentRating: SourceContentRating?
    public let languages: [String]
    public let minAppVersion: String?

    public init(
        id: String,
        name: String,
        altNames: [String]? = nil,
        version: Int,
        url: String? = nil,
        urls: [String]? = nil,
        contentRating: SourceContentRating? = .safe,
        languages: [String] = ["en"],
        minAppVersion: String? = nil
    ) {
        self.id = id
        self.name = name
        self.altNames = altNames
        self.version = version
        self.url = url
        self.urls = urls
        self.contentRating = contentRating
        self.languages = languages
        self.minAppVersion = minAppVersion
    }
}

/// Intermediate container supporting both string-based and dictionary-based listings in `source.json`.
public struct ManifestListing: Sendable, Codable, Hashable {
    public let listing: Listing

    public init(_ listing: Listing) {
        self.listing = listing
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let name = try? container.decode(String.self) {
            self.listing = Listing(id: name, name: name, kind: .default)
        } else {
            self.listing = try container.decode(Listing.self)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(listing)
    }
}

/// Parsed representation of an extension's `source.json` manifest.
public struct SourceManifest: Sendable, Codable {
    public let info: SourceInfo
    public let listings: [Listing]?
    public let config: SourceConfiguration?

    public init(
        info: SourceInfo,
        listings: [Listing]? = nil,
        config: SourceConfiguration? = nil
    ) {
        self.info = info
        self.listings = listings
        self.config = config
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.info = try container.decode(SourceInfo.self, forKey: .info)
        self.config = try container.decodeIfPresent(SourceConfiguration.self, forKey: .config)
        if let manifestListings = try? container.decodeIfPresent([ManifestListing].self, forKey: .listings) {
            self.listings = manifestListings.map(\.listing)
        } else {
            self.listings = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(info, forKey: .info)
        try container.encodeIfPresent(config, forKey: .config)
        let manifestListings = listings?.map { ManifestListing($0) }
        try container.encodeIfPresent(manifestListings, forKey: .listings)
    }

    /// Convenience decoder from raw JSON Data.
    public static func decode(from data: Data) throws -> SourceManifest {
        try JSONDecoder().decode(SourceManifest.self, from: data)
    }

    enum CodingKeys: String, CodingKey {
        case info
        case listings
        case config
    }
}
