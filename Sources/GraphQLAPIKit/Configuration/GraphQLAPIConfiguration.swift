import Foundation

/// Configuration for initializing a GraphQL API adapter.
///
/// Use this struct to configure the GraphQL client with endpoint URL,
/// session configuration, default headers, and network observers.
public struct GraphQLAPIConfiguration: Sendable {
    /// The GraphQL endpoint URL.
    public let url: URL

    /// URL session configuration. Defaults to `.default`.
    public let urlSessionConfiguration: URLSessionConfiguration

    /// Headers to include in every request.
    public let defaultHeaders: [String: String]

    /// Network observers for monitoring requests (logging, analytics, etc.).
    public let networkObservers: [any GraphQLNetworkObserver]

    /// Retry policy for single-response GraphQL queries. Defaults to no retries.
    public let queryRetryPolicy: GraphQLQueryRetryPolicy

    /// Creates a new GraphQL API configuration.
    ///
    /// - Parameters:
    ///   - url: The GraphQL endpoint URL.
    ///   - urlSessionConfiguration: URL session configuration. Defaults to `.default`.
    ///   - defaultHeaders: Headers to include in every request. Defaults to empty.
    ///   - networkObservers: Network observers for monitoring requests. Defaults to empty.
    ///   - queryRetryPolicy: Retry policy for single-response queries. Defaults to no retries.
    public init(
        url: URL,
        urlSessionConfiguration: URLSessionConfiguration = .default,
        defaultHeaders: [String: String] = [:],
        networkObservers: [any GraphQLNetworkObserver] = [],
        queryRetryPolicy: GraphQLQueryRetryPolicy = .none
    ) {
        self.url = url
        self.urlSessionConfiguration = urlSessionConfiguration
        self.defaultHeaders = defaultHeaders
        self.networkObservers = networkObservers
        self.queryRetryPolicy = queryRetryPolicy
    }
}
