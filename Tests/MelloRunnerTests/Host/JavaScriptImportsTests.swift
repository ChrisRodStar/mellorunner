import Foundation
import JavaScriptCore
import Testing
import WasmKit
import WebKit
import os

@testable import MelloRunner

@Suite("JavaScript Imports Tests")
struct JavaScriptImportsTests {
    @Test("IsolatedJSContext evaluates synchronous expressions")
    func testSyncEvaluation() async {
        let context = IsolatedJSContext()
        let result = await context.evaluateScript("1 + 1")
        #expect(result == "2")

        let stringResult = await context.evaluateScript("'hello' + ' ' + 'world'")
        #expect(stringResult == "hello world")

        let jsonResult = await context.evaluateScript("JSON.stringify({ a: 1, b: 'two' })")
        #expect(jsonResult == "{\"a\":1,\"b\":\"two\"}")
    }

    @Test("IsolatedJSContext evaluates asynchronous Promises")
    func testAsyncEvaluation() async throws {
        let context = IsolatedJSContext()
        let result = try await context.evaluateAsyncScript("Promise.resolve(42 * 2)")
        #expect(result == "84")
    }

    @Test("IsolatedJSContext exception handling")
    func testExceptionHandler() async {
        let recordedException = OSAllocatedUnfairLock<String?>(initialState: nil)
        let context = IsolatedJSContext { exception in
            recordedException.withLock { $0 = exception }
        }

        _ = await context.evaluateScript("throw new Error('boom');")
        let message = recordedException.withLock { $0 }
        #expect(message?.contains("boom") == true)
    }

    @Test("Cookie model Codable round-trip")
    func testCookieCodable() throws {
        let testDate = Date(timeIntervalSince1970: 1_700_000_000)
        let cookie = Cookie(
            name: "session_id",
            value: "xyz123",
            expiresDate: testDate,
            domain: "example.com",
            path: "/",
            isSecure: true,
            isHTTPOnly: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(cookie)
        let decoded = try JSONDecoder().decode(Cookie.self, from: data)

        #expect(decoded.name == "session_id")
        #expect(decoded.value == "xyz123")
        #expect(decoded.domain == "example.com")
        #expect(decoded.path == "/")
        #expect(decoded.isSecure == true)
        #expect(decoded.isHTTPOnly == true)
        #expect(decoded.expiresDate?.timeIntervalSince1970 == 1_700_000_000)
    }

    @Test("JavaScriptImports registers js module in Store")
    func testJavaScriptImportsModuleRegistration() throws {
        let resourceStore = ResourceStore()
        let js = JavaScriptImports(resourceStore: resourceStore)

        let wasmStore = Store(engine: Engine())
        let imports = js.makeImports(store: wasmStore)
        _ = imports
    }

    @Test("WebKitHandler initialization and script evaluation on MainActor")
    @MainActor
    func testWebKitHandlerEvaluation() async throws {
        let handler = WebKitHandler(id: "test-source")
        let evalResult = try await handler.webView.evaluateJavaScript("10 + 20")
        #expect("\(evalResult ?? "")" == "30")

        let asyncResult = try await handler.evaluateAsyncJavaScript("Promise.resolve('async-val')")
        #expect("\(asyncResult ?? "")" == "async-val")
    }

    @Test("WebKitHandler cookie store management")
    @MainActor
    func testWebKitHandlerCookies() async throws {
        let handler = WebKitHandler(id: "cookie-test")
        let cookieProps: [HTTPCookiePropertyKey: Any] = [
            .name: "auth_token",
            .value: "secret123",
            .domain: "example.com",
            .path: "/",
        ]
        guard let httpCookie = HTTPCookie(properties: cookieProps) else {
            Issue.record("Failed to create HTTPCookie")
            return
        }

        await handler.cookieStore.setCookie(httpCookie)
        let allCookies = await handler.cookieStore.allCookies()
        let matched = allCookies.first(where: { $0.name == "auth_token" })
        #expect(matched?.value == "secret123")

        await handler.cookieStore.deleteCookie(httpCookie)
        let remainingCookies = await handler.cookieStore.allCookies()
        #expect(!remainingCookies.contains(where: { $0.name == "auth_token" }))
    }

    @Test("JavaScriptImports webview_create and eval via synthetic WasmKit module")
    func testWebViewWasmExecution() throws {
        let store = Store(engine: Engine())
        let resourceStore = ResourceStore()
        let js = JavaScriptImports(resourceStore: resourceStore, webViewNamespace: "wasm-test")
        let imports = js.makeImports(store: store)

        // Synthetic Wasm module calling js.webview_create() -> i32
        // Type 0: () -> i32
        // Import: "js" "webview_create" func 0
        // Export: "test_create" -> func 0
        let wasmBytes: [UInt8] = [
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,  // Magic & Version
            0x01, 0x05, 0x01,  // Type section (5 bytes)
            0x60, 0x00, 0x01, 0x7f,  // type 0: () -> i32
            0x02, 0x15, 0x01,  // Import section (21 bytes)
            0x02, 0x6a, 0x73,  // "js" (2 bytes)
            // "webview_create" (14 bytes)
            0x0e, 0x77, 0x65, 0x62, 0x76, 0x69, 0x65, 0x77, 0x5f, 0x63, 0x72, 0x65, 0x61, 0x74, 0x65,
            0x00, 0x00,  // func 0
            0x07, 0x0f, 0x01,  // Export section (15 bytes)
            0x0b, 0x74, 0x65, 0x73, 0x74, 0x5f, 0x63, 0x72, 0x65, 0x61, 0x74, 0x65,  // "test_create" (11 bytes)
            0x00, 0x00,  // func 0
        ]

        let module = try parseWasm(bytes: wasmBytes)
        let instance = try module.instantiate(store: store, imports: imports)

        guard let testCreateExport = instance.export("test_create"),
            case .function(let testCreate) = testCreateExport
        else {
            Issue.record("Missing test_create export")
            return
        }

        let res = try testCreate.invoke([])
        guard let first = res.first, case .i32(let descPattern) = first else {
            Issue.record("Expected i32 from test_create")
            return
        }

        let desc = Int32(bitPattern: descPattern)
        #expect(desc > 0)
        let handler: WebKitHandler? = resourceStore.fetchObject(desc)
        #expect(handler != nil)
    }
}
