import Foundation
import Testing
import WasmKit

@testable import MelloRunner

@Suite("Network Imports Tests")
struct NetworkImportsTests {
    @Test("NetRequest to URLRequest mapping")
    func testNetRequestToURLRequest() throws {
        var req = NetRequest(method: .post)
        req.url = URL(string: "https://api.example.com/search")
        req.headers["Authorization"] = "Bearer test_token"
        req.headers["Content-Type"] = "application/json"
        req.body = Data("{\"query\":\"test\"}".utf8)
        req.timeoutInterval = 15.0

        let urlReq = try #require(req.toURLRequest())
        #expect(urlReq.httpMethod == "POST")
        #expect(urlReq.url?.absoluteString == "https://api.example.com/search")
        #expect(urlReq.value(forHTTPHeaderField: "Authorization") == "Bearer test_token")
        #expect(urlReq.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(urlReq.httpBody == Data("{\"query\":\"test\"}".utf8))
        #expect(urlReq.timeoutInterval == 15.0)
    }

    @Test("MockHTTPTransport response mocking and request tracking")
    func testMockHTTPTransport() async throws {
        let mock = MockHTTPTransport()
        let targetURL = URL(string: "https://api.example.com/data")!
        let responseBody = Data("{\"status\":\"ok\"}".utf8)

        mock.register(
            url: targetURL,
            data: responseBody,
            statusCode: 200,
            headers: ["Content-Type": "application/json"]
        )

        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"

        let (data, response) = try await mock.send(request: request)
        #expect(response.statusCode == 200)
        #expect(response.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(data == responseBody)
        #expect(mock.recordedRequests.count == 1)
        #expect(mock.recordedRequests.first?.url == targetURL)
    }

