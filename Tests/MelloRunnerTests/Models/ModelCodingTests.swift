import Foundation
import Testing
import WasmKit

@testable import MelloRunner

@Suite("Model Coding Tests")
struct ModelCodingTests {
    private let encoder = PostcardEncoder()
    private let decoder = PostcardDecoder()

    // MARK: - Manga Tests

    @Test("Manga round-trip serialization with all fields populated")
    func mangaFullRoundTrip() throws {
        let chapter = Chapter(
            key: "ch-1",
            title: "Chapter 1",
            chapterNumber: 1.0,
            volumeNumber: 1.0,
            dateUploaded: Date(timeIntervalSince1970: 1_700_000_000),
            scanlators: ["ScanGroup"],
            url: URL(string: "https://example.com/ch1"),
            language: "en",
            thumbnail: "https://example.com/ch1_thumb.jpg",
            locked: false
        )

        let manga = Manga(
            sourceKey: "test-source",
            key: "manga-42",
            title: "MelloRunner Adventure",
            cover: "https://example.com/cover.png",
            artists: ["Artist A", "Artist B"],
            authors: ["Author A"],
            description: "High performance manga reader runtime.",
            url: URL(string: "https://example.com/manga42"),
            tags: ["Action", "Sci-Fi", "Swift 6"],
            status: .ongoing,
            contentRating: .safe,
            viewer: .webtoon,
            updateStrategy: .always,
            nextUpdateTime: 1_750_000_000,
            chapters: [chapter]
        )

        let bytes = try encoder.encode(manga)
        let decoded = try decoder.decode(Manga.self, from: bytes)

        #expect(decoded.key == "manga-42")
        #expect(decoded.title == "MelloRunner Adventure")
        #expect(decoded.cover == "https://example.com/cover.png")
        #expect(decoded.artists == ["Artist A", "Artist B"])
        #expect(decoded.authors == ["Author A"])
        #expect(decoded.description == "High performance manga reader runtime.")
        #expect(decoded.url == URL(string: "https://example.com/manga42"))
        #expect(decoded.tags == ["Action", "Sci-Fi", "Swift 6"])
        #expect(decoded.status == .ongoing)
        #expect(decoded.contentRating == .safe)
        #expect(decoded.viewer == .webtoon)
        #expect(decoded.updateStrategy == .always)
        #expect(decoded.nextUpdateTime == 1_750_000_000)
        #expect(decoded.chapters?.count == 1)
        #expect(decoded.chapters?.first?.key == "ch-1")
        #expect(decoded.chapters?.first?.dateUploaded == Date(timeIntervalSince1970: 1_700_000_000))
        // Verify sourceKey is excluded from the wire
        #expect(decoded.sourceKey.isEmpty)
    }

    @Test("Manga round-trip with nil optional fields")
    func mangaMinimalRoundTrip() throws {
        let manga = Manga(
            key: "min-1",
            title: "Minimal Title"
        )

        let bytes = try encoder.encode(manga)
        let decoded = try decoder.decode(Manga.self, from: bytes)

        #expect(decoded.key == "min-1")
        #expect(decoded.title == "Minimal Title")
        #expect(decoded.cover == nil)
        #expect(decoded.artists == nil)
        #expect(decoded.authors == nil)
        #expect(decoded.description == nil)
        #expect(decoded.url == nil)
        #expect(decoded.tags == nil)
        #expect(decoded.status == .unknown)
        #expect(decoded.contentRating == .unknown)
        #expect(decoded.viewer == .unknown)
        #expect(decoded.updateStrategy == .always)
        #expect(decoded.nextUpdateTime == nil)
        #expect(decoded.chapters == nil)
    }

    @Test("All enum variants for Manga fields round-trip cleanly")
    func mangaEnumVariants() throws {
        for status in PublishingStatus.allCases {
            for rating in ContentRating.allCases {
                for viewer in Viewer.allCases {
                    for strategy in UpdateStrategy.allCases {
                        let manga = Manga(
                            key: "enum-test",
                            title: "Enums",
                            status: status,
                            contentRating: rating,
                            viewer: viewer,
                            updateStrategy: strategy
                        )
                        let bytes = try encoder.encode(manga)
                        let decoded = try decoder.decode(Manga.self, from: bytes)
                        #expect(decoded.status == status)
                        #expect(decoded.contentRating == rating)
                        #expect(decoded.viewer == viewer)
                        #expect(decoded.updateStrategy == strategy)
                    }
                }
            }
        }
    }

