import Foundation
import WasmKit
import os

/// High-level coordinator managing an instantiated source extension session.
///
/// `SourceSession` is a thread-safe `Sendable` wrapper over `HostBridge` that provides typed access
/// to static and dynamic listings, filters, settings, manga searches, chapter page extraction,
/// and authentication flows.
public final class SourceSession: Sendable {
    /// The loaded source package bundle.
    public let package: SourcePackage

    /// Discovered capabilities and exported functions supported by this extension.
    public let features: SourceFeatures

    /// Static exploration listings declared in `source.json`.
    public let staticListings: [Listing]

    /// Static query filters declared in `filters.json`.
    public let staticFilters: [Filter]

    /// Static in-app settings declared in `settings.json`.
    public let staticSettings: [Setting]

    private let bridgeHolder: OSAllocatedUnfairLock<HostBridge>
    private let accumulatedHome: OSAllocatedUnfairLock<Home?>
    private let configuration: SourceSessionConfiguration
    private let encoder: PostcardEncoder
    private let decoder: PostcardDecoder

    /// Underlying bridge managing the WebAssembly virtual machine and host import tables.
    public var bridge: HostBridge {
        bridgeHolder.withLock { $0 }
    }

    // MARK: - Synchronous Metadata Accessors

    /// The parsed `source.json` manifest.
    public var manifest: SourceManifest {
        package.manifest
    }

    /// Unique identifier key for this extension (e.g. `en.asurascans`).
    public var key: String {
        manifest.info.id
    }

    /// Human-readable display name for this extension (e.g. `Asura Scans`).
    public var name: String {
        manifest.info.name
    }

    /// Incremental version number of this extension.
    public var version: Int {
        manifest.info.version
    }

    /// Content rating classification (safe, contains NSFW, primarily NSFW).
    public var contentRating: SourceContentRating {
        manifest.info.contentRating ?? .safe
    }

    /// Supported language codes (e.g. `["en"]`).
    public var languages: [String] {
        manifest.info.languages
    }

    /// Base URLs declared by the extension.
    public var urls: [URL] {
        var result: [URL] = []
        if let primary = manifest.info.url.flatMap({ URL(string: $0) }) {
            result.append(primary)
        }
        if let secondary = manifest.info.urls?.compactMap({ URL(string: $0) }) {
            for url in secondary where !result.contains(url) {
                result.append(url)
            }
        }
        return result
    }

    /// Whether this extension provides any exploration categories (static or dynamic).
    public var hasListings: Bool {
        features.dynamicListings || !staticListings.isEmpty
    }

    /// Whether the extension only supports searching and lacks a home feed or listings.
    public var onlySearch: Bool {
        !features.providesHome && !hasListings
    }

    /// Whether the extension supports searching specifically by artist name.
    public var supportsArtistSearch: Bool {
        manifest.config?.supportsArtistSearch
            ?? staticFilters.contains {
                if case .text = $0.value {
                    return $0.id == "artist"
                }
                return false
            }
    }

    /// Whether the extension supports searching specifically by author name.
    public var supportsAuthorSearch: Bool {
        manifest.config?.supportsAuthorSearch
            ?? staticFilters.contains {
                if case .text = $0.value {
                    return $0.id == "author"
                }
                return false
            }
    }

    /// Whether the extension supports tag/genre filtering during search.
    public var supportsTagSearch: Bool {
        manifest.config?.supportsTagSearch
            ?? staticFilters.contains {
                if case .multiselect(let filter) = $0.value, filter.isGenre {
                    return true
                } else if case .select(let filter) = $0.value, filter.isGenre {
                    return true
                }
                return false
            }
    }

    // MARK: - Initialization

