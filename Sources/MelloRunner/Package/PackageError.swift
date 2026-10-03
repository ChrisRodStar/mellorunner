import Foundation

/// Errors that can occur when reading, parsing, or validating a source extension package.
public enum PackageError: Error, Sendable, CustomStringConvertible {
    /// The specified file URL or path is invalid.
    case invalidURL(String)

    /// The archive is not a valid ZIP or `.aix` package file.
    case invalidArchive(String)

    /// A required package member (e.g. `main.wasm` or `source.json`) is missing.
    case missingRequiredFile(String)

    /// Failed to decompress a compressed file payload.
    case decompressionFailed(String)

    /// The `source.json` manifest could not be decoded.
    case manifestDecodingFailed(String)

    public var description: String {
        switch self {
            case .invalidURL(let path):
                "Invalid package URL: \(path)"
            case .invalidArchive(let reason):
                "Invalid archive: \(reason)"
            case .missingRequiredFile(let file):
                "Package is missing required file: \(file)"
            case .decompressionFailed(let file):
                "Failed to decompress file: \(file)"
            case .manifestDecodingFailed(let reason):
                "Failed to decode source.json manifest: \(reason)"
        }
    }
}
