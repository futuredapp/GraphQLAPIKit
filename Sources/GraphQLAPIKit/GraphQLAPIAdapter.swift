import Apollo
import ApolloAPI
import Foundation

public protocol GraphQLAPIAdapterProtocol: AnyObject, Sendable {
    /// Fetches a query from the server.
    /// Apollo cache is ignored.
    ///
    /// - Parameters:
    ///   - query: The query to fetch.
    ///   - headers: [optional] Additional headers to add to the request. Should default to `nil`.
    /// - Returns: The query data on success.
    /// - Throws: `GraphQLAPIAdapterError` on failure.
    func fetch<Query: GraphQLQuery>(
        query: Query,
        headers: RequestHeaders?
    ) async throws -> Query.Data where Query.ResponseFormat == SingleResponseFormat

    /// Performs a mutation by sending it to the server.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to perform.
    ///   - headers: [optional] Additional headers to add to the request. Should default to `nil`.
    /// - Returns: The mutation data on success.
    /// - Throws: `GraphQLAPIAdapterError` on failure.
    func perform<Mutation: GraphQLMutation>(
        mutation: Mutation,
        headers: RequestHeaders?
    ) async throws -> Mutation.Data where Mutation.ResponseFormat == SingleResponseFormat
}

public final class GraphQLAPIAdapter: GraphQLAPIAdapterProtocol, Sendable {
    private let apollo: ApolloClient

    /// Creates a new GraphQL API adapter with variadic network observers.
    ///
    /// - Parameters:
    ///   - url: The GraphQL endpoint URL.
    ///   - urlSessionConfiguration: URL session configuration. Defaults to `.default`.
    ///   - defaultHeaders: Headers to include in every request. Defaults to empty.
    ///   - networkObservers: Zero or more network observers for monitoring requests.
    public init<each Observer: GraphQLNetworkObserver>(
        url: URL,
        urlSessionConfiguration: URLSessionConfiguration = .default,
        defaultHeaders: [String: String] = [:],
        networkObservers: repeat each Observer
    ) {
        var observers: [any GraphQLNetworkObserver] = []
        repeat observers.append(each networkObservers)

        let urlSession = URLSession(configuration: urlSessionConfiguration)
        let store = ApolloStore(cache: InMemoryNormalizedCache())

        let provider = NetworkInterceptorProvider(
            defaultHeaders: defaultHeaders,
            networkObservers: observers
        )

        let networkTransport = RequestChainNetworkTransport(
            urlSession: urlSession,
            interceptorProvider: provider,
            store: store,
            endpointURL: url
        )

        self.apollo = ApolloClient(
            networkTransport: networkTransport,
            store: store
        )
    }

    public func fetch<Query: GraphQLQuery>(
        query: Query,
        headers: RequestHeaders? = nil
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
        headers: RequestHeaders? = nil
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