    /// Initializes a `SourceSession` from a loaded `SourcePackage`.
    ///
    /// - Parameters:
    ///   - package: The extension bundle package.
    ///   - configuration: Session runtime configuration and host dependencies.
    public init(
        package: SourcePackage,
        configuration: SourceSessionConfiguration = .init()
    ) async throws {
        self.package = package
        self.configuration = configuration
        self.staticListings = package.manifest.listings ?? []
        self.staticFilters = package.decodeStaticFilters()
        self.staticSettings = package.decodeStaticSettings()
        self.encoder = PostcardEncoder()
        self.decoder = PostcardDecoder()
        let homeHolder = OSAllocatedUnfairLock<Home?>(initialState: nil)
        self.accumulatedHome = homeHolder

        let partialHandler = Self.makePartialHandler(
            configuration: configuration,
            sessionKey: package.manifest.info.id,
            accumulatedHome: homeHolder
        )

        let bridge = try HostBridge(
            wasmBytes: package.wasmBytes,
            engine: configuration.engine,
            maximumBytes: configuration.maximumBytes,
            transport: configuration.transport,
            rateLimiter: configuration.rateLimiter,
            settingsStore: configuration.settingsStore,
            settingsNamespace: package.manifest.info.id,
            printHandler: configuration.printHandler,
            partialResultHandler: partialHandler,
            additionalImports: configuration.additionalImports
        )
        self.bridgeHolder = OSAllocatedUnfairLock(initialState: bridge)

        // Discover features from exports
        self.features = await SourceFeatures.discover(from: bridge)

        // Invoke start export if present (standard Aidoku extension lifecycle)
        if await bridge.hasExport("start") {
            _ = try await bridge.invoke("start")
        }
    }

    /// Convenience initializer loading directly from an `.aix` archive file or unpacked directory URL.
    public convenience init(
        url: URL,
        configuration: SourceSessionConfiguration = .init()
    ) async throws {
        let package = try SourcePackage.load(from: url)
        try await self.init(package: package, configuration: configuration)
    }

    // MARK: - Lifecycle & Restart

    /// Restarts the WebAssembly runtime environment, resetting state and clearing caches.
    public func restart() async throws {
        let oldBridge = bridge
        await oldBridge.close()

        accumulatedHome.withLock { $0 = nil }
        let partialHandler = Self.makePartialHandler(
            configuration: configuration,
            sessionKey: key,
            accumulatedHome: accumulatedHome
        )

        let newBridge = try HostBridge(
            wasmBytes: package.wasmBytes,
            engine: configuration.engine,
            maximumBytes: configuration.maximumBytes,
            transport: configuration.transport,
            rateLimiter: configuration.rateLimiter,
            settingsStore: configuration.settingsStore,
            settingsNamespace: package.manifest.info.id,
            printHandler: configuration.printHandler,
            partialResultHandler: partialHandler,
            additionalImports: configuration.additionalImports
        )
        bridgeHolder.withLock { $0 = newBridge }

        if await newBridge.hasExport("start") {
            _ = try await newBridge.invoke("start")
        }
    }

    private static func makePartialHandler(
        configuration: SourceSessionConfiguration,
        sessionKey: String,
        accumulatedHome: OSAllocatedUnfairLock<Home?>
    ) -> @Sendable (Data) -> Void {
        return { data in
            configuration.partialResultHandler?(data)
            guard let partial = try? PostcardDecoder().decode(HomePartialResult.self, from: data) else { return }
            switch partial {
                case .layout(var home):
                    home.setSourceKey(sessionKey)
                    let finalHome = home
                    accumulatedHome.withLock { $0 = finalHome }
                    configuration.partialHomeHandler?(finalHome)
                case .component(var component):
                    component.setSourceKey(sessionKey)
                    let finalComponent = component
                    let currentHome = accumulatedHome.withLock { home in
                        if var existing = home {
                            if let idx = existing.components.firstIndex(where: { $0.title == finalComponent.title }) {
                                existing.components[idx] = finalComponent
                            } else {
                                existing.components.append(finalComponent)
                            }
                            home = existing
                            return existing
                        } else {
                            let newHome = Home(components: [finalComponent])
                            home = newHome
                            return newHome
                        }
                    }
                    configuration.partialHomeHandler?(currentHome)
            }
        }
    }

    // MARK: - Listings, Filters, and Settings

    /// Retrieves exploration categories, combining static `source.json` listings with dynamic guest listings.
    public func getListings() async throws -> [Listing] {
        if features.dynamicListings {
            let dynamic = try await bridge.invokeAndDecode([Listing].self, export: "get_listings")
            return staticListings + dynamic
        } else {
            return staticListings
        }
    }

