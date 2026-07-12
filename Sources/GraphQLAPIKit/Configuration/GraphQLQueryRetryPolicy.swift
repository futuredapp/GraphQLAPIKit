import Foundation

/// Defines automatic retry behavior for single-response GraphQL queries.
public struct GraphQLQueryRetryPolicy: Sendable {
    /// Disables automatic retries.
    public static let none = GraphQLQueryRetryPolicy(
        maxRetryCount: 0,
        retryableURLErrorCodes: []
    )

    /// Immediately retries connection loss and timeout errors once.
    public static let transientNetworkFailures = GraphQLQueryRetryPolicy(
        maxRetryCount: 1,
        retryableURLErrorCodes: [
            .networkConnectionLost,
            .timedOut
        ]
    )

    /// Maximum number of retries after the initial request.
    public let maxRetryCount: UInt

    /// URL error codes that can trigger a retry.
    public let retryableURLErrorCodes: Set<URLError.Code>

    /// Creates a query retry policy.
    ///
    /// - Parameters:
    ///   - maxRetryCount: Maximum number of retries after the initial request.
    ///   - retryableURLErrorCodes: URL error codes that can trigger a retry.
    public init(
        maxRetryCount: UInt,
        retryableURLErrorCodes: Set<URLError.Code>
    ) {
        self.maxRetryCount = maxRetryCount
        self.retryableURLErrorCodes = retryableURLErrorCodes
    }

    func shouldRetry(error: Error) -> Bool {
        if let adapterError = error as? GraphQLAPIAdapterError {
            switch adapterError {
            case let .network(_, underlyingError),
                 let .connection(underlyingError),
                 let .unhandled(underlyingError):
                return shouldRetry(error: underlyingError)
            case .cancelled, .graphQl:
                return false
            }
        }

        let error = error as NSError
        return error.domain == NSURLErrorDomain &&
            retryableURLErrorCodes.contains(URLError.Code(rawValue: error.code))
    }
}
