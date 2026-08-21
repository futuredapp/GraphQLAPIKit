import Apollo
import ApolloAPI
import Foundation

/// Interceptor that observes network requests.
/// In Apollo 2.0, this uses the HTTPInterceptor protocol with pre-flight and post-flight in a single instance.
struct ObserverInterceptor<Observer: GraphQLNetworkObserver>: HTTPInterceptor {
    private let observer: Observer

    init(observer: Observer) {
        self.observer = observer
    }

    func intercept(
        request: URLRequest,
        next: NextHTTPInterceptorFunction
    ) async throws -> HTTPResponse {
        // PRE-FLIGHT: Called before network request
        let context = observer.willSendRequest(request)

        do {
            // Execute network request and get response
            let httpResponse = try await next(request)

            // POST-FLIGHT: Notify observer with response metadata
            // Note: In Apollo 2.0, response data is streamed, so we pass nil for data
            // The response metadata (status code, headers) is still available immediately
            observer.didReceiveResponse(
                for: request,
                response: httpResponse.response,
                data: nil,
                context: context
            )

            return httpResponse
        } catch {
            // Error handling
            observer.didFail(request: request, error: error, context: context)
            throw error
        }
    }
}
