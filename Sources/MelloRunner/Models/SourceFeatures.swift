import Foundation

/// Capabilities and exported function features supported by a source extension instance.
public struct SourceFeatures: Sendable, Hashable {
    /// Whether the extension exports `get_manga_list` for browsing listings.
    public let providesListings: Bool

    /// Whether the extension exports `get_home` for dynamic home feed views.
    public let providesHome: Bool

    /// Whether the extension exports `get_filters` for dynamic query filters.
    public let dynamicFilters: Bool

    /// Whether the extension exports `get_settings` for dynamic in-app settings.
    public let dynamicSettings: Bool

    /// Whether the extension exports `get_listings` for dynamic exploration categories.
    public let dynamicListings: Bool

    /// Whether the extension exports `process_page_image` for modifying chapter page images.
    public let processesPages: Bool

    /// Whether the extension exports `process_cover_image` for modifying manga cover images.
    public let processesCovers: Bool

    /// Whether the extension exports `get_image_request` for custom image request headers/auth.
    public let providesImageRequests: Bool

    /// Whether the extension exports `get_page_description` for localized page text.
    public let providesPageDescriptions: Bool

    /// Whether the extension exports `get_alternate_covers` for multi-cover selection.
    public let providesAlternateCovers: Bool

    /// Whether the extension exports `get_base_url` for dynamic host domain resolution.
    public let providesBaseUrl: Bool

    /// Whether the extension exports `handle_notification` for user action callbacks.
    public let handlesNotifications: Bool

    /// Whether the extension exports `handle_deep_link` for URI scheme routing.
    public let handlesDeepLinks: Bool

    /// Whether the extension exports `handle_basic_login` for username/password authentication.
    public let handlesBasicLogin: Bool

    /// Whether the extension exports `handle_web_login` for cookie-based web authentication.
    public let handlesWebLogin: Bool

    /// Whether the extension exports `handle_key_migration` for manga/chapter key updates.
    public let handlesMigration: Bool

    public init(
        providesListings: Bool = false,
        providesHome: Bool = false,
        dynamicFilters: Bool = false,
        dynamicSettings: Bool = false,
        dynamicListings: Bool = false,
        processesPages: Bool = false,
        processesCovers: Bool = false,
        providesImageRequests: Bool = false,
        providesPageDescriptions: Bool = false,
        providesAlternateCovers: Bool = false,
        providesBaseUrl: Bool = false,
        handlesNotifications: Bool = false,
        handlesDeepLinks: Bool = false,
        handlesBasicLogin: Bool = false,
        handlesWebLogin: Bool = false,
        handlesMigration: Bool = false
    ) {
        self.providesListings = providesListings
        self.providesHome = providesHome
        self.dynamicFilters = dynamicFilters
        self.dynamicSettings = dynamicSettings
        self.dynamicListings = dynamicListings
        self.processesPages = processesPages
        self.processesCovers = processesCovers
        self.providesImageRequests = providesImageRequests
        self.providesPageDescriptions = providesPageDescriptions
        self.providesAlternateCovers = providesAlternateCovers
        self.providesBaseUrl = providesBaseUrl
        self.handlesNotifications = handlesNotifications
        self.handlesDeepLinks = handlesDeepLinks
        self.handlesBasicLogin = handlesBasicLogin
        self.handlesWebLogin = handlesWebLogin
        self.handlesMigration = handlesMigration
    }
}

extension SourceFeatures {
    /// Inspects the WebAssembly module instance on `HostBridge` and discovers which features are supported.
    public static func discover(from bridge: HostBridge) async -> SourceFeatures {
        let providesListings = await bridge.hasExport("get_manga_list")
        let providesHome = await bridge.hasExport("get_home")
        let dynamicFilters = await bridge.hasExport("get_filters")
        let dynamicSettings = await bridge.hasExport("get_settings")
        let dynamicListings = await bridge.hasExport("get_listings")
        let processesPages = await bridge.hasExport("process_page_image")
        let processesCovers = await bridge.hasExport("process_cover_image")
        let providesImageRequests = await bridge.hasExport("get_image_request")
        let providesPageDescriptions = await bridge.hasExport("get_page_description")
        let providesAlternateCovers = await bridge.hasExport("get_alternate_covers")
        let providesBaseUrl = await bridge.hasExport("get_base_url")
        let handlesNotifications = await bridge.hasExport("handle_notification")
        let handlesDeepLinks = await bridge.hasExport("handle_deep_link")
        let handlesBasicLogin = await bridge.hasExport("handle_basic_login")
        let handlesWebLogin = await bridge.hasExport("handle_web_login")
        let handlesMigration = await bridge.hasExport("handle_key_migration")

        return SourceFeatures(
            providesListings: providesListings,
            providesHome: providesHome,
            dynamicFilters: dynamicFilters,
            dynamicSettings: dynamicSettings,
            dynamicListings: dynamicListings,
            processesPages: processesPages,
            processesCovers: processesCovers,
            providesImageRequests: providesImageRequests,
            providesPageDescriptions: providesPageDescriptions,
            providesAlternateCovers: providesAlternateCovers,
            providesBaseUrl: providesBaseUrl,
            handlesNotifications: handlesNotifications,
            handlesDeepLinks: handlesDeepLinks,
            handlesBasicLogin: handlesBasicLogin,
            handlesWebLogin: handlesWebLogin,
            handlesMigration: handlesMigration
        )
    }
}
