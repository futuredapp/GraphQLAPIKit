import Apollo
import ApolloAPI
import Foundation
import FTNetworkTracer

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
    private let networkTracer: FTNetworkTracer?
    private let url: URL

    public init(
        url: URL,
        urlSessionConfiguration: URLSessionConfiguration = .default,
        defaultHeaders: [String: String] = [:],
        networkTracer: FTNetworkTracer? = nil
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

        self.networkTracer = networkTracer
        self.url = url
    }

    public func fetch<Query>(
        query: Query,
        context: RequestHeaders?,
        queue: DispatchQueue,
        resultHandler: @escaping (Result<Query.Data, GraphQLAPIAdapterError>) -> Void
    ) -> Cancellable where Query: GraphQLQuery {
        let requestId = UUID().uuidString
        let startTime = Date()

        // Log and track request
        networkTracer?.logAndTrackRequest(
            url: url.absoluteString,
            operationName: Query.operationName,
            query: Query.definition?.queryDocument ?? "",
            variables: query.__variables,
            headers: context?.additionalHeaders,
            requestId: requestId
        )

        return apollo.fetch(
            query: query,
            cachePolicy: .fetchIgnoringCacheCompletely,
            contextIdentifier: nil,
            context: context,
            queue: queue
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(result):
                // Log and track response
                self.networkTracer?.logAndTrackResponse(
                    url: self.url.absoluteString,
                    operationName: Query.operationName,
                    statusCode: nil, // We don't have access to status code here
                    requestId: requestId,
                    startTime: startTime
                )

                if let errors = result.errors {
                    let error = GraphQLAPIAdapterError(error: ApolloError(errors: errors))
                    self.networkTracer?.logAndTrackError(
                        url: self.url.absoluteString,
                        operationName: Query.operationName,
                        error: error,
                        requestId: requestId
                    )
                    resultHandler(.failure(error))
                } else if let data = result.data {
                    resultHandler(.success(data))
                } else {
                    assertionFailure("Did not receive no data nor errors")
                }
            case let .failure(error):
                let adaptedError = GraphQLAPIAdapterError(error: error)
                self.networkTracer?.logAndTrackError(
                    url: self.url.absoluteString,
                    operationName: Query.operationName,
                    error: adaptedError,
                    requestId: requestId
                )
                resultHandler(.failure(adaptedError))
            }
        }
    }

    public func perform<Mutation>(
        mutation: Mutation,
        context: RequestHeaders?,
        queue: DispatchQueue,
        resultHandler: @escaping (Result<Mutation.Data, GraphQLAPIAdapterError>) -> Void
    ) -> Cancellable where Mutation: GraphQLMutation {
        let requestId = UUID().uuidString
        let startTime = Date()

        // Log and track request
        networkTracer?.logAndTrackRequest(
            url: url.absoluteString,
            operationName: Mutation.operationName,
            query: Mutation.definition?.queryDocument ?? "",
            variables: mutation.__variables,
            headers: context?.additionalHeaders,
            requestId: requestId
        )

        return apollo.perform(
            mutation: mutation,
            publishResultToStore: false,
            context: context,
            queue: queue
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(result):
                // Log and track response
                self.networkTracer?.logAndTrackResponse(
                    url: self.url.absoluteString,
                    operationName: Mutation.operationName,
                    statusCode: nil, // We don't have access to status code here
                    requestId: requestId,
                    startTime: startTime
                )

                if let errors = result.errors {
                    let error = GraphQLAPIAdapterError(error: ApolloError(errors: errors))
                    self.networkTracer?.logAndTrackError(
                        url: self.url.absoluteString,
                        operationName: Mutation.operationName,
                        error: error,
                        requestId: requestId
                    )
                    resultHandler(.failure(error))
                } else if let data = result.data {
                    resultHandler(.success(data))
                } else {
                    assertionFailure("Did not receive no data nor errors")
                }
            case .failure(let error):
                let adaptedError = GraphQLAPIAdapterError(error: error)
                self.networkTracer?.logAndTrackError(
                    url: self.url.absoluteString,
                    operationName: Mutation.operationName,
                    error: adaptedError,
                    requestId: requestId
                )
                resultHandler(.failure(adaptedError))
            }
        }
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
            MultipartResponseParsingInterceptor(),
            JSONResponseParsingInterceptor()
        ]
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
