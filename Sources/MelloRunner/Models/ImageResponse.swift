import Foundation

/// HTTP request details passed to image transformation hooks.
public struct ImageRequest: Sendable, Codable, Hashable {
    public var url: URL?
    public var headers: [String: String]

    public init(url: URL? = nil, headers: [String: String] = [:]) {
        self.url = url
        self.headers = headers
    }

    private enum CodingKeys: CodingKey {
        case key
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decodeIfPresent(String.self, forKey: .key).flatMap(URL.init)
        let count = try container.decode(UInt64.self, forKey: .key)
        var map = [String: String]()
        map.reserveCapacity(Int(count))
        for _ in 0..<count {
            let k = try container.decode(String.self, forKey: .key)
            let v = try container.decode(String.self, forKey: .key)
            map[k] = v
        }
        self.headers = map
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(url?.absoluteString, forKey: .key)
        try container.encode(UInt64(headers.count), forKey: .key)
        for (k, v) in headers.sorted(by: { $0.key < $1.key }) {
            try container.encode(k, forKey: .key)
            try container.encode(v, forKey: .key)
        }
    }
}

/// HTTP response details and payload descriptor passed to image transformation hooks.
public struct ImageResponse: Sendable, Codable, Hashable {
    public var code: UInt16
    public var headers: [String: String]
    public var request: ImageRequest
    public var image: Int32

    public init(code: Int, headers: [String: String] = [:], request: ImageRequest, image: Int32) {
        self.code = UInt16(code)
        self.headers = headers
        self.request = request
        self.image = image
    }

    private enum CodingKeys: CodingKey {
        case key
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(UInt16.self, forKey: .key)
        let count = try container.decode(UInt64.self, forKey: .key)
        var map = [String: String]()
        map.reserveCapacity(Int(count))
        for _ in 0..<count {
            let k = try container.decode(String.self, forKey: .key)
            let v = try container.decode(String.self, forKey: .key)
            map[k] = v
        }
        self.headers = map
        self.request = try container.decode(ImageRequest.self, forKey: .key)
        self.image = try container.decode(Int32.self, forKey: .key)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .key)
        try container.encode(UInt64(headers.count), forKey: .key)
        for (k, v) in headers.sorted(by: { $0.key < $1.key }) {
            try container.encode(k, forKey: .key)
            try container.encode(v, forKey: .key)
        }
        try container.encode(request, forKey: .key)
        try container.encode(image, forKey: .key)
    }
}
