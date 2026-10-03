import Foundation

/// HTTP cookie representation exchanged between WebKit cookie stores and WebAssembly extensions.
public struct Cookie: Sendable, Codable, Equatable {
    public let name: String
    public let value: String
    public let expiresDate: Date?
    public let domain: String
    public let path: String
    public let isSecure: Bool
    public let isHTTPOnly: Bool

    public init(
        name: String,
        value: String,
        expiresDate: Date? = nil,
        domain: String = "",
        path: String = "/",
        isSecure: Bool = false,
        isHTTPOnly: Bool = false
    ) {
        self.name = name
        self.value = value
        self.expiresDate = expiresDate
        self.domain = domain
        self.path = path
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
    }

    public init(_ httpCookie: HTTPCookie) {
        self.name = httpCookie.name
        self.value = httpCookie.value
        self.expiresDate = httpCookie.expiresDate
        self.domain = httpCookie.domain
        self.path = httpCookie.path
        self.isSecure = httpCookie.isSecure
        self.isHTTPOnly = httpCookie.isHTTPOnly
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case value
        case expiresDate
        case domain
        case path
        case isSecure
        case isHTTPOnly
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.value = try container.decode(String.self, forKey: .value)
        if let timestamp = try container.decodeIfPresent(Int64.self, forKey: .expiresDate) {
            self.expiresDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else {
            self.expiresDate = nil
        }
        self.domain = try container.decode(String.self, forKey: .domain)
        self.path = try container.decode(String.self, forKey: .path)
        self.isSecure = try container.decode(Bool.self, forKey: .isSecure)
        self.isHTTPOnly = try container.decode(Bool.self, forKey: .isHTTPOnly)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
        let epochSeconds = expiresDate.map { Int64($0.timeIntervalSince1970) }
        try container.encodeIfPresent(epochSeconds, forKey: .expiresDate)
        try container.encode(domain, forKey: .domain)
        try container.encode(path, forKey: .path)
        try container.encode(isSecure, forKey: .isSecure)
        try container.encode(isHTTPOnly, forKey: .isHTTPOnly)
    }
}
