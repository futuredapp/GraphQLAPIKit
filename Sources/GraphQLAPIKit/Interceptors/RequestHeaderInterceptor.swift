import Apollo
import ApolloAPI
import Foundation

struct RequestHeaderInterceptor: GraphQLInterceptor {
    private let defaultHeaders: [String: String]
    private let requestHeaders: RequestHeaders?

    init(defaultHeaders: [String: String], requestHeaders: RequestHeaders? = nil) {
        self.defaultHeaders = defaultHeaders
        self.requestHeaders = requestHeaders
    }

    func intercept<Request: GraphQLRequest>(
        request: Request,
        next: NextInterceptorFunction<Request>
    ) async throws -> InterceptorResultStream<Request> {
        var modifiedRequest = request

        // Add default headers
        for (key, value) in defaultHeaders {
            modifiedRequest.addHeader(name: key, value: value)
        }

        // Add request-specific headers
        if let headers = requestHeaders?.additionalHeaders {
            for (key, value) in headers {
                modifiedRequest.addHeader(name: key, value: value)
            }
        }

        // Continue chain
        return await next(modifiedRequest)
    }
}
