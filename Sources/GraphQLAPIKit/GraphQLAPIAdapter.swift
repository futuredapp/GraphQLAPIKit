import Apollo
import ApolloAPI
import Foundation

public protocol GraphQLAPIAdapterProtocol: AnyObject, Sendable {

    // MARK: - Single Response

    /// Fetches a query from the server.
    /// Apollo cache is ignored.
    ///
    /// - Parameters:
    ///   - query: The query to fetch.
    ///   - configuration: Additional request configuration.
    /// - Returns: The query data on success.
    /// - Throws: `GraphQLAPIAdapterError` on failure.
    func fetch<Query: GraphQLQuery>(
        query: Query,
        configuration: GraphQLRequestConfiguration
    ) async throws -> Query.Data where Query.ResponseFormat == SingleResponseFormat

    /// Performs a mutation by sending it to the server.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to perform.
    ///   - configuration: Additional request configuration.
    /// - Returns: The mutation data on success.
    /// - Throws: `GraphQLAPIAdapterError` on failure.
    func perform<Mutation: GraphQLMutation>(
        mutation: Mutation,
        configuration: GraphQLRequestConfiguration
    ) async throws -> Mutation.Data where Mutation.ResponseFormat == SingleResponseFormat

    // MARK: - Incremental/Deferred Response

    /// Fetches a query with `@defer` directive from the server.
    /// Returns a stream that emits data progressively as deferred fragments arrive.
    ///
    /// - Parameters:
    ///   - query: The query to fetch (must use `@defer` directive).
    ///   - configuration: Additional request configuration.
    /// - Returns: An async stream of query data, emitting updates as deferred data arrives.
    /// - Throws: `GraphQLAPIAdapterError` on stream creation failure.
    func fetch<Query: GraphQLQuery>(
        query: Query,
        configuration: GraphQLRequestConfiguration
    ) throws -> AsyncThrowingStream<Query.Data, Error> where Query.ResponseFormat == IncrementalDeferredResponseFormat

    /// Performs a mutation with `@defer` directive.
    /// Returns a stream that emits data progressively as deferred fragments arrive.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to perform (must use `@defer` directive).
    ///   - configuration: Additional request configuration.
    /// - Returns: An async stream of mutation data, emitting updates as deferred data arrives.
    /// - Throws: `GraphQLAPIAdapterError` on stream creation failure.
    func perform<Mutation: GraphQLMutation>(
        mutation: Mutation,
        configuration: GraphQLRequestConfiguration
    ) throws -> AsyncThrowingStream<Mutation.Data, Error> where Mutation.ResponseFormat == IncrementalDeferredResponseFormat

    // MARK: - Subscriptions

    /// Subscribes to a GraphQL subscription.
    /// Returns a stream that emits events as they arrive from the server.
    ///
    /// - Parameters:
    ///   - subscription: The subscription to subscribe to.
    ///   - configuration: Additional subscription configuration.
    /// - Returns: An async stream of subscription data, emitting events as they arrive.
    /// - Throws: `GraphQLAPIAdapterError` on stream creation failure.
    func subscribe<Subscription: GraphQLSubscription>(
        subscription: Subscription,
        configuration: GraphQLSubscriptionConfiguration
    ) async throws -> AsyncThrowingStream<Subscription.Data, Error>
}

public final class GraphQLAPIAdapter: GraphQLAPIAdapterProtocol, Sendable {
    private let apollo: ApolloClient

    /// Creates a new GraphQL API adapter with the given configuration.
    ///
    /// - Parameter configuration: The configuration for the GraphQL client.
    public init(configuration: GraphQLAPIConfiguration) {
        let urlSession = URLSession(configuration: configuration.urlSessionConfiguration)
        let store = ApolloStore(cache: InMemoryNormalizedCache())

        let provider = NetworkInterceptorProvider(
            defaultHeaders: configuration.defaultHeaders,
            networkObservers: configuration.networkObservers
        )

        let networkTransport = RequestChainNetworkTransport(
            urlSession: urlSession,
            interceptorProvider: provider,
            store: store,
            endpointURL: configuration.url
        )

        self.apollo = ApolloClient(
            networkTransport: networkTransport,
            store: store
        )
    }