    /// Retrieves search filters, combining static `filters.json` filters with dynamic guest filters.
    public func getSearchFilters() async throws -> [Filter] {
        if features.dynamicFilters {
            let dynamic = try await bridge.invokeAndDecode([Filter].self, export: "get_filters")
            return staticFilters + dynamic
        } else {
            return staticFilters
        }
    }

    /// Retrieves in-app settings, combining static `settings.json` settings with dynamic guest settings.
    public func getSettings() async throws -> [Setting] {
        if features.dynamicSettings {
            let dynamic = try await bridge.invokeAndDecode([Setting].self, export: "get_settings")
            return staticSettings + dynamic
        } else {
            return staticSettings
        }
    }

    // MARK: - Content Browsing and Search

    /// Queries a paginated list of manga for a specific exploration listing.
    public func getMangaList(listing: Listing, page: Int) async throws -> MangaPageResult {
        let listingData = try encoder.encode(listing)
        let listingPtr = bridge.storeResource(listingData)
        defer { bridge.removeResource(listingPtr) }

        var result = try await bridge.invokeAndDecode(
            MangaPageResult.self,
            export: "get_manga_list",
            arguments: [.i32(listingPtr), .i32(Int32(page))]
        )
        result.setSourceKey(key)
        return result
    }

    /// Performs a search query with optional text keywords and filter values.
    public func getSearchMangaList(
        query: String?,
        page: Int,
        filters: [FilterValue] = []
    ) async throws -> MangaPageResult {
        let queryPtr = bridge.storeResource(string: query ?? "")
        defer { bridge.removeResource(queryPtr) }

        let filtersData = try encoder.encode(filters)
        let filtersPtr = bridge.storeResource(filtersData)
        defer { bridge.removeResource(filtersPtr) }

        var result = try await bridge.invokeAndDecode(
            MangaPageResult.self,
            export: "get_search_manga_list",
            arguments: [.i32(queryPtr), .i32(Int32(page)), .i32(filtersPtr)]
        )
        result.setSourceKey(key)
        return result
    }

    /// Fetches updated details, metadata, and chapters for a manga entry.
    public func getMangaUpdate(
        manga: Manga,
        needsDetails: Bool = true,
        needsChapters: Bool = true
    ) async throws -> Manga {
        let mangaData = try encoder.encode(manga)
        let mangaPtr = bridge.storeResource(mangaData)
        defer { bridge.removeResource(mangaPtr) }

        var updatedManga = try await bridge.invokeAndDecode(
            Manga.self,
            export: "get_manga_update",
            arguments: [
                .i32(mangaPtr),
                .i32(needsDetails ? 1 : 0),
                .i32(needsChapters ? 1 : 0),
            ]
        )
        updatedManga.sourceKey = key
        return updatedManga
    }

    /// Fetches the list of pages belonging to a chapter.
    public func getPageList(manga: Manga, chapter: Chapter) async throws -> [Page] {
        var cleanManga = manga
        cleanManga.chapters = nil
        let mangaData = try encoder.encode(cleanManga)
        let mangaPtr = bridge.storeResource(mangaData)
        defer { bridge.removeResource(mangaPtr) }

        let chapterData = try encoder.encode(chapter)
        let chapterPtr = bridge.storeResource(chapterData)
        defer { bridge.removeResource(chapterPtr) }

        return try await bridge.invokeAndDecode(
            [Page].self,
            export: "get_page_list",
            arguments: [.i32(mangaPtr), .i32(chapterPtr)]
        )
    }

    /// Fetches the dynamic home feed layout and components.
    public func getHome() async throws -> Home {
        accumulatedHome.withLock { $0 = nil }
        var home = try await bridge.invokeAndDecode(Home.self, export: "get_home")
        home.setSourceKey(key)
        if home.components.isEmpty, let streamed = accumulatedHome.withLock({ $0 }) {
            return streamed
        }
        return home
    }

    // MARK: - Image Processing and Requests

