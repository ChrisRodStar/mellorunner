import Foundation

/// Errors that occur at the host-guest bridge boundary.
public enum BridgeError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The guest function is unimplemented (-2).
    case unimplemented
    /// A network error occurred in the guest (-3).
    case networkError
    /// An HTML parsing error occurred in the guest (-4).
    case htmlError
    /// A JavaScript execution error occurred in the guest (-5).
    case jsError
    /// A canvas/image processing error occurred in the guest (-6).
    case canvasError
    /// A UTF-8 decoding error occurred in the guest (-7).
    case utf8Error
    /// A JSON parsing error occurred in the guest (-8).
    case jsonParseError
    /// A Postcard deserialization error occurred in the guest (-9).
    case deserializeError
    /// The guest explicitly returned an error message string (encoded with length UInt32.max).
    case guestError(String)
    /// An unrecognized negative error code was returned by the guest.
    case unknownGuestErrorCode(Int32)
    /// The guest returned an invalid or out-of-bounds pointer into linear memory.
    case invalidResultPointer(Int32)
    /// The guest memory header at the result pointer was corrupted or smaller than the 8-byte minimum.
    case corruptedResultHeader(String)
    /// The guest function returned no result pointer when one was expected.
    case missingResult
    /// The requested resource descriptor handle was not found in the resource store.
    case invalidDescriptor(Int32)

    public var description: String {
        switch self {
        case .unimplemented:
            return "Guest feature or function is unimplemented (-2)"
        case .networkError:
            return "Guest encountered a network error (-3)"
        case .htmlError:
            return "Guest encountered an HTML parsing error (-4)"
        case .jsError:
            return "Guest encountered a JavaScript evaluation error (-5)"
        case .canvasError:
            return "Guest encountered an image canvas error (-6)"
        case .utf8Error:
            return "Guest encountered a UTF-8 encoding error (-7)"
        case .jsonParseError:
            return "Guest encountered a JSON parse error (-8)"
        case .deserializeError:
            return "Guest encountered a Postcard deserialization error (-9)"
        case .guestError(let message):
            return "Guest error: \(message)"
        case .unknownGuestErrorCode(let code):
            return "Guest returned unknown error code: \(code)"
        case .invalidResultPointer(let ptr):
            return "Invalid guest memory pointer: \(ptr)"
        case .corruptedResultHeader(let details):
            return "Corrupted guest result header: \(details)"
        case .missingResult:
            return "Guest returned no result"
        case .invalidDescriptor(let handle):
            return "Invalid resource descriptor handle: \(handle)"
        }
    }
}
