import Foundation
import Testing
import os

@testable import MelloRunner

@Suite("SourceSession High-Level API Tests")
struct SourceSessionTests {
    private func resolvePath(_ relativePath: String) -> URL {
        let candidates = [
            relativePath,
            "../" + relativePath,
            "../../" + relativePath,
        ]
        let found = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[0]
        return URL(fileURLWithPath: found)
    }

    @Test("Instantiate SourceSession from real .aix archive (Asura Scans)")
    func instantiateSessionFromAIX() async throws {
        let aixURL = resolvePath("Reference/en.asurascans-v19.aix")
        guard FileManager.default.fileExists(atPath: aixURL.path) else { return }

        let session = try await SourceSession(url: aixURL)

        // Metadata
        #expect(session.name == "Asura Scans")
        #expect(session.key == "en.asurascans")
        #expect(session.version == 19)
        #expect(session.languages == ["en"])
        #expect(session.contentRating == .safe)
        #expect(session.urls.count >= 1)

        // Capabilities
        #expect(session.features.dynamicListings == true)
        #expect(session.hasListings == true)
        #expect(session.onlySearch == false)

        // Static components
        #expect(session.staticListings.count == 1)
        #expect(session.staticListings.first?.id == "Ranking")
        #expect(session.staticFilters.count >= 4)
        #expect(session.staticSettings.count >= 2)

        // Tag search support
        #expect(session.supportsTagSearch == true)

        // Query listings (merges static "Ranking" with dynamic guest listings)
        let listings = try await session.getListings()
        #expect(listings.contains { $0.id == "Ranking" })

        // Query settings
        let settings = try await session.getSettings()
        #expect(settings.count >= 2)

        // Query filters
        let filters = try await session.getSearchFilters()
        #expect(filters.count >= 4)

        // Clean teardown
        await session.close()
    }

    @Test("Instantiate SourceSession from upstream 96KB Rust payload.wasm")
    func instantiateSessionFromUpstreamPayload() async throws {
        let wasmURL = resolvePath("Reference/AidokuRunner/Tests/AidokuRunnerTests/Resources/Payload/main.wasm")
        guard FileManager.default.fileExists(atPath: wasmURL.path) else { return }

        let wasmBytes = try Data(contentsOf: wasmURL)
        let manifest = SourceManifest(
            info: SourceInfo(
                id: "test.upstream",
                name: "Upstream Test",
                version: 1,
                url: "https://example.com",
                contentRating: .safe,
                languages: ["en"]
            )
        )
        let package = SourcePackage(manifest: manifest, wasmBytes: wasmBytes)

        let session = try await SourceSession(package: package)

        // Feature discovery
        #expect(session.features.dynamicSettings == true)
        #expect(session.features.dynamicFilters == true)
        #expect(session.features.dynamicListings == true)

        // Query dynamic settings
        let settings = try await session.getSettings()
        #expect(!settings.isEmpty)

        // Query dynamic filters
        let filters = try await session.getSearchFilters()
        #expect(!filters.isEmpty)

        // Query dynamic listings
        let listings = try await session.getListings()
        #expect(!listings.isEmpty)

        await session.close()
    }

    @Test("Verify search capability flags on synthetic manifest")
    func verifySearchCapabilityFlags() async throws {
        let manifest = SourceManifest(
            info: SourceInfo(
                id: "test.search",
                name: "Search Flags",
                version: 1,
                languages: ["en"]
            ),
            config: SourceConfiguration(
                supportsArtistSearch: true,
                supportsAuthorSearch: false,
                supportsTagSearch: true
            )
        )

        let answerWasm = Data([
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x0a, 0x01, 0x06, 0x61, 0x6e, 0x73, 0x77, 0x65, 0x72, 0x00, 0x00,
            0x0a, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2a, 0x0b,
        ])

        let package = SourcePackage(manifest: manifest, wasmBytes: answerWasm)
        let session = try await SourceSession(package: package)

        #expect(session.supportsArtistSearch == true)
        #expect(session.supportsAuthorSearch == false)
        #expect(session.supportsTagSearch == true)
        #expect(session.hasListings == false)
        #expect(session.onlySearch == true)

        await session.close()
    }

