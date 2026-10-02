import Foundation

/// Paginated result of a manga listing or search query.
public struct MangaPageResult: Sendable, Hashable, Codable {
    /// List of manga entries returned for the current page.
    public var entries: [Manga]

    /// Whether additional pages are available.
    public var hasNextPage: Bool

    public init(entries: [Manga], hasNextPage: Bool) {
        self.entries = entries
        self.hasNextPage = hasNextPage
    }

    /// Assigns a source key to all manga entries within this page result.
    public mutating func setSourceKey(_ sourceKey: String) {
        for index in entries.indices {
            entries[index].sourceKey = sourceKey
        }
    }
}
