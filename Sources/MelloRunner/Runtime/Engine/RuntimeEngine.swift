import Foundation
import WasmKit

/// Wraps the WebAssembly execution engine while keeping engine-specific types internal.
public final class RuntimeEngine: Sendable {
    /// Shared runtime engine instance using default configuration.
    public static let shared = RuntimeEngine()

    let engine: Engine

    public init() {
        self.engine = Engine()
    }
}
