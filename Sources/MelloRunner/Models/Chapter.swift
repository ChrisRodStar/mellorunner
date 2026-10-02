import Foundation

/// Represents a single chapter belonging to a manga.
public struct Chapter: Sendable, Hashable, Identifiable {
    /// Unique identifier for the chapter within the source.
    public var key: String

    /// Optional title or subtitle of the chapter (excluding volume/chapter numbers).
    public var title: String?

    /// Chapter number, supporting fractional/decimal chapters (e.g. 10.5).
    public var chapterNumber: Float?

    /// Volume number, supporting fractional/decimal volumes.
    public var volumeNumber: Float?

    /// Upload date and time of the chapter.
    public var dateUploaded: Date?

    /// List of scanlation groups or translators that produced the chapter release.
    public var scanlators: [String]?

    /// Canonical web URL for the chapter on the source website.
    public var url: URL?

    /// BCP-47 language tag or string indicating the chapter's language.
    public var language: String?

    /// Optional thumbnail image URL for the chapter.
    public var thumbnail: String?

    /// Whether the chapter is behind a paywall, account requirement, or lock.
    public var locked: Bool

    public var id: String { key }

    public init(
        key: String,
        title: String? = nil,
        chapterNumber: Float? = nil,
        volumeNumber: Float? = nil,
        dateUploaded: Date? = nil,
        scanlators: [String]? = nil,
        url: URL? = nil,
        language: String? = nil,
        thumbnail: String? = nil,
        locked: Bool = false
    ) {
        self.key = key
        self.title = title
        self.chapterNumber = chapterNumber
        self.volumeNumber = volumeNumber
        self.dateUploaded = dateUploaded
        self.scanlators = scanlators
        self.url = url
        self.language = language
        self.thumbnail = thumbnail
        self.locked = locked
    }
}

extension Chapter: Codable {
    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case chapterNumber
        case volumeNumber
        case dateUploaded
        case scanlators
        case url
        case language
        case thumbnail
        case locked
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decode(String.self, forKey: .key)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.chapterNumber = try container.decodeIfPresent(Float.self, forKey: .chapterNumber)
        self.volumeNumber = try container.decodeIfPresent(Float.self, forKey: .volumeNumber)

        if let epochSeconds = try container.decodeIfPresent(Int64.self, forKey: .dateUploaded) {
            self.dateUploaded = Date(timeIntervalSince1970: TimeInterval(epochSeconds))
        } else {
            self.dateUploaded = nil
        }

        self.scanlators = try container.decodeIfPresent([String].self, forKey: .scanlators)

        let urlString = try container.decodeIfPresent(String.self, forKey: .url)
        self.url = urlString.flatMap { URL(string: $0) }

        self.language = try container.decodeIfPresent(String.self, forKey: .language)
        self.thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        self.locked = (try? container.decode(Bool.self, forKey: .locked)) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(chapterNumber, forKey: .chapterNumber)
        try container.encodeIfPresent(volumeNumber, forKey: .volumeNumber)

        let epochSeconds = dateUploaded.map { Int64($0.timeIntervalSince1970) }
        try container.encodeIfPresent(epochSeconds, forKey: .dateUploaded)

        try container.encodeIfPresent(scanlators, forKey: .scanlators)
        try container.encodeIfPresent(url?.absoluteString, forKey: .url)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
        try container.encode(locked, forKey: .locked)
    }
}
