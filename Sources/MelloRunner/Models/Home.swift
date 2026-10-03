import Foundation

/// Root model for an extension's dynamic home feed page.
public struct Home: Sendable, Codable, Hashable {
    public var components: [HomeComponent]

    public init(components: [HomeComponent] = []) {
        self.components = components
    }

    public mutating func setSourceKey(_ sourceKey: String) {
        for i in 0..<components.count {
            components[i].setSourceKey(sourceKey)
        }
    }
}

/// A section or modular card row on the home feed.
public struct HomeComponent: Sendable, Codable, Hashable {
    public var title: String?
    public var subtitle: String?
    public var value: Value

    public init(title: String? = nil, subtitle: String? = nil, value: Value) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
    }

    public mutating func setSourceKey(_ sourceKey: String) {
        value.setSourceKey(sourceKey)
    }

    public enum Value: Sendable, Hashable {
        case imageScroller(
            links: [HomeLink],
            autoScrollInterval: TimeInterval? = nil,
            width: Int? = nil,
            height: Int? = nil
        )
        case bigScroller(
            entries: [Manga],
            autoScrollInterval: TimeInterval? = nil
        )
        case scroller(
            entries: [HomeLink],
            listing: Listing? = nil
        )
        case mangaList(
            ranking: Bool = false,
            pageSize: Int? = nil,
            entries: [HomeLink],
            listing: Listing? = nil
        )
        case mangaChapterList(
            pageSize: Int? = nil,
            entries: [MangaWithChapter],
            listing: Listing? = nil
        )
        case filters([HomeFilterItem])
        case links([HomeLink])

        public var discriminant: UInt8 {
            switch self {
                case .imageScroller: 0
                case .bigScroller: 1
                case .scroller: 2
                case .mangaList: 3
                case .mangaChapterList: 4
                case .filters: 5
                case .links: 6
            }
        }

        public mutating func setSourceKey(_ sourceKey: String) {
            switch self {
                case .bigScroller(var entries, let interval):
                    for i in 0..<entries.count {
                        entries[i].sourceKey = sourceKey
                    }
                    self = .bigScroller(entries: entries, autoScrollInterval: interval)
                case .scroller(var entries, let listing):
                    for i in 0..<entries.count {
                        entries[i].setSourceKey(sourceKey)
                    }
                    self = .scroller(entries: entries, listing: listing)
                case .mangaList(let ranking, let pageSize, var entries, let listing):
                    for i in 0..<entries.count {
                        entries[i].setSourceKey(sourceKey)
                    }
                    self = .mangaList(ranking: ranking, pageSize: pageSize, entries: entries, listing: listing)
                case .mangaChapterList(let pageSize, var entries, let listing):
                    for i in 0..<entries.count {
                        entries[i].manga.sourceKey = sourceKey
                    }
                    self = .mangaChapterList(pageSize: pageSize, entries: entries, listing: listing)
                case .links(var links):
                    for i in 0..<links.count {
                        links[i].setSourceKey(sourceKey)
                    }
                    self = .links(links)
                default:
                    break
            }
        }
    }
}

