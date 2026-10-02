import Foundation

/// Publishing status of a manga.
public enum PublishingStatus: UInt8, Sendable, Codable, CaseIterable {
    case unknown = 0
    case ongoing = 1
    case completed = 2
    case cancelled = 3
    case hiatus = 4
}

/// Content rating of a manga.
public enum ContentRating: UInt8, Sendable, Codable, CaseIterable {
    case unknown = 0
    case safe = 1
    case suggestive = 2
    case nsfw = 3
}

/// Preferred viewer orientation or format for reading a manga.
public enum Viewer: UInt8, Sendable, Codable, CaseIterable {
    case unknown = 0
    case leftToRight = 1
    case rightToLeft = 2
    case vertical = 3
    case webtoon = 4
}

/// Strategy for updating manga details and chapters.
public enum UpdateStrategy: UInt8, Sendable, Codable, CaseIterable {
    case always = 0
    case never = 1
}

/// Represents a manga entry provided by a source extension.
public struct Manga: Sendable, Hashable, Identifiable {
    /// Unique identifier of the originating source extension. Not serialized over the extension wire.
    public var sourceKey: String

    /// Unique identifier for the manga within the source.
    public let key: String

    /// Title of the manga.
    public var title: String

    /// Cover image URL or path.
    public var cover: String?

    /// Optional list of contributing artists.
    public var artists: [String]?

    /// Optional list of authors/writers.
    public var authors: [String]?

    /// Synopsis or description of the manga.
    public var description: String?

    /// Canonical web URL for the manga on the source website.
    public var url: URL?

    /// Optional genres, categories, or tags.
    public var tags: [String]?

    /// Publishing status of the manga.
    public var status: PublishingStatus

    /// Content rating of the manga.
    public var contentRating: ContentRating

    /// Preferred reader orientation.
    public var viewer: Viewer

    /// Update strategy.
    public var updateStrategy: UpdateStrategy

    /// Optional epoch timestamp (in seconds) for scheduled updates.
    public var nextUpdateTime: Int?

    /// Optional list of chapters.
    public var chapters: [Chapter]?

    public var id: String { key }

    public init(
        sourceKey: String = "",
        key: String,
        title: String,
        cover: String? = nil,
        artists: [String]? = nil,
        authors: [String]? = nil,
        description: String? = nil,
        url: URL? = nil,
        tags: [String]? = nil,
        status: PublishingStatus = .unknown,
        contentRating: ContentRating = .unknown,
        viewer: Viewer = .unknown,
        updateStrategy: UpdateStrategy = .always,
        nextUpdateTime: Int? = nil,
        chapters: [Chapter]? = nil
    ) {
        self.sourceKey = sourceKey
        self.key = key
        self.title = title
        self.cover = cover
        self.artists = artists
        self.authors = authors
        self.description = description
        self.url = url
        self.tags = tags
        self.status = status
        self.contentRating = contentRating
        self.viewer = viewer
        self.updateStrategy = updateStrategy
        self.nextUpdateTime = nextUpdateTime
        self.chapters = chapters
    }
}

extension Manga: Codable {
    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case cover
        case artists
        case authors
        case description
        case url
        case tags
        case status
        case contentRating
        case viewer
        case updateStrategy
        case nextUpdateTime
        case chapters
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sourceKey = ""
        self.key = try container.decode(String.self, forKey: .key)
        self.title = try container.decode(String.self, forKey: .title)
        self.cover = try container.decodeIfPresent(String.self, forKey: .cover)
        self.artists = try container.decodeIfPresent([String].self, forKey: .artists)
        self.authors = try container.decodeIfPresent([String].self, forKey: .authors)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)

        let urlString = try container.decodeIfPresent(String.self, forKey: .url)
        self.url = urlString.flatMap { URL(string: $0) }

        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.status = (try? container.decode(PublishingStatus.self, forKey: .status)) ?? .unknown
        self.contentRating = (try? container.decode(ContentRating.self, forKey: .contentRating)) ?? .unknown
        self.viewer = (try? container.decode(Viewer.self, forKey: .viewer)) ?? .unknown
        self.updateStrategy = (try? container.decode(UpdateStrategy.self, forKey: .updateStrategy)) ?? .always
        self.nextUpdateTime = try container.decodeIfPresent(Int.self, forKey: .nextUpdateTime)
        self.chapters = try container.decodeIfPresent([Chapter].self, forKey: .chapters)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(artists, forKey: .artists)
        try container.encodeIfPresent(authors, forKey: .authors)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(url?.absoluteString, forKey: .url)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encode(status, forKey: .status)
        try container.encode(contentRating, forKey: .contentRating)
        try container.encode(viewer, forKey: .viewer)
        try container.encode(updateStrategy, forKey: .updateStrategy)
        try container.encodeIfPresent(nextUpdateTime, forKey: .nextUpdateTime)
        try container.encodeIfPresent(chapters, forKey: .chapters)
    }
}
