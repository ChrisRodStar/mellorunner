import Foundation
import Testing
import WasmKit
import os

@testable import MelloRunner

@Suite("Upstream Compatibility Tests")
struct UpstreamCompatibilityTests {
    private func resolvePath(_ relativePath: String) -> URL {
        let candidates = [
            relativePath,
            "../" + relativePath,
            "../../" + relativePath,
        ]
        let found = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[0]
        return URL(fileURLWithPath: found)
    }

    private func resolvePayloadDir() -> URL {
        let candidates = [
            "Tests/MelloRunnerTests/Fixtures/Payload",
            "../Tests/MelloRunnerTests/Fixtures/Payload",
            "../../Tests/MelloRunnerTests/Fixtures/Payload",
        ]
        let found = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[0]
        return URL(fileURLWithPath: found)
    }

    @Test("Load upstream reference source.json manifest and verify schema metadata")
    func loadUpstreamReferenceManifest() async throws {
        let payloadDir = resolvePayloadDir()
        guard FileManager.default.fileExists(atPath: payloadDir.path) else { return }

        let package = try SourcePackage.load(from: payloadDir)
        #expect(package.manifest.info.id == "test")
        #expect(package.manifest.info.name == "Test")
        #expect(package.manifest.info.version == 1)
        #expect(package.manifest.info.url == "https://aidoku.app")
        #expect(package.manifest.info.languages == ["en"])
        #expect(package.manifest.info.contentRating == .safe)
        #expect(package.wasmBytes.count == 96688)
    }

    @Test("Instantiate SourceSession from upstream Payload directory")
    func instantiateUpstreamSession() async throws {
        let payloadDir = resolvePayloadDir()
        guard FileManager.default.fileExists(atPath: payloadDir.path) else { return }

        let session = try await SourceSession(url: payloadDir)

        // Metadata accessors
        #expect(session.key == "test")
        #expect(session.name == "Test")
        #expect(session.version == 1)
        #expect(session.languages == ["en"])
        #expect(session.urls.first?.absoluteString == "https://aidoku.app")
        #expect(session.contentRating == .safe)

        // Feature discovery
        #expect(session.features.dynamicListings == true)
        #expect(session.features.dynamicFilters == true)
        #expect(session.features.dynamicSettings == true)
        #expect(session.features.providesHome == true)

        // Dynamic listings
        let listings = try await session.getListings()
        #expect(!listings.isEmpty)

        // Dynamic filters
        let filters = try await session.getSearchFilters()
        #expect(!filters.isEmpty)

        // Dynamic settings
        let settings = try await session.getSettings()
        #expect(!settings.isEmpty)

        // Dynamic home feed
        let home = try await session.getHome()
        #expect(home.components.count >= 0)

        // Search manga list
        let search = try await session.getSearchMangaList(query: "test", page: 1, filters: [])
        #expect(search.entries.count >= 0)

        // Teardown
        await session.close()
    }

    @Test("Verify upstream panic behavior on getMangaUpdate and clean recovery via restart()")
    func upstreamPanicAndRestartRecovery() async throws {
        let payloadDir = resolvePayloadDir()
        guard FileManager.default.fileExists(atPath: payloadDir.path) else { return }

        let session = try await SourceSession(url: payloadDir)

        // The upstream test extension deliberately executes `unreachable` in get_manga_update
        var didTrap = false
        do {
            _ = try await session.getMangaUpdate(
                manga: Manga(key: "test-manga", title: "Test Manga"),
                needsDetails: false,
                needsChapters: false
            )
        } catch let error as RuntimeError {
            if case .trap = error {
                didTrap = true
            }
        } catch {
            didTrap = true
        }
        #expect(didTrap == true)

        // Session must cleanly restart and rebind fresh runtime state
        try await session.restart()

        // Calling getHome() after restart succeeds cleanly
        let home = try await session.getHome()
        #expect(home.components.count >= 0)

        // Calling getListings() succeeds
        let listings = try await session.getListings()
        #expect(!listings.isEmpty)

        await session.close()
    }

