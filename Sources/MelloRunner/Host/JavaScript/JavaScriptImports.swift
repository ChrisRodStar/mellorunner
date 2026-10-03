import Foundation
import JavaScriptCore
import WasmKit
import WebKit

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
    public let webViewNamespace: String

    public init(
        resourceStore: ResourceStore,
        printHandler: (@Sendable (String) -> Void)? = nil,
        webViewNamespace: String = ""
    ) {
        self.resourceStore = resourceStore
        self.printHandler = printHandler
        self.webViewNamespace = webViewNamespace
    }

    private func runOnMainActor<T: Sendable>(_ body: @escaping @MainActor @Sendable () async throws -> T) -> Result<
        T, any Error & Sendable
    > {
        let box = MainActorResultBox<T>()
        if Thread.isMainThread {
            let semaphore = DispatchSemaphore(value: 0)
            Task { @MainActor in
                do {
                    let val = try await body()
                    box.result = .success(val)
                } catch {
                    box.result = .failure(error)
                }
                semaphore.signal()
            }
            while box.result == nil {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
            }
            return box.result!
        } else {
            let semaphore = DispatchSemaphore(value: 0)
            Task { @MainActor in
                do {
                    let val = try await body()
                    box.result = .success(val)
                } catch {
                    box.result = .failure(error)
                }
                semaphore.signal()
            }
            semaphore.wait()
            return box.result!
        }
    }

    private func getMemory(from caller: borrowing Caller) -> Memory? {
        guard let instance = caller.instance else { return nil }
        guard let exportValue = instance.export("memory") else { return nil }
        guard case .memory(let memory) = exportValue else { return nil }
        return memory
    }

    private func readString(from memory: Memory, offset: Int32, length: Int32) -> String? {
        guard offset >= 0, length >= 0 else { return nil }
        if length == 0 { return "" }
        let uOffset = UInt(offset)
        let uLength = Int(length)
        guard uOffset + UInt(uLength) <= memory.byteCount else { return nil }
        return memory.withUnsafeBufferPointer(offset: uOffset, count: uLength) { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
    }

    private func readString(from memory: Memory, offset: UInt32, length: UInt32) -> String? {
        let signedOffset = Int32(bitPattern: offset)
        let signedLength = Int32(bitPattern: length)
        return readString(from: memory, offset: signedOffset, length: signedLength)
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
            Function(store: store, type: FunctionType(parameters: [], results: [.i32])) { [weak self] _, _ in
                guard let self else { return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))] }
                let res = self.runOnMainActor {
                    WebKitHandler(id: self.webViewNamespace)
                }
                switch res {
                    case .success(let handler):
                        let desc = self.resourceStore.storeObject(handler)
                        return [.i32(UInt32(bitPattern: desc))]
                    case .failure:
                        return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
            }
        )

        // 6. js.webview_set_rule_list(descriptor: i32, string_pointer: i32, length: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_set_rule_list",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let handler: WebKitHandler = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                guard let jsonString = self.readString(from: memory, offset: args[1].i32, length: args[2].i32),
                    !jsonString.isEmpty
                else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidString.rawValue))]
                }
                let res = self.runOnMainActor {
                    try await handler.setRuleList(jsonString)
                }
                switch res {
                    case .success:
                        return [.i32(UInt32(bitPattern: JSResult.success.rawValue))]
                    case .failure:
                        return [.i32(UInt32(bitPattern: JSResult.invalidRuleList.rawValue))]
                }
            }
        )

        // 7. js.webview_load(descriptor: i32, request_descriptor: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_load",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let handler: WebKitHandler = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                let reqDesc = Int32(bitPattern: args[1].i32)
                guard let req: NetRequest = self.resourceStore.fetchObject(reqDesc),
                    let urlRequest = req.toURLRequest()
                else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidRequest.rawValue))]
                }
                let res = self.runOnMainActor {
                    _ = handler.webView.load(urlRequest)
                }
                switch res {
                    case .success:
                        return [.i32(UInt32(bitPattern: JSResult.success.rawValue))]
                    case .failure:
                        return [.i32(UInt32(bitPattern: JSResult.invalidRequest.rawValue))]
                }
            }
        )

        // 8. js.webview_load_html(descriptor: i32, html_pointer: i32, html_len: i32, url_pointer: i32, url_len: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_load_html",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let handler: WebKitHandler = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                guard let htmlString = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidString.rawValue))]
                }
                let urlPtr = args[3].i32
                let urlLen = args[4].i32
                let baseURL: URL?
                if urlPtr >= 0, urlLen > 0, let str = self.readString(from: memory, offset: urlPtr, length: urlLen) {
                    baseURL = URL(string: str)
                } else {
                    baseURL = nil
                }
                let res = self.runOnMainActor {
                    _ = handler.webView.loadHTMLString(htmlString, baseURL: baseURL)
                }
                switch res {
                    case .success:
                        return [.i32(UInt32(bitPattern: JSResult.success.rawValue))]
                    case .failure:
                        return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
            }
        )

        // 9. js.webview_wait_for_load(descriptor: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_wait_for_load",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let handler: WebKitHandler = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                handler.waitForLoad()
                return [.i32(UInt32(bitPattern: JSResult.success.rawValue))]
            }
        )

        // 10. js.webview_eval(descriptor: i32, string_pointer: i32, length: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_eval",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let handler: WebKitHandler = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                guard let jsString = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidString.rawValue))]
                }
                let res = self.runOnMainActor { () -> String in
                    let result = try await handler.webView.evaluateJavaScript(jsString)
                    return "\(result ?? "")"
                }
                switch res {
                    case .success(let str):
                        let desc = self.resourceStore.store(string: str)
                        return [.i32(UInt32(bitPattern: desc))]
                    case .failure:
                        return [.i32(UInt32(bitPattern: JSResult.missingResult.rawValue))]
                }
            }
        )

        // 11. js.webview_eval_async(descriptor: i32, string_pointer: i32, length: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_eval_async",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let handler: WebKitHandler = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                guard let jsString = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidString.rawValue))]
                }
                let res = self.runOnMainActor { () -> String in
                    guard let result = try await handler.evaluateAsyncJavaScript(jsString) else {
                        return ""
                    }
                    return "\(result)"
                }
                switch res {
                    case .success(let str):
                        let desc = self.resourceStore.store(string: str)
                        return [.i32(UInt32(bitPattern: desc))]
                    case .failure:
                        return [.i32(UInt32(bitPattern: JSResult.missingResult.rawValue))]
                }
            }
        )

        // 12. js.webview_add_user_script(descriptor: i32, string_pointer: i32, length: i32, at_document_end: i32, for_main_frame_only: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_add_user_script",
            Function(store: store, type: FunctionType(parameters: [.i32, .i32, .i32, .i32, .i32], results: [.i32])) {
                [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let handler: WebKitHandler = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                guard let source = self.readString(from: memory, offset: args[1].i32, length: args[2].i32) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidString.rawValue))]
                }
                let atDocumentEnd = args[3].i32 != 0
                let forMainFrameOnly = args[4].i32 != 0
                let res = self.runOnMainActor {
                    let script = WKUserScript(
                        source: source,
                        injectionTime: atDocumentEnd ? .atDocumentEnd : .atDocumentStart,
                        forMainFrameOnly: forMainFrameOnly
                    )
                    handler.webView.configuration.userContentController.addUserScript(script)
                }
                switch res {
                    case .success:
                        return [.i32(UInt32(bitPattern: JSResult.success.rawValue))]
                    case .failure:
                        return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
            }
        )

        // 13. js.webview_get_cookies(descriptor: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_get_cookies",
            Function(store: store, type: FunctionType(parameters: [.i32], results: [.i32])) {
                [weak self] _, args in
                guard let self else { return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))] }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let handler: WebKitHandler = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                let res = self.runOnMainActor { () -> [HTTPCookie] in
                    await handler.cookieStore.allCookies()
                }
                switch res {
                    case .success(let httpCookies):
                        let cookies = httpCookies.map(Cookie.init)
                        do {
                            let data = try PostcardEncoder().encode(cookies)
                            let desc = self.resourceStore.store(data)
                            return [.i32(UInt32(bitPattern: desc))]
                        } catch {
                            return [.i32(UInt32(bitPattern: JSResult.failedEncoding.rawValue))]
                        }
                    case .failure:
                        return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
            }
        )

        // 14. js.webview_delete_cookie(descriptor: i32, name_pointer: i32, name_len: i32, value_pointer: i32, value_len: i32, domain_pointer: i32, domain_len: i32) -> i32
        imports.define(
            module: "js",
            name: "webview_delete_cookie",
            Function(
                store: store,
                type: FunctionType(parameters: [.i32, .i32, .i32, .i32, .i32, .i32, .i32], results: [.i32])
            ) { [weak self] caller, args in
                guard let self, let memory = self.getMemory(from: caller) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                let descriptor = Int32(bitPattern: args[0].i32)
                guard let handler: WebKitHandler = self.resourceStore.fetchObject(descriptor) else {
                    return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
                let namePtr = Int32(bitPattern: args[1].i32)
                let nameLen = Int32(bitPattern: args[2].i32)
                let valPtr = Int32(bitPattern: args[3].i32)
                let valLen = Int32(bitPattern: args[4].i32)
                let domPtr = Int32(bitPattern: args[5].i32)
                let domLen = Int32(bitPattern: args[6].i32)

                let name =
                    (namePtr >= 0 && nameLen > 0)
                    ? self.readString(from: memory, offset: namePtr, length: nameLen) : nil
                let value =
                    (valPtr >= 0 && valLen > 0) ? self.readString(from: memory, offset: valPtr, length: valLen) : nil
                let domain =
                    (domPtr >= 0 && domLen > 0) ? self.readString(from: memory, offset: domPtr, length: domLen) : nil

                let res = self.runOnMainActor { () -> Bool in
                    if let name {
                        let cookies = await handler.cookieStore.allCookies()
                        guard
                            let cookie = cookies.first(where: {
                                let nameMatches = $0.name == name
                                let valMatches = value == nil || $0.value == value
                                let domMatches = domain == nil || $0.domain == domain
                                return nameMatches && valMatches && domMatches
                            })
                        else { return false }
                        await handler.cookieStore.deleteCookie(cookie)
                        return true
                    } else if nameLen == -1 {
                        await handler.webView.configuration.websiteDataStore.clearRecords()
                        return true
                    }
                    return false
                }

                switch res {
                    case .success(let ok):
                        return [
                            .i32(UInt32(bitPattern: ok ? JSResult.success.rawValue : JSResult.missingCookie.rawValue))
                        ]
                    case .failure:
                        return [.i32(UInt32(bitPattern: JSResult.invalidHandler.rawValue))]
                }
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

private final class MainActorResultBox<T>: @unchecked Sendable {
    var result: Result<T, any Error & Sendable>?
}