    // MARK: - Chapter Tests

    @Test("Chapter fractional numbers, date epoch, and URL serialization")
    func chapterRoundTrip() throws {
        let chapter = Chapter(
            key: "ch-10.5",
            title: "Extra Chapter",
            chapterNumber: 10.5,
            volumeNumber: 2.5,
            dateUploaded: Date(timeIntervalSince1970: 1_680_000_123),
            scanlators: ["SpeedyScans"],
            url: URL(string: "https://example.com/ch10.5"),
            language: "ja",
            thumbnail: "https://example.com/thumb.jpg",
            locked: true
        )

        let bytes = try encoder.encode(chapter)
        let decoded = try decoder.decode(Chapter.self, from: bytes)

        #expect(decoded.key == "ch-10.5")
        #expect(decoded.title == "Extra Chapter")
        #expect(decoded.chapterNumber == 10.5)
        #expect(decoded.volumeNumber == 2.5)
        #expect(decoded.dateUploaded == Date(timeIntervalSince1970: 1_680_000_123))
        #expect(decoded.scanlators == ["SpeedyScans"])
        #expect(decoded.url == URL(string: "https://example.com/ch10.5"))
        #expect(decoded.language == "ja")
        #expect(decoded.thumbnail == "https://example.com/thumb.jpg")
        #expect(decoded.locked == true)
        #expect(decoded.id == "ch-10.5")
    }

    // MARK: - Page Tests

    @Test("PageContent variants round-trip cleanly")
    func pageContentVariants() throws {
        // 1. URL with context headers
        let urlPage = Page(
            content: .url(
                url: URL(string: "https://images.example.com/page1.jpg")!,
                context: ["Referer": "https://example.com", "User-Agent": "MelloRunner"]
            ),
            thumbnail: URL(string: "https://images.example.com/page1_thumb.jpg"),
            hasDescription: true,
            description: "Color splash page"
        )
        let urlBytes = try encoder.encode(urlPage)
        let decodedUrlPage = try decoder.decode(Page.self, from: urlBytes)
        if case .url(let url, let context) = decodedUrlPage.content {
            #expect(url == URL(string: "https://images.example.com/page1.jpg"))
            #expect(context?["Referer"] == "https://example.com")
            #expect(context?["User-Agent"] == "MelloRunner")
        } else {
            Issue.record("Expected .url content variant")
        }
        #expect(decodedUrlPage.thumbnail == URL(string: "https://images.example.com/page1_thumb.jpg"))
        #expect(decodedUrlPage.hasDescription == true)
        #expect(decodedUrlPage.description == "Color splash page")

        // 2. Plain Text
        let textPage = Page(content: .text("Chapter 1: The Beginning\nOnce upon a time..."))
        let textBytes = try encoder.encode(textPage)
        let decodedTextPage = try decoder.decode(Page.self, from: textBytes)
        if case .text(let str) = decodedTextPage.content {
            #expect(str == "Chapter 1: The Beginning\nOnce upon a time...")
        } else {
            Issue.record("Expected .text content variant")
        }

        // 3. Image Descriptor handle
        let imagePage = Page(content: .imageDescriptor(77))
        let imageBytes = try encoder.encode(imagePage)
        let decodedImagePage = try decoder.decode(Page.self, from: imageBytes)
        if case .imageDescriptor(let desc) = decodedImagePage.content {
            #expect(desc == 77)
        } else {
            Issue.record("Expected .imageDescriptor content variant")
        }

        // 4. Zip File
        let zipPage = Page(content: .zipFile(url: URL(string: "file:///archive.zip")!, filePath: "images/001.png"))
        let zipBytes = try encoder.encode(zipPage)
        let decodedZipPage = try decoder.decode(Page.self, from: zipBytes)
        if case .zipFile(let url, let path) = decodedZipPage.content {
            #expect(url == URL(string: "file:///archive.zip"))
            #expect(path == "images/001.png")
        } else {
            Issue.record("Expected .zipFile content variant")
        }
    }

    // MARK: - Listing Tests