    /// Formats a custom HTTP request for an image URL with extension-specific headers/auth.
    public func getImageRequest(url: String, context: PageContext? = nil) async throws -> URLRequest {
        let urlData = try encoder.encode(url)
        let urlPtr = bridge.storeResource(urlData)
        defer { bridge.removeResource(urlPtr) }

        let contextPtr: Int32
        if let context {
            let contextData = try encoder.encode(context)
            contextPtr = bridge.storeResource(contextData)
        } else {
            contextPtr = -1
        }
        defer {
            if contextPtr >= 0 {
                bridge.removeResource(contextPtr)
            }
        }

        let requestPtr = try await bridge.invokeAndDecode(
            Int32.self,
            export: "get_image_request",
            arguments: [.i32(urlPtr), .i32(contextPtr)]
        )
        defer { bridge.resourceStore.remove(requestPtr) }

        guard let request: NetRequest = bridge.resourceStore.fetchObject(requestPtr),
            let urlRequest = request.toURLRequest()
        else {
            throw RuntimeError.trap("Image request descriptor \(requestPtr) could not be resolved to URLRequest")
        }
        return urlRequest
    }

    /// Processes a chapter page image if the extension supports `process_page_image`.
    ///
    /// - Parameters:
    ///   - data: Raw bytes of the image response.
    ///   - url: URL of the fetched image.
    ///   - headers: Response HTTP headers.
    ///   - statusCode: Response HTTP status code.
    ///   - context: Optional chapter page context.
    /// - Returns: Processed image raw bytes, or nil if unprocessed.
    public func processPageImage(
        data: Data,
        url: URL? = nil,
        headers: [String: String] = [:],
        statusCode: Int = 200,
        context: PageContext? = nil
    ) async throws -> Data? {
        guard features.processesPages else { return data }

        let imageDescriptor = bridge.storeResource(data)
        defer { bridge.removeResource(imageDescriptor) }

        let request = ImageRequest(url: url, headers: [:])
        let response = ImageResponse(code: statusCode, headers: headers, request: request, image: imageDescriptor)
        let responseData = try encoder.encode(response)
        let responsePtr = bridge.storeResource(responseData)
        defer { bridge.removeResource(responsePtr) }

        let contextPtr: Int32
        if let context {
            let contextData = try encoder.encode(context)
            contextPtr = bridge.storeResource(contextData)
        } else {
            contextPtr = -1
        }
        defer {
            if contextPtr >= 0 {
                bridge.removeResource(contextPtr)
            }
        }

        let resultImageRef = try await bridge.invokeAndDecode(
            Int32.self,
            export: "process_page_image",
            arguments: [.i32(responsePtr), .i32(contextPtr)]
        )
        defer { bridge.removeResource(resultImageRef) }

        return bridge.resourceStore.fetch(resultImageRef)
    }

    /// Processes a manga cover image if the extension supports `process_cover_image`.
    public func processCoverImage(
        data: Data,
        url: URL? = nil,
        headers: [String: String] = [:],
        statusCode: Int = 200
    ) async throws -> Data? {
        guard features.processesCovers else { return data }

        let imageDescriptor = bridge.storeResource(data)
        defer { bridge.removeResource(imageDescriptor) }

        let request = ImageRequest(url: url, headers: [:])
        let response = ImageResponse(code: statusCode, headers: headers, request: request, image: imageDescriptor)
        let responseData = try encoder.encode(response)
        let responsePtr = bridge.storeResource(responseData)
        defer { bridge.removeResource(responsePtr) }

        let resultImageRef = try await bridge.invokeAndDecode(
            Int32.self,
            export: "process_cover_image",
            arguments: [.i32(responsePtr)]
        )
        defer { bridge.removeResource(resultImageRef) }

        return bridge.resourceStore.fetch(resultImageRef)
    }

    /// Queries the extension for its current base URL.
    public func getBaseUrl() async throws -> URL? {
        let urlString = try await bridge.invokeAndDecode(String.self, export: "get_base_url")
        return URL(string: urlString)
    }

    /// Retrieves an extended localized page description.
    public func getPageDescription(page: Page) async throws -> String? {
        let pageData = try encoder.encode(page)
        let pagePtr = bridge.storeResource(pageData)
        defer { bridge.removeResource(pagePtr) }

        return try await bridge.invokeAndDecode(
            String.self,
            export: "get_page_description",
            arguments: [.i32(pagePtr)]
        )
    }

