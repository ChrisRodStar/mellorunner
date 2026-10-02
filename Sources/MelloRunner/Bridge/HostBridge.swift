import Foundation
import WasmKit

/// Actor that bridges high-level Swift requests to the isolated WebAssembly guest session,
/// managing outbound host buffer descriptors, standard imports, and return value framing.
public actor HostBridge {
    public let session: ExecutionSession
    public nonisolated let resourceStore: ResourceStore
    public nonisolated let standardImports: StandardImports
    public nonisolated let decoder: PostcardDecoder

    public init(
        wasmBytes: Data,
        engine: RuntimeEngine = .shared,
        maximumBytes: Int = 64 * 1024 * 1024,
        resourceStore: ResourceStore = ResourceStore(),
        decoder: PostcardDecoder = PostcardDecoder(),
        printHandler: (@Sendable (String) -> Void)? = nil,
        partialResultHandler: (@Sendable (Data) -> Void)? = nil,
        additionalImports: (@Sendable (Store, inout Imports) -> Void)? = nil
    ) throws(RuntimeError) {
        self.resourceStore = resourceStore
        self.decoder = decoder
        let imports = StandardImports(
            resourceStore: resourceStore,
            printHandler: printHandler,
            partialResultHandler: partialResultHandler
        )
        self.standardImports = imports

        self.session = try ExecutionSession(
            data: wasmBytes,
            engine: engine,
            maximumBytes: maximumBytes,
            makeImports: { store in
                var wasmImports = imports.makeImports(store: store)
                additionalImports?(store, &wasmImports)
                return wasmImports
            }
        )
    }

    /// Invoke an exported WebAssembly function by name.
    @discardableResult
    public func invoke(
        _ name: String,
        arguments: [RuntimeValue] = []
    ) async throws(RuntimeError) -> [RuntimeValue] {
        try await session.invoke(name, arguments: arguments)
    }

    /// Invoke an exported WebAssembly function expecting an integer return value.
    public func invokeInt32(
        _ name: String,
        arguments: [RuntimeValue] = []
    ) async throws(RuntimeError) -> Int32 {
        try await session.invokeInt32(name, arguments: arguments)
    }

    /// Invoke an exported WebAssembly function expecting a framed return pointer,
    /// extracting the raw payload data and releasing the guest buffer.
    public func invokeResult(
        _ name: String,
        arguments: [RuntimeValue] = []
    ) async throws -> Data {
        try await session.invokeResult(name, arguments: arguments)
    }

    /// Invoke an exported WebAssembly function, decode the Postcard payload, and free the guest buffer.
    public func invokeAndDecode<T: Decodable>(
        _ type: T.Type,
        export name: String,
        arguments: [RuntimeValue] = []
    ) async throws -> T {
        let data = try await invokeResult(name, arguments: arguments)
        return try decoder.decode(type, from: data)
    }

    /// Store data in the resource store and return its descriptor handle.
    @discardableResult
    public func storeResource(_ data: Data) -> Int32 {
        resourceStore.store(data)
    }

    /// Store a UTF-8 string in the resource store and return its descriptor handle.
    @discardableResult
    public func storeResource(string: String) -> Int32 {
        resourceStore.store(string: string)
    }

    /// Remove a resource from the store by its descriptor handle.
    @discardableResult
    public func removeResource(_ descriptor: Int32) -> Data? {
        resourceStore.remove(descriptor)
    }

    /// Closes the bridge, releasing all stored resources and terminating the execution session.
    public func close() async {
        resourceStore.removeAll()
        await session.close()
    }
}
