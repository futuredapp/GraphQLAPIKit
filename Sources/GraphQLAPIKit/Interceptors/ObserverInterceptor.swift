import Apollo
import ApolloAPI
import Foundation

/// Interceptor that observes network requests. Place TWO instances in chain:
/// - One BEFORE NetworkFetchInterceptor (captures request timing)
/// - One AFTER NetworkFetchInterceptor (captures response)
/// Both instances share state via the contextStore actor.
struct ObserverInterceptor<Observer: GraphQLNetworkObserver>: ApolloInterceptor {
    let id = UUID().uuidString

    private let observer: Observer
    private let contextStore: ObserverContextStore<Observer.Context>

    init(observer: Observer, contextStore: ObserverContextStore<Observer.Context>) {
        self.observer = observer
        self.contextStore = contextStore
    }

    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        guard let urlRequest = try? request.toURLRequest() else {
            chain.proceedAsync(request: request, response: response, interceptor: self, completion: completion)
            return
        }

        let requestId = urlRequest.hashValue.description

        if response == nil {
            // BEFORE network fetch - call willSendRequest and store context synchronously
            let context = observer.willSendRequest(urlRequest)
            contextStore.store(context, for: requestId)
        } else {
            // AFTER network fetch - retrieve context and call didReceiveResponse
            if let context = contextStore.retrieve(for: requestId) {
                observer.didReceiveResponse(
                    for: urlRequest,
                    response: response?.httpResponse,
                    data: response?.rawData,
                    context: context
                )
            }
        }

        // Wrap completion to handle errors
        let wrappedCompletion: (Result<GraphQLResult<Operation.Data>, Error>) -> Void = { result in
            if case .failure(let error) = result {
                if let context = contextStore.retrieve(for: requestId) {
                    observer.didFail(request: urlRequest, error: error, context: context)
                }
            }
            completion(result)
        }

        chain.proceedAsync(request: request, response: response, interceptor: self, completion: wrappedCompletion)
    }
}
