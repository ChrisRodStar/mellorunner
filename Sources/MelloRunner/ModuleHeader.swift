import Foundation

public enum ModuleInspectionError: Error, Equatable, Sendable {
    case invalidByteLimit
    case moduleTooLarge
    case truncatedHeader
    case invalidMagic
    case unsupportedVersion(UInt32)
}

/// Header inspection only. This does not validate sections or execute WebAssembly.
public struct ModuleHeader: Equatable, Sendable, Codable {
    public let binaryVersion: UInt32
    public let byteCount: Int

    public init(data: Data, maximumBytes: Int = 64 * 1024 * 1024) throws {
        guard maximumBytes >= 8 else { throw ModuleInspectionError.invalidByteLimit }
        guard data.count <= maximumBytes else { throw ModuleInspectionError.moduleTooLarge }
        guard data.count >= 8 else { throw ModuleInspectionError.truncatedHeader }
        let header = Array(data.prefix(8))
        guard header[0..<4].elementsEqual([0x00, 0x61, 0x73, 0x6d]) else {
            throw ModuleInspectionError.invalidMagic
        }
        let version = UInt32(header[4]) | UInt32(header[5]) << 8
            | UInt32(header[6]) << 16 | UInt32(header[7]) << 24
        guard version == 1 else { throw ModuleInspectionError.unsupportedVersion(version) }
        binaryVersion = version
        byteCount = data.count
    }
}
