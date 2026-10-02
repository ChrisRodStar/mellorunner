import Foundation

/// Errors encountered while encoding or decoding Postcard binary wire data.
public enum PostcardError: Error, Equatable, Sendable {
    /// Attempted to read past the end of the available input buffer.
    case unexpectedEndOfInput

    /// A variable-length integer has an invalid encoding or exceeds length limits.
    case invalidVarInt(String)

    /// A decoded integer exceeds the maximum representable range of the target type.
    case varIntOverflow(String)

    /// Encountered a boolean discriminant byte that is neither 0x00 nor 0x01.
    case invalidBooleanDiscriminant(UInt8)

    /// Encountered an option discriminant byte that is neither 0x00 (None) nor 0x01 (Some).
    case invalidOptionDiscriminant(UInt8)

    /// String payload is not valid UTF-8.
    case invalidUTF8

    /// A collection or string length exceeds the configured security limit.
    case excessiveLength(requested: Int, maximum: Int)

    /// Trailing unconsumed bytes remained when complete consumption was required.
    case trailingBytes(remaining: Int)
}