    /// Retrieves alternative cover art image URLs for a manga.
    public func getAlternateCovers(manga: Manga) async throws -> [String] {
        let mangaData = try encoder.encode(manga)
        let mangaPtr = bridge.storeResource(mangaData)
        defer { bridge.removeResource(mangaPtr) }

        return try await bridge.invokeAndDecode(
            [String].self,
            export: "get_alternate_covers",
            arguments: [.i32(mangaPtr)]
        )
    }

    // MARK: - Handlers & Auth

    /// Dispatches a user action or notification event to the extension.
    public func handleNotification(notification: String) async throws {
        let data = try encoder.encode(notification)
        let ptr = bridge.storeResource(data)
        defer { bridge.removeResource(ptr) }

        _ = try await bridge.invoke("handle_notification", arguments: [.i32(ptr)])
    }

    /// Resolves an incoming deep link URI to its matching manga, chapter, or listing.
    public func handleDeepLink(url: String) async throws -> DeepLinkResult? {
        let data = try encoder.encode(url)
        let ptr = bridge.storeResource(data)
        defer { bridge.removeResource(ptr) }

        return try await bridge.invokeAndDecode(
            DeepLinkResult?.self,
            export: "handle_deep_link",
            arguments: [.i32(ptr)]
        )
    }

    /// Submits credentials for basic username/password authentication.
    public func handleBasicLogin(key: String, username: String, password: String) async throws -> Bool {
        let keyData = try encoder.encode(key)
        let keyPtr = bridge.storeResource(keyData)
        defer { bridge.removeResource(keyPtr) }

        let userBytes = try encoder.encode(username)
        let userPtr = bridge.storeResource(userBytes)
        defer { bridge.removeResource(userPtr) }

        let passBytes = try encoder.encode(password)
        let passPtr = bridge.storeResource(passBytes)
        defer { bridge.removeResource(passPtr) }

        return try await bridge.invokeAndDecode(
            Bool.self,
            export: "handle_basic_login",
            arguments: [.i32(keyPtr), .i32(userPtr), .i32(passPtr)]
        )
    }

    /// Submits authenticated cookies for web view authentication.
    public func handleWebLogin(key: String, cookies: [String: String]) async throws -> Bool {
        let keyData = try encoder.encode(key)
        let keyPtr = bridge.storeResource(keyData)
        defer { bridge.removeResource(keyPtr) }

        let keys = [String](cookies.keys)
        let values = keys.map { cookies[$0] ?? "" }

        let keysData = try encoder.encode(keys)
        let keysPtr = bridge.storeResource(keysData)
        defer { bridge.removeResource(keysPtr) }

        let valuesData = try encoder.encode(values)
        let valuesPtr = bridge.storeResource(valuesData)
        defer { bridge.removeResource(valuesPtr) }

        return try await bridge.invokeAndDecode(
            Bool.self,
            export: "handle_web_login",
            arguments: [.i32(keyPtr), .i32(keysPtr), .i32(valuesPtr)]
        )
    }

    /// Migrates legacy keys for manga and chapters to current identifiers.
    public func handleMigration(kind: KeyKind, mangaKey: String, chapterKey: String? = nil) async throws -> String {
        let mangaData = try encoder.encode(mangaKey)
        let mangaPtr = bridge.storeResource(mangaData)
        defer { bridge.removeResource(mangaPtr) }

        let chapterPtr: Int32
        if let chapterKey {
            let chapterData = try encoder.encode(chapterKey)
            chapterPtr = bridge.storeResource(chapterData)
        } else {
            chapterPtr = -1
        }
        defer {
            if chapterPtr >= 0 {
                bridge.removeResource(chapterPtr)
            }
        }

        return try await bridge.invokeAndDecode(
            String.self,
            export: "handle_key_migration",
            arguments: [.i32(Int32(kind.rawValue)), .i32(mangaPtr), .i32(chapterPtr)]
        )
    }

    // MARK: - Teardown

    /// Closes the session and releases all associated WebAssembly instances and host resources.
    public func close() async {
        await bridge.close()
    }
}
