import Foundation

/// HTTP headers or query parameters associated with fetching a page image.
public typealias PageContext = [String: String]

/// The payload content of a chapter page.
public enum PageContent: Sendable, Hashable {
    /// Remote image URL with optional request context headers.
    case url(url: URL, context: PageContext? = nil)

    /// Raw plain text or HTML content (e.g. for light novels).
    case text(String)

    /// Resource store descriptor handle pointing to an in-memory image buffer.
    case imageDescriptor(Int32)

    /// Archive-backed page located within a ZIP file.
    case zipFile(url: URL, filePath: String)
}

extension PageContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case url
        case hasContext
        case contextCount
        case contextKey
        case contextValue
        case text
        case descriptor
        case filePath
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(UInt8.self)
        switch type {
            case 0:
                let urlString = try container.decode(String.self)
                guard let url = URL(string: urlString) else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Invalid page URL: \(urlString)"
                    )
                }
                let hasContext = try container.decode(UInt8.self) == 1
                var context: PageContext?
                if hasContext {
                    let count = try container.decode(UInt64.self)
                    var map = PageContext()
                    for _ in 0..<count {
                        let key = try container.decode(String.self)
                        let value = try container.decode(String.self)
                        map[key] = value
                    }
                    context = map
                }
                self = .url(url: url, context: context)
            case 1:
                self = .text(try container.decode(String.self))
            case 2:
                self = .imageDescriptor(try container.decode(Int32.self))
            case 3:
                let urlString = try container.decode(String.self)
                guard let url = URL(string: urlString) else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Invalid zip URL: \(urlString)"
                    )
                }
                let filePath = try container.decode(String.self)
                self = .zipFile(url: url, filePath: filePath)
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown PageContent discriminant: \(type)"
                )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
            case .url(let url, let context):
                try container.encode(UInt8(0))
                try container.encode(url.absoluteString)
                if let context {
                    try container.encode(UInt8(1))
                    try container.encode(UInt64(context.count))
                    // Sort keys for deterministic wire encoding
                    for key in context.keys.sorted() {
                        try container.encode(key)
                        try container.encode(context[key] ?? "")
                    }
                } else {
                    try container.encode(UInt8(0))
                }
            case .text(let string):
                try container.encode(UInt8(1))
                try container.encode(string)
            case .imageDescriptor(let desc):
                try container.encode(UInt8(2))
                try container.encode(desc)
            case .zipFile(let url, let filePath):
                try container.encode(UInt8(3))
                try container.encode(url.absoluteString)
                try container.encode(filePath)
        }
    }
}

/// Represents an individual page belonging to a chapter.
public struct Page: Sendable, Hashable {
    /// Content of the page (remote URL, text, in-memory image handle, or ZIP archive).
    public var content: PageContent

    /// Optional thumbnail image URL for the page.
    public var thumbnail: URL?

    /// Whether the page includes an extended text description.
    public var hasDescription: Bool

    /// Optional text description for the page.
    public var description: String?

    public init(
        content: PageContent,
        thumbnail: URL? = nil,
        hasDescription: Bool = false,
        description: String? = nil
    ) {
        self.content = content
        self.thumbnail = thumbnail
        self.hasDescription = hasDescription
        self.description = description
    }
}

extension Page: Codable {
    private enum CodingKeys: String, CodingKey {
        case content
        case thumbnail
        case hasDescription
        case description
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decode(PageContent.self, forKey: .content)

        let thumbnailString = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        self.thumbnail = thumbnailString.flatMap { URL(string: $0) }

        self.hasDescription = (try? container.decode(Bool.self, forKey: .hasDescription)) ?? false
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(thumbnail?.absoluteString, forKey: .thumbnail)
        try container.encode(hasDescription, forKey: .hasDescription)
        try container.encodeIfPresent(description, forKey: .description)
    }
}
