import Foundation
import WasmKit

/// Runtime options and environment dependencies passed to a `SourceSession`.
public struct SourceSessionConfiguration: Sendable {
    /// Runtime WebAssembly execution engine.
    public var engine: RuntimeEngine

    /// Upper boundary on WebAssembly linear memory allocations in bytes.
    public var maximumBytes: Int

    /// Network transport protocol implementation used for guest HTTP requests.
    public var transport: any HTTPTransport

    /// Rate limiter used to pace outbound HTTP requests.
    public var rateLimiter: RateLimiter

    /// Storage backend used to persist extension settings and state.
    public var settingsStore: any SettingsStore

    /// Optional closure receiving diagnostic or debug print lines from the extension.
    public var printHandler: (@Sendable (String) -> Void)?

    /// Optional closure receiving intermediate partial results (e.g. streaming home feed updates).
    public var partialResultHandler: (@Sendable (Data) -> Void)?

    /// Optional hook to link additional WebAssembly host imports into the store.
    public var additionalImports: (@Sendable (Store, inout Imports) -> Void)?

    public init(
        engine: RuntimeEngine = .shared,
        maximumBytes: Int = 64 * 1024 * 1024,
        transport: any HTTPTransport = URLSessionTransport(),
        rateLimiter: RateLimiter = RateLimiter(),
        settingsStore: any SettingsStore = InMemorySettingsStore(),
        printHandler: (@Sendable (String) -> Void)? = nil,
        partialResultHandler: (@Sendable (Data) -> Void)? = nil,
        additionalImports: (@Sendable (Store, inout Imports) -> Void)? = nil
    ) {
        self.engine = engine
        self.maximumBytes = maximumBytes
        self.transport = transport
        self.rateLimiter = rateLimiter
        self.settingsStore = settingsStore
        self.printHandler = printHandler
        self.partialResultHandler = partialResultHandler
        self.additionalImports = additionalImports
    }
}
