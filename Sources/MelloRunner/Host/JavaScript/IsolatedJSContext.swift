import Foundation
import JavaScriptCore

/// Thread-confined actor managing an isolated JavaScriptCore context for secure evaluation of untrusted guest scripts.
public actor IsolatedJSContext {
    private let context: JSContext

    public init(exceptionHandler: (@Sendable (String) -> Void)? = nil) {
        let ctx = JSContext() ?? JSContext()!
        if let exceptionHandler {
            ctx.exceptionHandler = { _, exception in
                exceptionHandler(exception?.toString() ?? "Unknown JavaScript exception")
            }
        }
        self.context = ctx
    }

    /// Synchronously evaluates a JavaScript expression within this isolated context and returns its string representation.
    public func evaluateScript(_ script: String) -> String? {
        context.evaluateScript(script)?.toString()
    }

    /// Asynchronously evaluates a JavaScript expression or Promise and returns the resolved string result.
    public func evaluateAsyncScript(_ script: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let onResolve: @convention(block) (JSValue) -> Void = { value in
                continuation.resume(returning: value.toString())
            }

            let onReject: @convention(block) (JSValue) -> Void = { error in
                let msg = error.toString() ?? "JavaScript Promise rejected"
                continuation.resume(
                    throwing: NSError(
                        domain: "IsolatedJSContext",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: msg]
                    )
                )
            }

            context.setObject(onResolve, forKeyedSubscript: "__resolve" as NSString)
            context.setObject(onReject, forKeyedSubscript: "__reject" as NSString)

            let wrappedScript = """
                (async () => {
                    try {
                        let result = await (\(script));
                        __resolve(result);
                    } catch (err) {
                        __reject(err ? (err.message || String(err)) : "Error");
                    }
                })();
                """

            context.evaluateScript(wrappedScript)
        }
    }

    /// Looks up a global property on the context by key name.
    public func objectForKeyedSubscript(_ key: String) -> String? {
        context.objectForKeyedSubscript(key)?.toString()
    }
}
