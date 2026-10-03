import Foundation

/// Result produced by an extension handling a deep link or source-specific URL.
public struct DeepLinkResult: Sendable, Codable, Hashable {
    /// Manga key if the link points to a manga detail page.
    public var mangaKey: String?

    /// Chapter key if the link points directly to a chapter.
    public var chapterKey: String?

    /// Listing if the link points to an exploration category.
    public var listing: Listing?

    public init(
        mangaKey: String? = nil,
        chapterKey: String? = nil,
        listing: Listing? = nil
    ) {
        self.mangaKey = mangaKey
        self.chapterKey = chapterKey
        self.listing = listing
    }
}
