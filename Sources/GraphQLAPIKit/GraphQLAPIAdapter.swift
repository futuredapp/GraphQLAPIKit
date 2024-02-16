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
        resultHandler: @escaping (Result<GraphQLResult<Query.Data>, Error>) -> Void
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
        resultHandler: @escaping (Result<GraphQLResult<Mutation.Data>, Error>) -> Void
    ) -> Cancellable
}

final class GraphQLAPIAdapter: GraphQLAPIAdapterProtocol {
    private let apollo: ApolloClient

    public init(
        url: URL,
        urlSessionConfiguration: URLSessionConfiguration = .default,
        defaultHeaders: [String: String] = [:]
    ) {
        let provider = NetworkInterceptorProvider(
            client: URLSessionClient(sessionConfiguration: urlSessionConfiguration),
            defaultHeaders: defaultHeaders
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

    func fetch<Query>(
        query: Query,
        context: RequestHeaders?,
        queue: DispatchQueue,
        resultHandler: @escaping GraphQLResultHandler<Query.Data>
    ) -> Cancellable where Query : GraphQLQuery {
        apollo.fetch(
            query: query,
            cachePolicy: .fetchIgnoringCacheCompletely,
            context: context,
            queue: queue,
            resultHandler: resultHandler
        )
    }

    func perform<Mutation>(
        mutation: Mutation,
        context: RequestHeaders?,
        queue: DispatchQueue,
        resultHandler: @escaping GraphQLResultHandler<Mutation.Data>
    ) -> Cancellable where Mutation : GraphQLMutation {
        apollo.perform(
            mutation: mutation,
            publishResultToStore: false,
            context: context,
            queue: queue,
            resultHandler: resultHandler
        )
    }
}

private struct NetworkInterceptorProvider: InterceptorProvider {
    private let client: URLSessionClient
    private let defaultHeaders: [String: String]

    init(client: URLSessionClient, defaultHeaders: [String: String]) {
        self.client = client
        self.defaultHeaders = defaultHeaders
    }

    func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
        [
            RequestHeaderInterceptor(defaultHeaders: defaultHeaders),
            MaxRetryInterceptor(),
            NetworkFetchInterceptor(client: self.client),
            ResponseCodeInterceptor(),
            JSONResponseParsingInterceptor()
        ]
    }

    func additionalErrorInterceptor<Operation: GraphQLOperation>(for operation: Operation) -> ApolloErrorInterceptor? {
        nil
    }
}

private struct RequestHeaderInterceptor: ApolloInterceptor {
    var id: String = UUID().uuidString

    private let defaultHeaders: [String: String]

    init(defaultHeaders: [String: String]) {
        self.defaultHeaders = defaultHeaders
    }

    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        defaultHeaders.forEach { request.addHeader(name: $0.key, value: $0.value) }
        if let additionalHeaders = request.context as? RequestHeaders {
            additionalHeaders.additionalHeaders.forEach { request.addHeader(name: $0.key, value: $0.value) }
        }

        chain.proceedAsync(request: request, response: response, interceptor: self, completion: completion)
    }
}


