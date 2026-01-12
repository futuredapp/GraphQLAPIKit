import Apollo
import ApolloAPI
import Foundation

/// Internal interceptor that observes network requests for a single observer.
///
/// One interceptor per observer (1:1 relationship), matching FTAPIKit's RequestToken pattern.
/// Uses closure capture to store URLRequest and Context immutably - type erasure happens
/// at closure creation time.
final class ObserverInterceptor: ApolloInterceptor, @unchecked Sendable {
    let id = UUID().uuidString

    /// Handlers set on first call, capturing URLRequest and Context in closures
    private var didReceiveResponse: ((URLResponse?, Data?) -> Void)?
    private var didFail: ((Error) -> Void)?

    /// Factory that creates the handlers - captures the observer with its concrete type
    private let createHandlers: (URLRequest) -> (
        didReceiveResponse: (URLResponse?, Data?) -> Void,
        didFail: (Error) -> Void
    )

    /// Creates an interceptor for the given observer.
    /// The generic initializer captures the concrete Observer type and its Context.
    init<Observer: GraphQLNetworkObserver>(observer: Observer) {
        self.createHandlers = { urlRequest in
            // Call willSendRequest and capture context
            let context = observer.willSendRequest(urlRequest)

            // Create handlers that capture urlRequest and context immutably
            let didReceiveResponse: (URLResponse?, Data?) -> Void = { [weak observer] response, data in
                observer?.didReceiveResponse(for: urlRequest, response: response, data: data, context: context)
            }

            let didFail: (Error) -> Void = { [weak observer] error in
                observer?.didFail(request: urlRequest, error: error, context: context)
            }

            return (didReceiveResponse, didFail)
        }
    }

    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        if response == nil {
            // Before network fetch - create handlers with captured context
            if let urlRequest = try? request.toURLRequest() {
                let handlers = createHandlers(urlRequest)
                didReceiveResponse = handlers.didReceiveResponse
                didFail = handlers.didFail
            }
        } else {
            // After network fetch - invoke captured closure
            didReceiveResponse?(response?.httpResponse, response?.rawData)
        }

        chain.proceedAsync(request: request, response: response, interceptor: self, completion: completion)
    }

    /// Called when the operation fails
    func notifyFailure(_ error: Error) {
        didFail?(error)
    }
}
