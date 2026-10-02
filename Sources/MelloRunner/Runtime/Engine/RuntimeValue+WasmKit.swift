import Foundation
import WasmKit

extension RuntimeValue {
    init(_ value: Value) {
        switch value {
        case .i32(let u):
            self = .i32(Int32(bitPattern: u))
        case .i64(let u):
            self = .i64(Int64(bitPattern: u))
        case .f32(let u):
            self = .f32(Float(bitPattern: u))
        case .f64(let u):
            self = .f64(Double(bitPattern: u))
        default:
            // Fallback for non-numeric/reference values
            self = .i64(0)
        }
    }

    var wasmValue: Value {
        switch self {
        case .i32(let s):
            return .i32(UInt32(bitPattern: s))
        case .i64(let s):
            return .i64(UInt64(bitPattern: s))
        case .f32(let f):
            return .f32(f.bitPattern)
        case .f64(let d):
            return .f64(d.bitPattern)
        }
    }
}
