import Foundation

/// Errors encountered during WebAssembly module parsing, instantiation, and invocation.
public enum RuntimeError: Error, Equatable, Sendable {
    /// The binary does not contain a valid WebAssembly module or violates structure rules.
    case invalidModule(String)
    /// An exported symbol with the given name was not found in the module.
    case exportNotFound(String)
    /// The exported symbol exists but is not an invocable function.
    case exportNotAFunction(String)
    /// The function returned results that did not match the expected count or type.
    case exportResultMismatch(expected: String, actual: String)
    /// A WebAssembly trap or runtime abort occurred during execution.
    case trap(String)
    /// An invocation is already active on an exclusive execution session.
    case invocationBusy
    /// A memory or fuel limit was exceeded.
    case resourceLimitExceeded(String)
    /// The execution session has already been closed.
    case instanceClosed
}