    @Test("Extra settings synthesis and settings defaults registration")
    func extraSettingsSynthesis() async throws {
        let manifest = SourceManifest(
            info: SourceInfo(
                id: "test.settings.source",
                name: "Settings Test",
                version: 1,
                urls: ["https://source1.com", "https://source2.com"],
                languages: ["en", "es", "fr"]
            ),
            config: SourceConfiguration(
                languageSelectType: .multiple,
                allowsBaseUrlSelect: true
            )
        )

        let answerWasm = Data([
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x0a, 0x01, 0x06, 0x61, 0x6e, 0x73, 0x77, 0x65, 0x72, 0x00, 0x00,
            0x0a, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2a, 0x0b,
        ])

        let settingsStore = InMemorySettingsStore()
        var config = SourceSessionConfiguration()
        config.settingsStore = settingsStore

        let package = SourcePackage(manifest: manifest, wasmBytes: answerWasm)
        let session = try await SourceSession(package: package, configuration: config)

        let settings = try await session.getSettings()
        #expect(settings.contains { $0.title == "LANGUAGES" })
        #expect(settings.contains { $0.title == "BASE_URL" })

        // Check inner group items
        let flatSettings = settings.flatMap { setting -> [Setting] in
            if case .group(let group) = setting.value {
                return group.items
            }
            return [setting]
        }
        #expect(flatSettings.contains { $0.key == "languages" })
        #expect(flatSettings.contains { $0.key == "url" })

        // Check default registration in settings store
        let baseUrlDefault = settingsStore.string(forKey: "test.settings.source.url")
        #expect(baseUrlDefault == "https://source1.com")

        // Equatable and Identifiable
        #expect(session.id == "test.settings.source")
        #expect(session == session)

        await session.clearCache()
        await session.close()
    }

    @Test("Matching genre filter resolution")
    func matchingGenreFilterResolution() async throws {
        // Tag search enabled case
        let manifestTag = SourceManifest(
            info: SourceInfo(id: "tag.source", name: "Tag Source", version: 1, languages: ["en"]),
            config: SourceConfiguration(supportsTagSearch: true)
        )
        let dummyWasm = Data([
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x0a, 0x01, 0x06, 0x61, 0x6e, 0x73, 0x77, 0x65, 0x72, 0x00, 0x00,
            0x0a, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2a, 0x0b,
        ])
        let sessionTag = try await SourceSession(package: SourcePackage(manifest: manifestTag, wasmBytes: dummyWasm))
        let tagFilter = sessionTag.matchingGenreFilter(for: "Action")
        #expect(tagFilter == .select(id: "genre", value: "Action"))
        await sessionTag.close()

        // Static multiselect genre filter case
        let multiselectGenre = MultiSelectFilter(
            isGenre: true,
            options: ["Action", "Comedy", "Drama"],
            ids: ["act", "com", "drm"]
        )
        let filter = Filter(id: "genres", title: "Genres", value: .multiselect(multiselectGenre))
        let manifestFilter = SourceManifest(
            info: SourceInfo(id: "filter.source", name: "Filter Source", version: 1, languages: ["en"]),
            config: SourceConfiguration(supportsTagSearch: false)
        )
        let sessionFilter = try await SourceSession(
            package: SourcePackage(manifest: manifestFilter, wasmBytes: dummyWasm))
        let matched = sessionFilter.matchingGenreFilter(for: "Comedy", filters: [filter])
        #expect(matched == .multiselect(id: "genres", included: ["com"], excluded: []))

        // Select genre filter case
        let selectGenre = SelectFilter(
            isGenre: true,
            options: ["Action", "Comedy"],
            ids: ["act", "com"]
        )
        let selectFilter = Filter(id: "genre_select", title: "Genre", value: .select(selectGenre))
        let matchedSelect = sessionFilter.matchingGenreFilter(for: "Action", filters: [selectFilter])
        #expect(matchedSelect == .select(id: "genre_select", value: "act"))

        // Unmatched tag
        let unmatched = sessionFilter.matchingGenreFilter(for: "Horror", filters: [filter, selectFilter])
        #expect(unmatched == nil)

        await sessionFilter.close()
    }

    @Test("Streaming partial manga updates callback delivery")
    func streamingPartialMangaUpdates() async throws {
        let receivedManga = OSAllocatedUnfairLock<[Manga]>(initialState: [])
        var config = SourceSessionConfiguration()
        config.partialMangaHandler = { manga in
            receivedManga.withLock { $0.append(manga) }
        }

        let manifest = SourceManifest(
            info: SourceInfo(id: "test.partial.manga", name: "Partial Source", version: 1, languages: ["en"])
        )
        let dummyWasm = Data([
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x0a, 0x01, 0x06, 0x61, 0x6e, 0x73, 0x77, 0x65, 0x72, 0x00, 0x00,
            0x0a, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2a, 0x0b,
        ])

        let session = try await SourceSession(
            package: SourcePackage(manifest: manifest, wasmBytes: dummyWasm), configuration: config)

        // Simulate sending a Manga partial result through configuration handler
        let sampleManga = Manga(key: "manga-1", title: "Solo Leveling")
        let encodedData = try PostcardEncoder().encode(sampleManga)

        // Trigger partial handler via bridge's standardImports callback
        let partialHandler = session.bridge.standardImports.partialResultHandler
        partialHandler?(encodedData)

        let results = receivedManga.withLock { $0 }
        #expect(results.count >= 1)
        #expect(results.first?.title == "Solo Leveling")
        #expect(results.first?.sourceKey == "test.partial.manga")

        await session.close()
    }
}