    @Test("Listing serialization and kind variants")
    func listingRoundTrip() throws {
        let popular = Listing(id: "popular", name: "Popular Manga", kind: .default)
        let bytes = try encoder.encode(popular)
        let decoded = try decoder.decode(Listing.self, from: bytes)
        #expect(decoded.id == "popular")
        #expect(decoded.name == "Popular Manga")
        #expect(decoded.kind == .default)

        let customList = Listing(id: "custom", name: "Custom List", kind: .list)
        let listBytes = try encoder.encode(customList)
        let decodedList = try decoder.decode(Listing.self, from: listBytes)
        #expect(decodedList.id == "custom")
        #expect(decodedList.name == "Custom List")
        #expect(decodedList.kind == .list)
    }

    // MARK: - MangaPageResult Tests

    @Test("MangaPageResult serialization and sourceKey propagation")
    func mangaPageResultRoundTrip() throws {
        var pageResult = MangaPageResult(
            entries: [
                Manga(key: "m1", title: "Manga One"),
                Manga(key: "m2", title: "Manga Two"),
            ],
            hasNextPage: true
        )

        pageResult.setSourceKey("mangadex")
        #expect(pageResult.entries[0].sourceKey == "mangadex")
        #expect(pageResult.entries[1].sourceKey == "mangadex")

        let bytes = try encoder.encode(pageResult)
        var decoded = try decoder.decode(MangaPageResult.self, from: bytes)

        #expect(decoded.entries.count == 2)
        #expect(decoded.entries[0].key == "m1")
        #expect(decoded.entries[1].key == "m2")
        #expect(decoded.hasNextPage == true)

        decoded.setSourceKey("source-2")
        #expect(decoded.entries[0].sourceKey == "source-2")
        #expect(decoded.entries[1].sourceKey == "source-2")
    }

    // MARK: - Filter Tests

    @Test("All Filter variants round-trip cleanly")
    func filterVariantsRoundTrip() throws {
        let filters: [Filter] = [
            Filter(id: "search_text", title: "Search", value: .text(placeholder: "Search title...")),
            Filter(
                id: "sort_order",
                title: "Sort",
                value: .sort(
                    canAscend: true,
                    options: ["Alphabetical", "Date", "Popularity"],
                    defaultValue: Filter.SortDefault(index: 2, ascending: false)
                )
            ),
            Filter(
                id: "completed_only", title: "Completed Only",
                value: .check(name: "Completed", canExclude: false, defaultValue: true)),
            Filter(
                id: "genre_select",
                title: "Genres",
                value: .select(
                    SelectFilter(isGenre: true, options: ["Action", "Comedy", "Drama"], defaultValue: "Action"))
            ),
            Filter(
                id: "tags_multi",
                title: "Tags",
                value: .multiselect(
                    MultiSelectFilter(
                        isGenre: false,
                        canExclude: true,
                        options: ["Shounen", "Seinen", "Isekai"],
                        defaultIncluded: ["Shounen"],
                        defaultExcluded: ["Isekai"]
                    )
                )
            ),
            Filter(id: "note_header", value: .note("Results updated every hour.")),
            Filter(id: "chapter_range", title: "Chapters", value: .range(min: 1.0, max: 500.0, decimal: false)),
        ]

        let bytes = try encoder.encode(filters)
        let decoded = try decoder.decode([Filter].self, from: bytes)

        #expect(decoded.count == 7)
        #expect(decoded[0].id == "search_text")
        if case .text(let placeholder) = decoded[0].value {
            #expect(placeholder == "Search title...")
        } else {
            Issue.record("Expected .text filter")
        }

        if case .sort(let canAscend, let options, let def) = decoded[1].value {
            #expect(canAscend == true)
            #expect(options == ["Alphabetical", "Date", "Popularity"])
            #expect(def?.index == 2)
            #expect(def?.ascending == false)
        } else {
            Issue.record("Expected .sort filter")
        }

        if case .check(let name, let canExclude, let def) = decoded[2].value {
            #expect(name == "Completed")
            #expect(canExclude == false)
            #expect(def == true)
        } else {
            Issue.record("Expected .check filter")
        }

        if case .select(let sel) = decoded[3].value {
            #expect(sel.isGenre == true)
            #expect(sel.options == ["Action", "Comedy", "Drama"])
            #expect(sel.defaultValue == "Action")
        } else {
            Issue.record("Expected .select filter")
        }

        if case .multiselect(let multi) = decoded[4].value {
            #expect(multi.canExclude == true)
            #expect(multi.options == ["Shounen", "Seinen", "Isekai"])
            #expect(multi.defaultIncluded == ["Shounen"])
            #expect(multi.defaultExcluded == ["Isekai"])
        } else {
            Issue.record("Expected .multiselect filter")
        }

        if case .note(let str) = decoded[5].value {
            #expect(str == "Results updated every hour.")
        } else {
            Issue.record("Expected .note filter")
        }

        if case .range(let min, let max, let decimal) = decoded[6].value {
            #expect(min == 1.0)
            #expect(max == 500.0)
            #expect(decimal == false)
        } else {
            Issue.record("Expected .range filter")
        }
    }

