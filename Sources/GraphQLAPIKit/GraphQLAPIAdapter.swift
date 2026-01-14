import Apollo
import ApolloAPI
import Foundation

public protocol GraphQLAPIAdapterProtocol: AnyObject, Sendable {
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
}