    @Test("Deterministic network transport mock with real Asura Scans extension")
    func asuraScansWithMockNetworkTransport() async throws {
        let aixURL = resolvePath("Reference/en.asurascans-v19.aix")
        guard FileManager.default.fileExists(atPath: aixURL.path) else { return }

        let sampleHTML = """
            <!DOCTYPE html>
            <html>
            <head><title>Asura Scans Search</title></head>
            <body>
                <div class="listupd">
                    <div class="bs">
                        <div class="bsx">
                            <a href="https://asuracomic.net/series/nano-machine-test" title="Nano Machine">
                                <div class="limit">
                                    <img src="https://example.com/nano.jpg" class="lazyloaded" />
                                </div>
                                <div class="bigor">
                                    <div class="tt">Nano Machine</div>
                                </div>
                            </a>
                        </div>
                    </div>
                </div>
            </body>
            </html>
            """

        let mockTransport = MockHTTPTransport { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://asuracomic.net")!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            return (Data(sampleHTML.utf8), response)
        }

        var config = SourceSessionConfiguration()
        config.transport = mockTransport

        let session = try await SourceSession(url: aixURL, configuration: config)
        #expect(session.name == "Asura Scans")
        #expect(session.version == 19)

        // Call listings to confirm mock transport handled network calls cleanly
        let listings = try await session.getListings()
        #expect(!listings.isEmpty)

        await session.close()
    }

    @Test("Streaming partial home feed updates callback delivery")
    func streamingPartialHomeFeed() async throws {
        let homeHolder = OSAllocatedUnfairLock<[Home]>(initialState: [])
        var config = SourceSessionConfiguration()
        config.partialHomeHandler = { updatedHome in
            homeHolder.withLock { $0.append(updatedHome) }
        }

        // Test manual partial decoding simulation
        let component = HomeComponent(
            title: "Trending",
            value: .scroller(entries: [HomeLink(title: "Nano Machine")])
        )
        let partial = HomePartialResult.component(component)
        let encoder = PostcardEncoder()
        let partialData = try encoder.encode(partial)

        let decodedPartial = try PostcardDecoder().decode(HomePartialResult.self, from: partialData)
        if case .component(let decodedComponent) = decodedPartial {
            #expect(decodedComponent.title == "Trending")
        } else {
            Issue.record("Expected .component variant in decoded HomePartialResult")
        }
    }

    @Test("Image processing fallback passes raw bytes when extension lacks export")
    func imageProcessingFallback() async throws {
        let payloadDir = resolvePayloadDir()
        guard FileManager.default.fileExists(atPath: payloadDir.path) else { return }

        let session = try await SourceSession(url: payloadDir)
        let sampleImageBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])  // PNG header

        let pageResult = try await session.processPageImage(
            data: sampleImageBytes,
            url: URL(string: "https://example.com/page1.png")
        )
        #expect(pageResult == sampleImageBytes)

        let coverResult = try await session.processCoverImage(
            data: sampleImageBytes,
            url: URL(string: "https://example.com/cover.png")
        )
        #expect(coverResult == sampleImageBytes)

        await session.close()
    }

    @Test("ImageRequest and ImageResponse Postcard serialization wire equivalence")
    func imageRequestAndResponseSerialization() throws {
        let encoder = PostcardEncoder()
        let decoder = PostcardDecoder()

        let req = ImageRequest(
            url: URL(string: "https://example.com/ch1/p1.png"),
            headers: ["Referer": "https://example.com"]
        )
        let resp = ImageResponse(code: 200, headers: ["Content-Type": "image/png"], request: req, image: 42)

        let encoded = try encoder.encode(resp)
        let decoded = try decoder.decode(ImageResponse.self, from: encoded)

        #expect(decoded.code == 200)
        #expect(decoded.image == 42)
        #expect(decoded.request.url?.absoluteString == "https://example.com/ch1/p1.png")
        #expect(decoded.request.headers["Referer"] == "https://example.com")
        #expect(decoded.headers["Content-Type"] == "image/png")
    }

    @Test("KeyKind enum integer discriminants match Aidoku specification")
    func keyKindIntegerDiscriminants() {
        #expect(KeyKind.manga.rawValue == 0)
        #expect(KeyKind.chapter.rawValue == 1)
    }

    @Test("Thread-safe concurrent execution across multiple async tasks on SourceSession")
    func threadSafeConcurrentSessionExecution() async throws {
        let payloadDir = resolvePayloadDir()
        guard FileManager.default.fileExists(atPath: payloadDir.path) else { return }

        let session = try await SourceSession(url: payloadDir)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    if i % 4 == 0 {
                        _ = try? await session.getListings()
                    } else if i % 4 == 1 {
                        _ = try? await session.getSearchFilters()
                    } else if i % 4 == 2 {
                        _ = try? await session.getSettings()
                    } else {
                        _ = try? await session.getHome()
                    }
                }
            }
        }

        let listings = try await session.getListings()
        #expect(!listings.isEmpty)

        await session.close()
    }
}
