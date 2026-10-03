import CryptoKit
import Foundation
import WebKit

/// Manages an isolated `WKWebView` instance, its content rule lists, script injection, and cookie store for an extension.
@MainActor
public final class WebKitHandler: NSObject, @unchecked Sendable {
    public let webView: WKWebView

    private let loadedSemaphore = DispatchSemaphore(value: 0)
    private var continuations: [String: CheckedContinuation<Any?, Error>] = [:]
    private var addedAsyncEvalHandler = false

    private static let asyncEvalHandlerName = "asyncEval"

    public var cookieStore: WKHTTPCookieStore {
        webView.configuration.websiteDataStore.httpCookieStore
    }

    public init(id: String) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .forSource(key: id)
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
    }

    public nonisolated func waitForLoad() {
        loadedSemaphore.wait()
    }

    public func setRuleList(_ json: String) async throws {
        let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "RuleList",
            encodedContentRuleList: json
        )
        guard let ruleList else { return }
        webView.configuration.userContentController.add(ruleList)
    }

    public func evaluateAsyncJavaScript(_ javaScriptString: String) async throws -> Any? {
        let callbackID = UUID().uuidString

        if !addedAsyncEvalHandler {
            webView.configuration.userContentController.add(self, name: Self.asyncEvalHandlerName)
            addedAsyncEvalHandler = true
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any?, Error>) in
            continuations[callbackID] = continuation

            let wrappedScript = """
                (async () => {
                    try {
                        const result = await (\(javaScriptString));
                        window.webkit.messageHandlers.\(Self.asyncEvalHandlerName).postMessage({
                            id: '\(callbackID)',
                            ok: true,
                            value: result ?? null
                        });
                    } catch (e) {
                        window.webkit.messageHandlers.\(Self.asyncEvalHandlerName).postMessage({
                            id: '\(callbackID)',
                            ok: false,
                            error: String(e?.message ?? e)
                        });
                    }
                })();
                """

            webView.evaluateJavaScript(wrappedScript) { _, error in
                if let error {
                    if let continuation = self.continuations.removeValue(forKey: callbackID) {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

extension WebKitHandler: WKNavigationDelegate {
    public func webView(_: WKWebView, didFinish _: WKNavigation) {
        loadedSemaphore.signal()
    }

    public func webView(_: WKWebView, didFail _: WKNavigation, withError _: Error) {
        loadedSemaphore.signal()
    }

    public func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation, withError _: Error) {
        loadedSemaphore.signal()
    }
}

extension WebKitHandler: WKScriptMessageHandler {
    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == Self.asyncEvalHandlerName,
            let body = message.body as? [String: Any],
            let id = body["id"] as? String,
            let ok = body["ok"] as? Bool,
            let continuation = continuations.removeValue(forKey: id)
        else {
            return
        }

        if ok {
            continuation.resume(returning: body["value"])
        } else {
            let errorMessage = body["error"] as? String ?? "JS evaluation failed"
            continuation.resume(
                throwing: NSError(
                    domain: "WebKitHandler",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
            )
        }
    }
}

// MARK: - WKWebsiteDataStore Extension

extension WKWebsiteDataStore {
    public static func forSource(key: String) -> WKWebsiteDataStore {
        if #available(iOS 17.0, macOS 14.0, *) {
            let id = UUID(sourceKey: key)
            return self.init(forIdentifier: id)
        } else {
            return Self.nonPersistent()
        }
    }

    public func clearRecords() async {
        await withCheckedContinuation { continuation in
            fetchDataRecords(ofTypes: Self.allWebsiteDataTypes()) { records in
                for record in records {
                    self.removeData(ofTypes: record.dataTypes, for: [record]) {}
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - Deterministic UUID from Key

extension UUID {
    public init(sourceKey: String) {
        let data = Data(sourceKey.utf8)
        var bytes = Array(Insecure.SHA1.hash(data: data).prefix(16))
        // RFC 4122 UUID version 5
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        self = bytes.withUnsafeBufferPointer { buffer in
            UUID(uuidString: NSUUID(uuidBytes: buffer.baseAddress!).uuidString)!
        }
    }
}
