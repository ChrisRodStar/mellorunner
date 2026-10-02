import Foundation
import os

/// In-memory mock `HTTPTransport` allowing deterministic test simulations and offline execution.
public final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    public typealias Handler = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    private let state = OSAllocatedUnfairLock(
        initialState: [String: Result<(Data, HTTPURLResponse), any Error & Sendable>]())
    private let recorded = OSAllocatedUnfairLock(initialState: [URLRequest]())
    public var defaultHandler: Handler?

    public init(defaultHandler: Handler? = nil) {
        self.defaultHandler = defaultHandler
    }

    /// List of requests that have been executed through this mock transport.
    public var recordedRequests: [URLRequest] {
        recorded.withLock { $0 }
    }

    /// Registers a canned response for a specific URL string.
    public func register(
        url: URL,
        data: Data = Data(),
        statusCode: Int = 200,
        headers: [String: String] = [:]
    ) {
        guard
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )
        else { return }

        state.withLock { dict in
            dict[url.absoluteString] = .success((data, response))
        }
    }

    /// Registers an error simulation for a specific URL string.
    public func registerError(url: URL, error: any Error & Sendable) {
        state.withLock { dict in
            dict[url.absoluteString] = .failure(error)
        }
    }

    /// Removes a previously registered mock response.
    public func unregister(url: URL) {
        _ = state.withLock { dict in
            dict.removeValue(forKey: url.absoluteString)
        }
    }

    /// Clears all registered mock responses and recorded requests.
    public func clear() {
        state.withLock { dict in
            dict.removeAll(keepingCapacity: true)
        }
        recorded.withLock { list in
            list.removeAll(keepingCapacity: true)
        }
    }

    public func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recorded.withLock { list in
            list.append(request)
        }

        guard let url = request.url else {
            throw URLError(.badURL)
        }

        if let entry = state.withLock({ $0[url.absoluteString] }) {
            switch entry {
                case .success(let payload):
                    return payload
                case .failure(let error):
                    throw error
            }
        }

        if let defaultHandler {
            return try await defaultHandler(request)
        }
        throw URLError(.cannotFindHost)
    }
}
