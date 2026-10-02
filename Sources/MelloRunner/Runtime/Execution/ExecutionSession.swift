import Foundation

/// Coordinates isolated, exclusive execution of a WebAssembly module instance.
///
/// `ExecutionSession` is an actor that enforces single-threaded confinement of the underlying
/// virtual machine and guards against re-entrant calls during async suspension points.
public actor ExecutionSession {
    private let instance: WasmInstance
    private var isInvoking: Bool = false
    private var isClosed: Bool = false

    /// Initialize a session from WebAssembly binary bytes.
    ///
    /// Validates the 8-byte WebAssembly binary header and size limits prior to engine instantiation.
    /// - Parameters:
    ///   - data: The binary bytes of the WebAssembly module.
    ///   - engine: The runtime engine to associate with this session. Defaults to `.shared`.
    ///   - maximumBytes: Maximum allowed module size in bytes. Defaults to 64MB.
    public init(
        data: Data,
        engine: RuntimeEngine = .shared,
        maximumBytes: Int = 64 * 1024 * 1024
    ) throws(RuntimeError) {
        do {
            _ = try ModuleHeader(data: data, maximumBytes: maximumBytes)
        } catch {
            throw RuntimeError.invalidModule("Header validation failed: \(error)")
        }

        self.instance = try WasmInstance(engine: engine, bytes: data)
    }

    /// Check if the module exports a symbol with the specified name.
    public func hasExport(_ name: String) -> Bool {
        guard !isClosed else { return false }
        return instance.hasExport(name)
    }

    /// Invoke an exported WebAssembly function by name.
    ///
    /// - Parameters:
    ///   - name: The export name of the function to invoke.
    ///   - arguments: The arguments to pass to the function.
    /// - Returns: An array of result values produced by the function.
    @discardableResult
    public func invoke(
        _ name: String,
        arguments: [RuntimeValue] = []
    ) async throws(RuntimeError) -> [RuntimeValue] {
        guard !isClosed else {
            throw RuntimeError.instanceClosed
        }
        guard !isInvoking else {
            throw RuntimeError.invocationBusy
        }

        isInvoking = true
        defer { isInvoking = false }

        return try instance.invoke(export: name, arguments: arguments)
    }

    /// Convenience invocation for functions returning a single 32-bit integer.
    public func invokeInt32(
        _ name: String,
        arguments: [RuntimeValue] = []
    ) async throws(RuntimeError) -> Int32 {
        let results = try await invoke(name, arguments: arguments)
        guard let first = results.first, case .i32(let value) = first, results.count == 1 else {
            throw RuntimeError.exportResultMismatch(
                expected: "single i32",
                actual: "\(results)"
            )
        }
        return value
    }

    /// Access a region of the guest instance's linear memory without copying into an intermediate buffer.
    public func withMemory<R: Sendable>(
        offset: UInt,
        count: Int,
        _ body: @Sendable (UnsafeRawBufferPointer) throws -> R
    ) throws(RuntimeError) -> R {
        guard !isClosed else {
            throw RuntimeError.instanceClosed
        }
        return try instance.withMemory(offset: offset, count: count, body)
    }

    /// Read bytes from the guest instance's exported linear memory.
    public func readMemory(offset: UInt, count: Int) async throws(RuntimeError) -> Data {
        guard !isClosed else {
            throw RuntimeError.instanceClosed
        }
        return try instance.readMemory(offset: offset, count: count)
    }

    /// Explicitly close the session and release all guest and host resources.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        instance.close()
    }
}