extension HomeComponent.Value: Codable {
    private enum CodingKeys: CodingKey {
        case key
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(UInt8.self, forKey: .key)
        switch type {
            case 0:
                let links = try container.decode([HomeLink].self, forKey: .key)
                let autoScrollInterval =
                    try container
                    .decodeIfPresent(Float.self, forKey: .key)
                    .map(TimeInterval.init)
                let width = try container.decodeIfPresent(Int.self, forKey: .key)
                let height = try container.decodeIfPresent(Int.self, forKey: .key)
                self = .imageScroller(
                    links: links,
                    autoScrollInterval: autoScrollInterval,
                    width: width,
                    height: height
                )
            case 1:
                let entries = try container.decode([Manga].self, forKey: .key)
                let autoScrollInterval = try container.decodeIfPresent(
                    Float.self,
                    forKey: .key
                ).map(TimeInterval.init)
                self = .bigScroller(
                    entries: entries,
                    autoScrollInterval: autoScrollInterval
                )
            case 2:
                let entries = try container.decode([HomeLink].self, forKey: .key)
                let listing = try container.decodeIfPresent(Listing.self, forKey: .key)
                self = .scroller(entries: entries, listing: listing)
            case 3:
                let ranking = try container.decode(Bool.self, forKey: .key)
                let pageSize = try container.decodeIfPresent(Int.self, forKey: .key)
                let entries = try container.decode([HomeLink].self, forKey: .key)
                let listing = try container.decodeIfPresent(Listing.self, forKey: .key)
                self = .mangaList(ranking: ranking, pageSize: pageSize, entries: entries, listing: listing)
            case 4:
                let pageSize = try container.decodeIfPresent(Int.self, forKey: .key)
                let entries = try container.decode([MangaWithChapter].self, forKey: .key)
                let listing = try container.decodeIfPresent(Listing.self, forKey: .key)
                self = .mangaChapterList(pageSize: pageSize, entries: entries, listing: listing)
            case 5:
                let filters = try container.decode([HomeFilterItem].self, forKey: .key)
                self = .filters(filters)
            case 6:
                let links = try container.decode([HomeLink].self, forKey: .key)
                self = .links(links)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .key,
                    in: container,
                    debugDescription: "Invalid HomeComponent.Value discriminant: \(type)"
                )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(UInt8(discriminant), forKey: .key)
        switch self {
            case .imageScroller(let links, let autoScrollInterval, let width, let height):
                try container.encode(links, forKey: .key)
                try container.encodeIfPresent(autoScrollInterval.flatMap(Float.init), forKey: .key)
                try container.encodeIfPresent(width, forKey: .key)
                try container.encodeIfPresent(height, forKey: .key)
            case .bigScroller(let entries, let autoScrollInterval):
                try container.encode(entries, forKey: .key)
                try container.encodeIfPresent(autoScrollInterval.flatMap(Float.init), forKey: .key)
            case .scroller(let entries, let listing):
                try container.encode(entries, forKey: .key)
                try container.encodeIfPresent(listing, forKey: .key)
            case .mangaList(let ranking, let pageSize, let entries, let listing):
                try container.encode(ranking, forKey: .key)
                try container.encodeIfPresent(pageSize, forKey: .key)
                try container.encode(entries, forKey: .key)
                try container.encodeIfPresent(listing, forKey: .key)
            case .mangaChapterList(let pageSize, let entries, let listing):
                try container.encodeIfPresent(pageSize, forKey: .key)
                try container.encode(entries, forKey: .key)
                try container.encodeIfPresent(listing, forKey: .key)
            case .filters(let filters):
                try container.encode(filters, forKey: .key)
            case .links(let links):
                try container.encode(links, forKey: .key)
        }
    }
}

/// Filter entry group on a home component.
public struct HomeFilterItem: Sendable, Codable, Hashable {
    public var title: String
    public var values: [FilterValue]?

    public init(title: String, values: [FilterValue]? = nil) {
        self.title = title
        self.values = values
    }
}

/// Link navigation item on a home component.
public struct HomeLink: Sendable, Codable, Hashable {
    public var title: String
    public var subtitle: String?
    public var imageUrl: String?
    public var value: HomeLinkValue?

    public init(
        title: String,
        subtitle: String? = nil,
        imageUrl: String? = nil,
        value: HomeLinkValue? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageUrl = imageUrl
        self.value = value
    }

    public mutating func setSourceKey(_ sourceKey: String) {
        if case .manga(var manga) = value {
            manga.sourceKey = sourceKey
            self.value = .manga(manga)
        }
    }
}

/// Target destination for a HomeLink.
public enum HomeLinkValue: Sendable, Codable, Hashable {
    case url(String)
    case listing(Listing)
    case manga(Manga)

    private enum CodingKeys: CodingKey {
        case key
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(UInt8.self, forKey: .key)
        switch type {
            case 0:
                let value = try container.decode(String.self, forKey: .key)
                self = .url(value)
            case 1:
                let value = try container.decode(Listing.self, forKey: .key)
                self = .listing(value)
            case 2:
                let value = try container.decode(Manga.self, forKey: .key)
                self = .manga(value)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .key,
                    in: container,
                    debugDescription: "Unknown HomeLinkValue discriminant: \(type)"
                )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .url(let value):
                try container.encode(UInt8(0), forKey: .key)
                try container.encode(value, forKey: .key)
            case .listing(let value):
                try container.encode(UInt8(1), forKey: .key)
                try container.encode(value, forKey: .key)
            case .manga(let value):
                try container.encode(UInt8(2), forKey: .key)
                try container.encode(value, forKey: .key)
        }
    }
}

/// Partial result streamed from an extension during home feed evaluation.
public enum HomePartialResult: Sendable, Codable, Hashable {
    case layout(Home)
    case component(HomeComponent)

    private enum CodingKeys: CodingKey {
        case key
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(UInt8.self, forKey: .key)
        switch type {
            case 0:
                self = .layout(try container.decode(Home.self, forKey: .key))
            case 1:
                self = .component(try container.decode(HomeComponent.self, forKey: .key))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .key,
                    in: container,
                    debugDescription: "Unknown HomePartialResult discriminant: \(type)"
                )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .layout(let home):
                try container.encode(UInt8(0), forKey: .key)
                try container.encode(home, forKey: .key)
            case .component(let component):
                try container.encode(UInt8(1), forKey: .key)
                try container.encode(component, forKey: .key)
        }
    }
}
