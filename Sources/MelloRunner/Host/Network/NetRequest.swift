import Foundation

/// Internal model tracking an in-flight or completed guest HTTP request lifecycle.
public struct NetRequest: Sendable {
    public enum Method: Int, Sendable, Codable, CaseIterable {
        case get = 0
        case post = 1
        case put = 2
        case head = 3
        case delete = 4
        case patch = 5
        case options = 6
        case connect = 7
        case trace = 8

        public var httpMethod: String {
            switch self {
                case .get: "GET"
                case .post: "POST"
                case .put: "PUT"
                case .head: "HEAD"
                case .delete: "DELETE"
                case .patch: "PATCH"
                case .options: "OPTIONS"
                case .connect: "CONNECT"
                case .trace: "TRACE"
            }
        }

        public var string: String {
            httpMethod
        }
    }

    public var method: Method
    public var url: URL?
    public var headers: [String: String] = [:]
    public var body: Data?
    public var timeoutInterval: TimeInterval = 30.0

    public var response: HTTPURLResponse?
    public var responseData: Data?
    public var responseError: (any Error & Sendable)?

    public init(method: Method = .get) {
        self.method = method
    }

    public func toURLRequest() -> URLRequest? {
        guard let url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.httpMethod
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
        request.httpBody = body
        return request
    }
}
