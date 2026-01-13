import Apollo
import ApolloAPI
import Foundation

public protocol GraphQLAPIAdapterProtocol: AnyObject {
    /// Fetches a query from the server
    /// Apollo cache is ignored.
    ///
    /// - Parameters:
    ///   - query: The query to fetch.
    ///   - queue: A dispatch queue on which the result handler will be called. Should default to the main queue.
    ///   - context: [optional] A context that is being passed through the request chain. Should default to `nil`.
    ///   - resultHandler: A closure that is called when query results are available or when an error occurs.
    /// - Returns: An object that can be used to cancel an in progress fetch.
    func fetch<Query: GraphQLQuery>(
        query: Query,
        context: RequestHeaders?,
        queue: DispatchQueue,
        resultHandler: @escaping (Result<Query.Data, GraphQLAPIAdapterError>) -> Void
    ) -> Cancellable

    /// Performs a mutation by sending it to the server.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to perform.
    ///   - context: [optional] A context that is being passed through the request chain. Should default to `nil`.
    ///   - queue: A dispatch queue on which the result handler will be called. Should default to the main queue.
    ///   - resultHandler: An optional closure that is called when mutation results are available or when an error occurs.
    /// - Returns: An object that can be used to cancel an in progress mutation.
    func perform<Mutation: GraphQLMutation>(
        mutation: Mutation,
        context: RequestHeaders?,
        queue: DispatchQueue,
        resultHandler: @escaping (Result<Mutation.Data, GraphQLAPIAdapterError>) -> Void
    ) -> Cancellable
}

public final class GraphQLAPIAdapter: GraphQLAPIAdapterProtocol {
    private let apollo: ApolloClientProtocol

    public init(
        url: URL,
        urlSessionConfiguration: URLSessionConfiguration = .default,
        defaultHeaders: [String: String] = [:],
        networkObservers: [any GraphQLNetworkObserver] = []
    ) {
        let provider = NetworkInterceptorProvider(
            client: URLSessionClient(sessionConfiguration: urlSessionConfiguration),
            defaultHeaders: defaultHeaders,
            networkObservers: networkObservers
        )

        let networkTransport = RequestChainNetworkTransport(
            interceptorProvider: provider,
            endpointURL: url
        )

        self.apollo = ApolloClient(
            networkTransport: networkTransport,
            store: ApolloStore()
        )
    }

    public func fetch<Query>(
        query: Query,
        context: RequestHeaders?,
        queue: DispatchQueue,
        resultHandler: @escaping (Result<Query.Data, GraphQLAPIAdapterError>) -> Void
    ) -> Cancellable where Query: GraphQLQuery {
        apollo.fetch(
            query: query,
            cachePolicy: .fetchIgnoringCacheCompletely,
            contextIdentifier: nil,
            context: context,
            queue: queue
        ) { result in
            switch result {
            case .success(let result):
                if let errors = result.errors {
                    resultHandler(.failure(GraphQLAPIAdapterError(error: ApolloError(errors: errors))))
                } else if let data = result.data {
                    resultHandler(.success(data))
                } else {
                    assertionFailure("Did not receive no data nor errors")
                }
            case .failure(let error):
                resultHandler(.failure(GraphQLAPIAdapterError(error: error)))
            }
        }
    }

    public func perform<Mutation>(
        mutation: Mutation,
        context: RequestHeaders?,
        queue: DispatchQueue,
        resultHandler: @escaping (Result<Mutation.Data, GraphQLAPIAdapterError>) -> Void
    ) -> Cancellable where Mutation: GraphQLMutation {
        apollo.perform(
            mutation: mutation,
            publishResultToStore: false,
            context: context,
            queue: queue
        ) { result in
            switch result {
            case .success(let result):
                if let errors = result.errors {
                    resultHandler(.failure(GraphQLAPIAdapterError(error: ApolloError(errors: errors))))
                } else if let data = result.data {
                    resultHandler(.success(data))
                } else {
                    assertionFailure("Did not receive no data nor errors")
                }
            case .failure(let error):
                resultHandler(.failure(GraphQLAPIAdapterError(error: error)))
            }
        }
    }
}