    public func fetch<Query: GraphQLQuery>(
        query: Query,
        configuration: GraphQLRequestConfiguration = GraphQLRequestConfiguration()
    ) async throws -> Query.Data where Query.ResponseFormat == SingleResponseFormat {
        // Use networkOnly to bypass cache, with writeResultsToCache: false
        let config = RequestConfiguration(writeResultsToCache: false)

        let response = try await apollo.fetch(
            query: query,
            cachePolicy: .networkOnly,
            requestConfiguration: config
        )

        if let errors = response.errors, !errors.isEmpty {
            throw GraphQLAPIAdapterError(error: ApolloError(errors: errors))
        }

        guard let data = response.data else {
            assertionFailure("No data received")
            throw GraphQLAPIAdapterError.unhandled(
                NSError(
                    domain: "GraphQLAPIKit",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No data received"]
                )
            )
        }

        return data
    }

    public func perform<Mutation: GraphQLMutation>(
        mutation: Mutation,
        configuration: GraphQLRequestConfiguration = GraphQLRequestConfiguration()
    ) async throws -> Mutation.Data where Mutation.ResponseFormat == SingleResponseFormat {
        // Mutations don't write to cache
        let config = RequestConfiguration(writeResultsToCache: false)

        let response = try await apollo.perform(
            mutation: mutation,
            requestConfiguration: config
        )

        if let errors = response.errors, !errors.isEmpty {
            throw GraphQLAPIAdapterError(error: ApolloError(errors: errors))
        }

        guard let data = response.data else {
            assertionFailure("No data received")
            throw GraphQLAPIAdapterError.unhandled(
                NSError(
                    domain: "GraphQLAPIKit",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No data received"]
                )
            )
        }

        return data
    }

    // MARK: - Incremental/Deferred Response

    public func fetch<Query: GraphQLQuery>(
        query: Query,
        configuration: GraphQLRequestConfiguration = GraphQLRequestConfiguration()
    ) throws -> AsyncThrowingStream<Query.Data, Error> where Query.ResponseFormat == IncrementalDeferredResponseFormat {
        let config = RequestConfiguration(writeResultsToCache: false)

        let apolloStream = try apollo.fetch(
            query: query,
            cachePolicy: .networkOnly,
            requestConfiguration: config
        )

        return transformStream(apolloStream)
    }

    public func perform<Mutation: GraphQLMutation>(
        mutation: Mutation,
        configuration: GraphQLRequestConfiguration = GraphQLRequestConfiguration()
    ) throws -> AsyncThrowingStream<Mutation.Data, Error> where Mutation.ResponseFormat == IncrementalDeferredResponseFormat {
        let config = RequestConfiguration(writeResultsToCache: false)

        let apolloStream = try apollo.perform(
            mutation: mutation,
            requestConfiguration: config
        )

        return transformStream(apolloStream)
    }

    // MARK: - Subscriptions

    public func subscribe<Subscription: GraphQLSubscription>(
        subscription: Subscription,
        configuration: GraphQLSubscriptionConfiguration = GraphQLSubscriptionConfiguration()
    ) async throws -> AsyncThrowingStream<Subscription.Data, Error> {
        let config = RequestConfiguration(writeResultsToCache: false)

        let apolloStream = try await apollo.subscribe(
            subscription: subscription,
            requestConfiguration: config
        )

        return transformStream(apolloStream)
    }

    // MARK: - Private Helpers

    /// Transforms an Apollo response stream into a data stream with error mapping.
    private func transformStream<Operation: GraphQLOperation>(
        _ apolloStream: AsyncThrowingStream<GraphQLResponse<Operation>, Error>
    ) -> AsyncThrowingStream<Operation.Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await response in apolloStream {
                        // Check for GraphQL errors
                        if let errors = response.errors, !errors.isEmpty {
                            continuation.finish(throwing: GraphQLAPIAdapterError(error: ApolloError(errors: errors)))
                            return
                        }

                        // Yield data if present (may be partial for @defer)
                        if let data = response.data {
                            continuation.yield(data)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: GraphQLAPIAdapterError(error: error))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
