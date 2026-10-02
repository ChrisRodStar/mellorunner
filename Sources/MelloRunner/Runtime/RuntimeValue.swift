import Foundation

/// Engine-neutral representation of WebAssembly primitive values.
public enum RuntimeValue: Equatable, Sendable, CustomStringConvertible {
    case i32(Int32)
    case i64(Int64)
    case f32(Float)
    case f64(Double)

    public var description: String {
        switch self {
            case .i32(let value): "i32(\(value))"
            case .i64(let value): "i64(\(value))"
            case .f32(let value): "f32(\(value))"
            case .f64(let value): "f64(\(value))"
        }
    }

    public var i32Value: Int32? {
        guard case .i32(let val) = self else { return nil }
        return val
    }

    public var i64Value: Int64? {
        guard case .i64(let val) = self else { return nil }
        return val
    }

    public var f32Value: Float? {
        guard case .f32(let val) = self else { return nil }
        return val
    }

    public var f64Value: Double? {
        guard case .f64(let val) = self else { return nil }
        return val
    }
}
