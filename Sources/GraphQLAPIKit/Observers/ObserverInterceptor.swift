import Apollo
import ApolloAPI
import Foundation

/// Interceptor that observes network requests. Place TWO instances in chain:
/// - One BEFORE NetworkFetchInterceptor (captures request timing)
/// - One AFTER NetworkFetchInterceptor (captures response)
/// Both instances share state via the contextStore actor.
final class ObserverInterceptor<Observer: GraphQLNetworkObserver>: ApolloInterceptor, @unchecked Sendable {
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
            // BEFORE network fetch - call willSendRequest and store context
            let context = observer.willSendRequest(urlRequest)
            Task {
                await contextStore.store(context, for: requestId)
            }
        } else {
            // AFTER network fetch - retrieve context and call didReceiveResponse
            Task { [weak self] in
                guard let self,
                      let context = await contextStore.retrieve(for: requestId) else {
                    return
                }
                self.observer.didReceiveResponse(
                    for: urlRequest,
                    response: response?.httpResponse,
                    data: response?.rawData,
                    context: context
                )
            }
        }

        // Wrap completion to handle errors
        let wrappedCompletion: (Result<GraphQLResult<Operation.Data>, Error>) -> Void = { [weak self] result in
            if case .failure(let error) = result {
                Task {
                    guard let self,
                          let context = await self.contextStore.retrieve(for: requestId) else {
                        completion(result)
                        return
                    }
                    self.observer.didFail(request: urlRequest, error: error, context: context)
                    completion(result)
                }
                return
            }
            completion(result)
        }

        chain.proceedAsync(request: request, response: response, interceptor: self, completion: wrappedCompletion)
    }
}
