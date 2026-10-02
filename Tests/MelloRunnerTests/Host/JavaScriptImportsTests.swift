import Foundation
import JavaScriptCore
import Testing
import WasmKit
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
        #expect(imports != nil)
    }
}
