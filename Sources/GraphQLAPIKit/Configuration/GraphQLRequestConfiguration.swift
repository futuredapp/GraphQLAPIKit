import Foundation

/// Base protocol for GraphQL operation configurations.
///
/// Defines common options shared across all GraphQL operations (queries, mutations, subscriptions).
public protocol GraphQLOperationConfiguration: Sendable {
    /// Additional headers to add to the request.
    var headers: RequestHeaders? { get }
}

/// Configuration for GraphQL queries and mutations.
///
/// Use this struct to customize request-specific options like additional headers.
public struct GraphQLRequestConfiguration: GraphQLOperationConfiguration {
    /// Additional headers to add to the request.
    public let headers: RequestHeaders?

    /// Creates a new request configuration.
    ///
    /// - Parameter headers: Additional headers to add to the request. Defaults to `nil`.
    public init(headers: RequestHeaders? = nil) {
        self.headers = headers
    }
}

/// Configuration for GraphQL subscriptions.
///
/// Use this struct to customize subscription-specific options.
/// Subscriptions are long-lived connections that may require different configuration than standard requests.
public struct GraphQLSubscriptionConfiguration: GraphQLOperationConfiguration {
    /// Additional headers to add to the subscription request.
    public let headers: RequestHeaders?

    /// Creates a new subscription configuration.
    ///
    /// - Parameter headers: Additional headers to add to the request. Defaults to `nil`.
    public init(headers: RequestHeaders? = nil) {
        self.headers = headers
    }
}
