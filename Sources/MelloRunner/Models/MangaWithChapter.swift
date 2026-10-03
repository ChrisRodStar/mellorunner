import Foundation

/// Compound model pairing a manga entry with its associated chapter.
public struct MangaWithChapter: Sendable, Codable, Hashable {
    public var manga: Manga
    public var chapter: Chapter

    public init(manga: Manga, chapter: Chapter) {
        self.manga = manga
        self.chapter = chapter
    }
}
