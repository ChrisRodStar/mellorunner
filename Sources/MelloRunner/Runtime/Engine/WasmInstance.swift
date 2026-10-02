import Foundation
import WasmKit

/// Internal wrapper managing a WasmKit module, instance, and store lifetime.
final class WasmInstance {
    private var store: Store?
    private var instance: Instance?

    private var functionCache: [String: Function] = [:]

    init(
        engine: RuntimeEngine,
        bytes: Data,
        makeImports: ((Store) -> Imports)? = nil
    ) throws(RuntimeError) {
        let module: Module
        do {
            module = try parseWasm(bytes: [UInt8](bytes))
        } catch {
            throw RuntimeError.invalidModule("Failed to parse WebAssembly binary: \(error)")
        }

        let store = Store(engine: engine.engine)
        let imports = makeImports?(store) ?? Imports()
        let instance: Instance
        do {
            instance = try module.instantiate(store: store, imports: imports)
        } catch {
            throw RuntimeError.invalidModule("Failed to instantiate WebAssembly module: \(error)")
        }

        self.store = store
        self.instance = instance
    }

    var isInstantiated: Bool {
        instance != nil && store != nil
    }

    func hasExport(_ name: String) -> Bool {
        guard let instance else { return false }
        if functionCache[name] != nil { return true }
        return instance.export(name) != nil
    }

    func function(named name: String) throws(RuntimeError) -> Function {
        if let cached = functionCache[name] {
            return cached
        }
        guard let instance else {
            throw RuntimeError.instanceClosed
        }
        guard let exportValue = instance.export(name) else {
            throw RuntimeError.exportNotFound(name)
        }
        guard case .function(let function) = exportValue else {
            throw RuntimeError.exportNotAFunction(name)
        }
        functionCache[name] = function
        return function
    }

    func invoke(export name: String, arguments: [RuntimeValue] = []) throws(RuntimeError) -> [RuntimeValue] {
        let function = try function(named: name)
        let wasmArgs = arguments.map(\.wasmValue)
        do {
            let wasmResults = try function.invoke(wasmArgs)
            return wasmResults.map(RuntimeValue.init)
        } catch {
            throw RuntimeError.trap("Trap during execution of '\(name)': \(error)")
        }
    }

    func invokeInt32(export name: String, arguments: [RuntimeValue] = []) throws(RuntimeError) -> Int32 {
        let results = try invoke(export: name, arguments: arguments)
        guard let first = results.first, case .i32(let value) = first, results.count == 1 else {
            throw RuntimeError.exportResultMismatch(
                expected: "single i32",
                actual: "\(results)"
            )
        }
        return value
    }

    func withMemory<R: Sendable>(
        offset: UInt,
        count: Int,
        _ body: @Sendable (UnsafeRawBufferPointer) throws -> R
    ) throws(RuntimeError) -> R {
        guard let instance else {
            throw RuntimeError.instanceClosed
        }
        guard let exportValue = instance.export("memory"), case .memory(let memory) = exportValue else {
            throw RuntimeError.exportNotFound("memory")
        }
        guard Int(offset) + count <= memory.byteCount else {
            throw RuntimeError.resourceLimitExceeded(
                "Memory read out of bounds: offset \(offset) + count \(count) exceeds size \(memory.byteCount)"
            )
        }
        do {
            return try memory.withUnsafeBufferPointer(offset: offset, count: count, body)
        } catch {
            throw RuntimeError.trap("Error accessing guest memory: \(error)")
        }
    }

    func readMemory(offset: UInt, count: Int) throws(RuntimeError) -> Data {
        try withMemory(offset: offset, count: count) { buffer in
            Data(buffer)
        }
    }

    func getMemory() throws(RuntimeError) -> Memory {
        guard let instance else {
            throw RuntimeError.instanceClosed
        }
        guard let exportValue = instance.export("memory"), case .memory(let memory) = exportValue else {
            throw RuntimeError.exportNotFound("memory")
        }
        return memory
    }

    func close() {
        self.functionCache.removeAll(keepingCapacity: false)
        self.instance = nil
        self.store = nil
    }

    deinit {
        close()
    }
}
