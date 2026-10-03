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
    private enum CodingKeys: String, CodingKey {
        case type
        case links
        case entries
        case autoScrollInterval
        case width
        case height
        case listing
        case ranking
        case pageSize
        case filters
    }

    public init(from decoder: any Decoder) throws {
        let unkeyed = try? decoder.unkeyedContainer()
        if var unkeyed {
            let disc = try unkeyed.decode(UInt8.self)
            switch disc {
                case 0:
                    let links = try unkeyed.decode([HomeLink].self)
                    let autoScroll = try unkeyed.decodeIfPresent(Float.self).flatMap { TimeInterval($0) }
                    let width = try unkeyed.decodeIfPresent(Int.self)
                    let height = try unkeyed.decodeIfPresent(Int.self)
                    self = .imageScroller(links: links, autoScrollInterval: autoScroll, width: width, height: height)
                case 1:
                    let entries = try unkeyed.decode([Manga].self)
                    let autoScroll = try unkeyed.decodeIfPresent(Float.self).flatMap { TimeInterval($0) }
                    self = .bigScroller(entries: entries, autoScrollInterval: autoScroll)
                case 2:
                    let entries = try unkeyed.decode([HomeLink].self)
                    let listing = try unkeyed.decodeIfPresent(Listing.self)
                    self = .scroller(entries: entries, listing: listing)
                case 3:
                    let ranking = try unkeyed.decode(Bool.self)
                    let pageSize = try unkeyed.decodeIfPresent(Int.self)
                    let entries = try unkeyed.decode([HomeLink].self)
                    let listing = try unkeyed.decodeIfPresent(Listing.self)
                    self = .mangaList(ranking: ranking, pageSize: pageSize, entries: entries, listing: listing)
                case 4:
                    let pageSize = try unkeyed.decodeIfPresent(Int.self)
                    let entries = try unkeyed.decode([MangaWithChapter].self)
                    let listing = try unkeyed.decodeIfPresent(Listing.self)
                    self = .mangaChapterList(pageSize: pageSize, entries: entries, listing: listing)
                case 5:
                    let filters = try unkeyed.decode([HomeFilterItem].self)
                    self = .filters(filters)
                case 6:
                    let links = try unkeyed.decode([HomeLink].self)
                    self = .links(links)
                default:
                    throw DecodingError.dataCorruptedError(
                        in: unkeyed,
                        debugDescription: "Unknown HomeComponent.Value discriminant: \(disc)"
                    )
            }
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
            case "imageScroller":
                let links = try container.decode([HomeLink].self, forKey: .links)
                let autoScroll = try container.decodeIfPresent(TimeInterval.self, forKey: .autoScrollInterval)
                let width = try container.decodeIfPresent(Int.self, forKey: .width)
                let height = try container.decodeIfPresent(Int.self, forKey: .height)
                self = .imageScroller(links: links, autoScrollInterval: autoScroll, width: width, height: height)
            case "bigScroller":
                let entries = try container.decode([Manga].self, forKey: .entries)
                let autoScroll = try container.decodeIfPresent(TimeInterval.self, forKey: .autoScrollInterval)
                self = .bigScroller(entries: entries, autoScrollInterval: autoScroll)
            case "scroller":
                let entries = try container.decode([HomeLink].self, forKey: .entries)
                let listing = try container.decodeIfPresent(Listing.self, forKey: .listing)
                self = .scroller(entries: entries, listing: listing)
            case "mangaList":
                let ranking = (try? container.decode(Bool.self, forKey: .ranking)) ?? false
                let pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize)
                let entries = try container.decode([HomeLink].self, forKey: .entries)
                let listing = try container.decodeIfPresent(Listing.self, forKey: .listing)
                self = .mangaList(ranking: ranking, pageSize: pageSize, entries: entries, listing: listing)
            case "mangaChapterList":
                let pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize)
                let entries = try container.decode([MangaWithChapter].self, forKey: .entries)
                let listing = try container.decodeIfPresent(Listing.self, forKey: .listing)
                self = .mangaChapterList(pageSize: pageSize, entries: entries, listing: listing)
            case "filters":
                let filters = try container.decode([HomeFilterItem].self, forKey: .filters)
                self = .filters(filters)
            case "links":
                let links = try container.decode([HomeLink].self, forKey: .links)
                self = .links(links)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown HomeComponent type: \(type)"
                )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var unkeyed = encoder.unkeyedContainer()
        try unkeyed.encode(discriminant)
        switch self {
            case .imageScroller(let links, let autoScroll, let width, let height):
                try unkeyed.encode(links)
                try unkeyed.encode(autoScroll.flatMap(Float.init))
                try unkeyed.encode(width)
                try unkeyed.encode(height)
            case .bigScroller(let entries, let autoScroll):
                try unkeyed.encode(entries)
                try unkeyed.encode(autoScroll.flatMap(Float.init))
            case .scroller(let entries, let listing):
                try unkeyed.encode(entries)
                try unkeyed.encode(listing)
            case .mangaList(let ranking, let pageSize, let entries, let listing):
                try unkeyed.encode(ranking)
                try unkeyed.encode(pageSize)
                try unkeyed.encode(entries)
                try unkeyed.encode(listing)
            case .mangaChapterList(let pageSize, let entries, let listing):
                try unkeyed.encode(pageSize)
                try unkeyed.encode(entries)
                try unkeyed.encode(listing)
            case .filters(let filters):
                try unkeyed.encode(filters)
            case .links(let links):
                try unkeyed.encode(links)
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

    public init(from decoder: any Decoder) throws {
        let unkeyed = try? decoder.unkeyedContainer()
        if var unkeyed {
            let disc = try unkeyed.decode(UInt8.self)
            switch disc {
                case 0: self = .url(try unkeyed.decode(String.self))
                case 1: self = .listing(try unkeyed.decode(Listing.self))
                case 2: self = .manga(try unkeyed.decode(Manga.self))
                default:
                    throw DecodingError.dataCorruptedError(
                        in: unkeyed,
                        debugDescription: "Unknown HomeLinkValue discriminant: \(disc)"
                    )
            }
            return
        }

        let container = try decoder.singleValueContainer()
        if let manga = try? container.decode(Manga.self) {
            self = .manga(manga)
        } else if let listing = try? container.decode(Listing.self) {
            self = .listing(listing)
        } else if let url = try? container.decode(String.self) {
            self = .url(url)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode HomeLinkValue"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var unkeyed = encoder.unkeyedContainer()
        switch self {
            case .url(let url):
                try unkeyed.encode(UInt8(0))
                try unkeyed.encode(url)
            case .listing(let listing):
                try unkeyed.encode(UInt8(1))
                try unkeyed.encode(listing)
            case .manga(let manga):
                try unkeyed.encode(UInt8(2))
                try unkeyed.encode(manga)
        }
    }
}
