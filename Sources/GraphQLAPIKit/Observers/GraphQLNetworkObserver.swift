import Apollo
import ApolloAPI
import Foundation

/// Context containing GraphQL operation metadata for observers.
///
/// This struct provides all relevant information about a GraphQL operation
/// that observers might need for logging, tracing, or analytics.
public struct GraphQLOperationContext: Sendable {
    /// Name of the GraphQL operation (e.g., "GetUser", "CreatePost")
    public let operationName: String

    /// Type of the operation: "query", "mutation", or "subscription"
    public let operationType: String

    /// The endpoint URL
    public let url: URL

    public init(operationName: String, operationType: String, url: URL) {
        self.operationName = operationName
        self.operationType = operationType
        self.url = url
    }
}

/// Protocol for observing GraphQL network request lifecycle events.
///
/// Implement this protocol to add logging, analytics, or request tracking to GraphQL operations.
/// Observers are passive - they cannot modify requests or responses, only observe them.
///
/// ## Context Lifecycle
/// The `Context` associated type allows passing correlation data (request ID, start time, etc.)
/// through the request lifecycle:
/// 1. `willSendRequest` is called before the operation starts and returns a `Context` value
/// 2. `didReceiveResponse` is always called with the raw HTTP response data (useful for debugging)
/// 3. `didFail` is called additionally if the operation fails
/// 4. If the observer is deallocated before the operation completes, the context is discarded
///    and no completion callback is invoked
///
/// ## Example
/// ```swift
/// final class LoggingObserver: GraphQLNetworkObserver {
///     struct Context: Sendable {
///         let requestId: String
///         let startTime: Date
///     }
///
///     func willSendRequest(_ context: GraphQLOperationContext) -> Context {
///         let requestId = UUID().uuidString
///         print("[\(requestId)] → \(context.operationType) \(context.operationName)")
///         return Context(requestId: requestId, startTime: Date())
///     }
///
///     func didReceiveResponse(
///         for context: GraphQLOperationContext,
///         response: HTTPURLResponse?,
///         data: Data?,
///         observerContext: Context
///     ) {
///         let duration = Date().timeIntervalSince(observerContext.startTime)
///         print("[\(observerContext.requestId)] ← \(response?.statusCode ?? 0) (\(duration)s)")
///     }
///
///     func didFail(for context: GraphQLOperationContext, error: Error, observerContext: Context) {
///         print("[\(observerContext.requestId)] ✗ \(error.localizedDescription)")
///     }
/// }
/// ```
public protocol GraphQLNetworkObserver: AnyObject, Sendable {
    associatedtype Context: Sendable

    /// Called immediately before a GraphQL operation is sent.
    /// - Parameter context: Information about the operation being sent
    /// - Returns: Context to be passed to `didReceiveResponse` and optionally `didFail`
    func willSendRequest(_ context: GraphQLOperationContext) -> Context

    /// Called when a response is received from the server.
    ///
    /// This is always called with the raw HTTP response data, even if processing subsequently fails.
    /// This allows observers to inspect the actual response for debugging purposes.
    /// - Parameters:
    ///   - context: Information about the original operation
    ///   - response: The HTTP response (may be nil if network error occurred before response)
    ///   - data: Response body data, if any
    ///   - observerContext: Value returned from `willSendRequest`
    func didReceiveResponse(
        for context: GraphQLOperationContext,
        response: HTTPURLResponse?,
        data: Data?,
        observerContext: Context
    )

    /// Called when an operation fails with an error.
    ///
    /// Called after `didReceiveResponse` if processing determines the operation failed.
    /// - Parameters:
    ///   - context: Information about the original operation
    ///   - error: The error that occurred
    ///   - observerContext: Value returned from `willSendRequest`
    func didFail(for context: GraphQLOperationContext, error: Error, observerContext: Context)
}

// MARK: - Internal Type Erasure

/// Internal struct that hides the specific observer type and its associated Context type.
/// This enables storing heterogeneous observers in an array.
struct GraphQLRequestToken: Sendable {
    let didReceiveResponse: @Sendable (HTTPURLResponse?, Data?) -> Void
    let didFail: @Sendable (Error) -> Void

    /// Creates a token that captures the observer and immediately calls `willSendRequest`.
    /// - Parameters:
    ///   - observer: The observer to wrap
    ///   - context: The operation context
    init<T: GraphQLNetworkObserver>(observer: T, context: GraphQLOperationContext) {
        // Generate the observer context immediately upon initialization
        let observerContext = observer.willSendRequest(context)

        // Capture the specific observer and context inside closures using weak reference
        self.didReceiveResponse = { [weak observer] response, data in
            observer?.didReceiveResponse(
                for: context,
                response: response,
                data: data,
                observerContext: observerContext
            )
        }

        self.didFail = { [weak observer] error in
            observer?.didFail(for: context, error: error, observerContext: observerContext)
        }
    }
}
