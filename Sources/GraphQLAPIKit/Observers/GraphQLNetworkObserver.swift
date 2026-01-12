import Foundation

/// Protocol for observing GraphQL network request lifecycle events.
///
/// Implement this protocol to add logging, analytics, or request tracking to GraphQL operations.
/// Observers are passive - they cannot modify requests or responses, only observe them.
///
/// This protocol matches FTAPIKit's `NetworkObserver` pattern exactly, using `URLRequest` directly.
///
/// ## Context Lifecycle
/// The `Context` associated type allows passing correlation data (request ID, start time, etc.)
/// through the request lifecycle:
/// 1. `willSendRequest` is called before the request starts and returns a `Context` value
/// 2. `didReceiveResponse` is always called with the raw HTTP response data (useful for debugging)
/// 3. `didFail` is called additionally if the request fails
/// 4. If the observer is deallocated before the request completes, the context is discarded
///    and no completion callback is invoked
///
public protocol GraphQLNetworkObserver: AnyObject, Sendable {
    associatedtype Context: Sendable

    /// Called immediately before a request is sent.
    /// - Parameter request: The URLRequest about to be sent
    /// - Returns: Context to be passed to `didReceiveResponse` and optionally `didFail`
    func willSendRequest(_ request: URLRequest) -> Context

    /// Called when a response is received from the server.
    ///
    /// This is always called with the raw response data, even if processing subsequently fails.
    /// This allows observers to inspect the actual response for debugging purposes.
    /// - Parameters:
    ///   - request: The original request
    ///   - response: The URL response (may be nil if network error occurred before response)
    ///   - data: Response body data, if any
    ///   - context: Value returned from `willSendRequest`
    func didReceiveResponse(for request: URLRequest, response: URLResponse?, data: Data?, context: Context)

    /// Called when a request fails with an error.
    ///
    /// Called after `didReceiveResponse` if processing determines the request failed.
    /// - Parameters:
    ///   - request: The original request
    ///   - error: The error that occurred
    ///   - context: Value returned from `willSendRequest`
    func didFail(request: URLRequest, error: Error, context: Context)
}