    // MARK: - FilterValue Tests

    @Test("All FilterValue variants round-trip cleanly")
    func filterValueVariantsRoundTrip() throws {
        let values: [FilterValue] = [
            .text(id: "query", value: "Solo Leveling"),
            .sort(SortFilterValue(id: "order", index: 1, ascending: true)),
            .check(id: "safe", value: 1),
            .select(id: "category", value: "Manga"),
            .multiselect(id: "tags", included: ["Action", "Fantasy"], excluded: ["Romance"]),
            .range(id: "chapters", from: 50.0, to: 200.0),
        ]

        let bytes = try encoder.encode(values)
        let decoded = try decoder.decode([FilterValue].self, from: bytes)

        #expect(decoded.count == 6)
        #expect(decoded[0] == .text(id: "query", value: "Solo Leveling"))
        #expect(decoded[1] == .sort(SortFilterValue(id: "order", index: 1, ascending: true)))
        #expect(decoded[2] == .check(id: "safe", value: 1))
        #expect(decoded[3] == .select(id: "category", value: "Manga"))
        #expect(decoded[4] == .multiselect(id: "tags", included: ["Action", "Fantasy"], excluded: ["Romance"]))
        #expect(decoded[5] == .range(id: "chapters", from: 50.0, to: 200.0))
    }

    // MARK: - Real Upstream Wasm Extension Integration

    @Test("Decode real listings and filters from upstream 96KB Rust Wasm binary")
    func upstreamBinaryModelDecoding() async throws {
        let fixtureUrl = try #require(
            Bundle.module.url(forResource: "payload", withExtension: "wasm", subdirectory: "Fixtures")
        )
        let wasmData = try Data(contentsOf: fixtureUrl)

        let bridge = try HostBridge(
            wasmBytes: wasmData,
            additionalImports: { store, imports in
                imports.define(
                    module: "defaults",
                    name: "get",
                    Function(
                        store: store,
                        type: FunctionType(parameters: [.i32, .i32], results: [.i32])
                    ) { _, _ in
                        [Value.i32(UInt32(bitPattern: -1))]
                    }
                )
            }
        )

        // Initialize Rust extension state
        _ = try await bridge.invoke("start")

        // 1. Listings
        let listings = try await bridge.invokeAndDecode([Listing].self, export: "get_listings")
        #expect(listings.count == 1)
        #expect(listings[0].id == "listing")
        #expect(listings[0].name == "Listing")
        #expect(listings[0].kind == .list)

        // 2. Filters
        let filters = try await bridge.invokeAndDecode([Filter].self, export: "get_filters")
        #expect(filters.count == 7)
        #expect(filters[0].id == "text")
        #expect(filters[0].title == "Text")
        #expect(filters[1].id == "sort")
        #expect(filters[1].title == "Sort")
        #expect(filters[2].id == "check")
        #expect(filters[2].title == "Check")
        #expect(filters[3].id == "select")
        #expect(filters[3].title == "Select")
        #expect(filters[4].id == "mselect")
        #expect(filters[4].title == "Multi-Select")
        #expect(filters[5].id == "note")
        #expect(filters[5].title == nil)
        #expect(filters[6].id == "range")
        #expect(filters[6].title == "Range")

        // 3. Settings
        let settings = try await bridge.invokeAndDecode([Setting].self, export: "get_settings")
        #expect(settings.count == 1)
        #expect(settings[0].key == "setting")
        #expect(settings[0].title == "Toggle")

        await bridge.close()
    }
}
