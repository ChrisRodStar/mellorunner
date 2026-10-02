import Foundation

/// Protocol defining the asynchronous execution of HTTP requests for WebAssembly source extensions.
public protocol HTTPTransport: Sendable {
    /// Executes a given `URLRequest` asynchronously and returns the response payload and HTTP response.
    ///
    /// - Parameter request: The configured `URLRequest` to execute.
    /// - Returns: A tuple containing the received payload `Data` and the HTTP URL response.
    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