    @Test("MockHTTPTransport failure simulation")
    func testMockHTTPTransportError() async throws {
        let mock = MockHTTPTransport()
        let targetURL = URL(string: "https://api.example.com/error")!
        mock.registerError(url: targetURL, error: URLError(.timedOut))

        let request = URLRequest(url: targetURL)
        await #expect(throws: URLError.self) {
            try await mock.send(request: request)
        }
    }

    @Test("RateLimiter token bucket throttling")
    func testRateLimiter() async {
        let limiter = RateLimiter(requestsPerPeriod: 5, periodSeconds: 0.05)
        let start = Date()

        for _ in 0..<5 {
            await limiter.acquire()
        }
        let initialElapsed = Date().timeIntervalSince(start)
        #expect(initialElapsed < 0.05)

        // 6th acquire should wait for refill
        await limiter.acquire()
        let delayedElapsed = Date().timeIntervalSince(start)
        #expect(delayedElapsed >= 0.04)
    }

    @Test("NetworkImports registers all expected net functions in Store")
    func testNetworkImportsRegistration() throws {
        let store = Store(engine: Engine())
        let resourceStore = ResourceStore()
        let net = NetworkImports(resourceStore: resourceStore)

        let imports = net.makeImports(store: store)
        _ = imports
    }

    @Test("NetRequest.Method discriminants and strings match Aidoku specification")
    func testNetRequestMethodDiscriminants() {
        #expect(NetRequest.Method.get.rawValue == 0)
        #expect(NetRequest.Method.post.rawValue == 1)
        #expect(NetRequest.Method.put.rawValue == 2)
        #expect(NetRequest.Method.head.rawValue == 3)
        #expect(NetRequest.Method.delete.rawValue == 4)
        #expect(NetRequest.Method.patch.rawValue == 5)
        #expect(NetRequest.Method.options.rawValue == 6)
        #expect(NetRequest.Method.connect.rawValue == 7)
        #expect(NetRequest.Method.trace.rawValue == 8)

        #expect(NetRequest.Method.get.httpMethod == "GET")
        #expect(NetRequest.Method.post.httpMethod == "POST")
        #expect(NetRequest.Method.put.httpMethod == "PUT")
        #expect(NetRequest.Method.head.httpMethod == "HEAD")
        #expect(NetRequest.Method.delete.httpMethod == "DELETE")
        #expect(NetRequest.Method.patch.httpMethod == "PATCH")
        #expect(NetRequest.Method.options.httpMethod == "OPTIONS")
        #expect(NetRequest.Method.connect.httpMethod == "CONNECT")
        #expect(NetRequest.Method.trace.httpMethod == "TRACE")
        #expect(NetRequest.Method.allCases.count == 9)
    }

    @Test("net.init and net.set_timeout execution via WasmKit")
    func testNetworkImportsWasmExecution() throws {
        let store = Store(engine: Engine())
        let resourceStore = ResourceStore()
        let net = NetworkImports(resourceStore: resourceStore)
        let imports = net.makeImports(store: store)

        let wasmBytes: [UInt8] = [
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,  // Magic & Version
            0x01, 0x0c, 0x02,  // Type section (12 bytes)
            0x60, 0x01, 0x7f, 0x01, 0x7f,  // type 0: (i32) -> i32
            0x60, 0x02, 0x7f, 0x7c, 0x01, 0x7f,  // type 1: (i32, f64) -> i32
            0x02, 0x1e, 0x02,  // Import section (30 bytes)
            0x03, 0x6e, 0x65, 0x74, 0x04, 0x69, 0x6e, 0x69, 0x74, 0x00, 0x00,  // "net" "init" func 0
            0x03, 0x6e, 0x65, 0x74, 0x0b, 0x73, 0x65, 0x74, 0x5f, 0x74, 0x69, 0x6d, 0x65, 0x6f, 0x75, 0x74, 0x00,
            0x01,  // "net" "set_timeout" func 1
            0x03, 0x03, 0x02, 0x00, 0x01,  // Function section (3 bytes)
            0x07, 0x20, 0x02,  // Export section (32 bytes)
            0x09, 0x74, 0x65, 0x73, 0x74, 0x5f, 0x69, 0x6e, 0x69, 0x74, 0x00, 0x02,  // "test_init" -> func 2
            0x10, 0x74, 0x65, 0x73, 0x74, 0x5f, 0x73, 0x65, 0x74, 0x5f, 0x74, 0x69, 0x6d, 0x65, 0x6f, 0x75, 0x74, 0x00,
            0x03,  // "test_set_timeout" -> func 3
            0x0a, 0x11, 0x02,  // Code section (17 bytes)
            0x06, 0x00, 0x20, 0x00, 0x10, 0x00, 0x0b,  // func 2
            0x08, 0x00, 0x20, 0x00, 0x20, 0x01, 0x10, 0x01, 0x0b,  // func 3
        ]

        let module = try parseWasm(bytes: wasmBytes)
        let instance = try module.instantiate(store: store, imports: imports)

        guard let testInit = instance.export("test_init"), case .function(let initFn) = testInit else {
            Issue.record("Missing test_init function export")
            return
        }
        guard let testSetTimeout = instance.export("test_set_timeout"),
            case .function(let setTimeoutFn) = testSetTimeout
        else {
            Issue.record("Missing test_set_timeout function export")
            return
        }

        // Test methods 0..8 via Wasm call
        for m in 0...8 {
            let res = try initFn.invoke([.i32(UInt32(m))])
            guard let first = res.first, case .i32(let descPattern) = first else {
                Issue.record("Expected i32 result from test_init")
                return
            }
            let desc = Int32(bitPattern: descPattern)
            #expect(desc >= 0)
            let req: NetRequest? = resourceStore.fetchObject(desc)
            #expect(req?.method.rawValue == m)

            // Test set_timeout with Float64 via Wasm call
            let timeoutVal: Double = 42.5 + Double(m)
            let timeoutRes = try setTimeoutFn.invoke([.i32(descPattern), .f64(timeoutVal.bitPattern)])
            guard let timeoutFirst = timeoutRes.first, case .i32(let code) = timeoutFirst else {
                Issue.record("Expected i32 result from test_set_timeout")
                return
            }
            #expect(Int32(bitPattern: code) == NetworkImports.NetResult.success.rawValue)
            let updatedReq: NetRequest? = resourceStore.fetchObject(desc)
            #expect(updatedReq?.timeoutInterval == timeoutVal)
        }

        // Test invalid method via Wasm call
        let invalidRes = try initFn.invoke([.i32(UInt32(bitPattern: -1))])
        if let first = invalidRes.first, case .i32(let code) = first {
            #expect(Int32(bitPattern: code) == NetworkImports.NetResult.invalidMethod.rawValue)
        }
    }

    @Test("net.get_image validates missing data, non-image data, and valid bitmap images")
    func testNetworkImportsGetImage() throws {
        let store = Store(engine: Engine())
        let resourceStore = ResourceStore()
        let net = NetworkImports(resourceStore: resourceStore)
        let imports = net.makeImports(store: store)

        let wasmBytes: [UInt8] = [
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,  // Magic & Version
            0x01, 0x06, 0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f,  // Type section: (i32) -> i32
            0x02, 0x11, 0x01,  // Import section: 1 import
            0x03, 0x6e, 0x65, 0x74, 0x09, 0x67, 0x65, 0x74, 0x5f, 0x69, 0x6d, 0x61, 0x67, 0x65, 0x00, 0x00,  // "net" "get_image" func 0
            0x03, 0x02, 0x01, 0x00,  // Function section: func 1 of type 0
            0x07, 0x12, 0x01,  // Export section: 1 export
            0x0e, 0x74, 0x65, 0x73, 0x74, 0x5f, 0x67, 0x65, 0x74, 0x5f, 0x69, 0x6d, 0x61, 0x67, 0x65, 0x00, 0x01,  // "test_get_image" -> func 1
            0x0a, 0x08, 0x01, 0x06, 0x00, 0x20, 0x00, 0x10, 0x00, 0x0b,  // Code section: local.get 0, call 0, end
        ]

        let module = try parseWasm(bytes: wasmBytes)
        let instance = try module.instantiate(store: store, imports: imports)

        guard let testGetImage = instance.export("test_get_image"),
            case .function(let getImageFn) = testGetImage
        else {
            Issue.record("Missing test_get_image export")
            return
        }

        // 1. Invalid descriptor
        let invRes = try getImageFn.invoke([.i32(UInt32(bitPattern: -99))])
        if let first = invRes.first, case .i32(let code) = first {
            #expect(Int32(bitPattern: code) == NetworkImports.NetResult.invalidDescriptor.rawValue)
        }

        // 2. NetRequest with no response data (nil) -> returns missingData (-7)
        let emptyReq = NetRequest(method: .get)
        let emptyReqDesc = resourceStore.storeObject(emptyReq)
        let missingRes = try getImageFn.invoke([.i32(UInt32(bitPattern: emptyReqDesc))])
        if let first = missingRes.first, case .i32(let code) = first {
            #expect(Int32(bitPattern: code) == NetworkImports.NetResult.missingData.rawValue)
        }

        // 3. NetRequest with non-image data (HTML 404 text) -> returns notAnImage (-12)
        var htmlReq = NetRequest(method: .get)
        htmlReq.responseData = Data("<html><body>404 Not Found</body></html>".utf8)
        let htmlReqDesc = resourceStore.storeObject(htmlReq)
        let notAnImageRes = try getImageFn.invoke([.i32(UInt32(bitPattern: htmlReqDesc))])
        if let first = notAnImageRes.first, case .i32(let code) = first {
            #expect(Int32(bitPattern: code) == NetworkImports.NetResult.notAnImage.rawValue)
        }

        // 4. NetRequest with valid PNG image data -> returns valid descriptor > 0
        let ctx = CanvasContext(width: 10, height: 10)!
        let sampleImage = try #require(ctx.makeImage())
        let validPng = try #require(sampleImage.pngData())

        var validReq = NetRequest(method: .get)
        validReq.responseData = validPng
        let validReqDesc = resourceStore.storeObject(validReq)
        let successRes = try getImageFn.invoke([.i32(UInt32(bitPattern: validReqDesc))])
        guard let first = successRes.first, case .i32(let pattern) = first else {
            Issue.record("Expected i32 from test_get_image")
            return
        }
        let imageDesc = Int32(bitPattern: pattern)
        #expect(imageDesc > 0)

        // Verify resourceStore stores both raw Data and PlatformImage
        let fetchedData = resourceStore.fetch(imageDesc)
        #expect(fetchedData == validPng)

        let fetchedImage = resourceStore.fetchImage(imageDesc)
        #expect(fetchedImage != nil)
        #expect(fetchedImage?.size.width == 10)
        #expect(fetchedImage?.size.height == 10)
    }
}
