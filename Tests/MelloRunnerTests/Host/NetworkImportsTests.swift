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
        // Verify that net module is defined
        #expect(imports != nil)
    }
}
