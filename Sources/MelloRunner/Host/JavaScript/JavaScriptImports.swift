import Foundation
import JavaScriptCore
import WasmKit

/// Provides `js` host functions imported by WebAssembly source extensions to evaluate JavaScriptCore scripts and coordinate web views.
public final class JavaScriptImports: @unchecked Sendable {
    public enum JSResult: Int32 {
        case success = 0
        case missingResult = -1
        case invalidContext = -2
        case invalidString = -3
        case invalidHandler = -4
        case invalidRequest = -5
        case invalidRuleList = -6
        case failedEncoding = -7
        case missingCookie = -8
    }

    public let resourceStore: ResourceStore
    public let printHandler: (@Sendable (String) -> Void)?

    public init(
        resourceStore: ResourceStore,
        printHandler: (@Sendable (String) -> Void)? = nil
    ) {
        self.resourceStore = resourceStore
        self.printHandler = printHandler
    }

    private func getMemory(from caller: borrowing Caller) -> Memory? {
        guard let instance = caller.instance else { return nil }
        guard let exportValue = instance.export("memory") else { return nil }
        guard case .memory(let memory) = exportValue else { return nil }
        return memory
    }

    private func readString(from memory: Memory, offset: UInt32, length: UInt32) -> String? {
        if length == 0 { return "" }
        let uOffset = UInt(offset)
        let uLength = Int(length)
        guard uOffset + UInt(uLength) <= memory.byteCount else { return nil }
        return memory.withUnsafeBufferPointer(offset: uOffset, count: uLength) { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
    }

    /// Registers the `js` module functions into the given WasmKit `Imports`.
    public func register(into imports: inout Imports, store: Store) {
        // 1. js.context_create() -> i32 (descriptor)
        imports.define(
            module: "js",
            name: "context_create",
            Function(store: store, type: FunctionType(parameters: [], results: [.i32])) { [weak self] _, _ in
                guard let self else { return [.i32(UInt32(bitPattern: JSResult.invalidContext.rawValue))] }
                let context = IsolatedJSContext(exceptionHandler: self.printHandler)
                let desc = self.resourceStore.storeObject(context)
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 2. js.context_eval(descriptor: i32, string_pointer: i32, length: i32) -> i32 (descriptor)
        imports.define(
            module: "js",
            name: "context_eval",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidContext.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let context: IsolatedJSContext = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidContext.rawValue))]
                }
                guard let script = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidString.rawValue))]
                }

                let semaphore = DispatchSemaphore(value: 0)
                let box = JSResultBox()

                Task {
                    let res = await context.evaluateScript(script)
                    box.result = res
                    semaphore.signal()
                }
                semaphore.wait()

                guard let result = box.result else {
                    return [.i32(UInt32(bitPattern: JSResult.missingResult.rawValue))]
                }

                let desc = self.resourceStore.store(string: result)
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 3. js.context_eval_async(descriptor: i32, string_pointer: i32, length: i32) -> i32 (descriptor)
        imports.define(
            module: "js",
            name: "context_eval_async",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidContext.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let context: IsolatedJSContext = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidContext.rawValue))]
                }
                guard let script = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidString.rawValue))]
                }

                let semaphore = DispatchSemaphore(value: 0)
                let box = JSResultBox()

                Task {
                    do {
                        let res = try await context.evaluateAsyncScript(script)
                        box.result = res
                    } catch {
                        self.printHandler?("JS Async Error: \(error.localizedDescription)")
                        box.error = error
                    }
                    semaphore.signal()
                }
                semaphore.wait()

                guard let result = box.result else {
                    return [.i32(UInt32(bitPattern: JSResult.missingResult.rawValue))]
                }

                let desc = self.resourceStore.store(string: result)
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 4. js.context_get(descriptor: i32, string_pointer: i32, length: i32) -> i32 (descriptor)
        imports.define(
            module: "js",
            name: "context_get",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidContext.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let context: IsolatedJSContext = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidContext.rawValue))]
                }
                guard let propertyName = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidString.rawValue))]
                }

                let semaphore = DispatchSemaphore(value: 0)
                let box = JSResultBox()

                Task {
                    let res = await context.objectForKeyedSubscript(propertyName)
                    box.result = res
                    semaphore.signal()
                }
                semaphore.wait()

                guard let result = box.result else {
                    return [.i32(UInt32(bitPattern: JSResult.missingResult.rawValue))]
                }

                let desc = self.resourceStore.store(string: result)
                return [.i32(UInt32(bitPattern: desc))]
            }
        )

        // 5. js.webview_create() -> i32
        imports.define(
            module: "js",
            name: "webview_create",
            Function(store: store, type: FunctionType(parameters: [], results: [.i32])) { _, _ in
                // Webview stub for headless execution
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )

        // 6. js.webview_set_rule_list(descriptor: i32, string_pointer: i32, length: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_set_rule_list",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) { _, _ in
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )

        // 7. js.webview_load(descriptor: i32, request_descriptor: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_load",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) { _, _ in
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )

        // 8. js.webview_load_html(descriptor: i32, html_pointer: i32, html_len: i32, url_pointer: i32, url_len: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_load_html",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32, .i32, .i32], results: [.i32])) {
                _, _ in
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )

        // 9. js.webview_wait_for_load(descriptor: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_wait_for_load",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { _, _ in
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )

        // 10. js.webview_eval(descriptor: i32, string_pointer: i32, length: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_eval",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) { _, _ in
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )

        // 11. js.webview_eval_async(descriptor: i32, string_pointer: i32, length: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_eval_async",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) { _, _ in
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )

        // 12. js.webview_add_user_script(descriptor: i32, string_pointer: i32, length: i32, at_document_end: i32, for_main_frame_only: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_add_user_script",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32, .i32, .i32], results: [.i32])) {
                _, _ in
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )

        // 13. js.webview_get_cookies(descriptor: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_get_cookies",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) { _, _ in
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )

        // 14. js.webview_delete_cookie(descriptor: i32, name_pointer: i32, name_len: i32, value_pointer: i32, value_len: i32, domain_pointer: i32, domain_len: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_delete_cookie",
            Function(
                store: store,
                type: FunctionType(parameters: [.i32, .i32, .i32, .i32, .i32, .i32, .i32], results: [.i32])
            ) { _, _ in
                [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
            }
        )
    }

    /// Creates and returns a populated `Imports` instance containing the `js` module.
    public func makeImports(store: Store) -> Imports {
        var imports = Imports()
        register(into: &imports, store: store)
        return imports
    }
}

private final class JSResultBox: @unchecked Sendable {
    var result: String?
    var error: (any Error & Sendable)?
}
