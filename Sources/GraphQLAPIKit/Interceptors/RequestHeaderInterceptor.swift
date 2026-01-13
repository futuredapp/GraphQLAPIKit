import Apollo
import ApolloAPI
import Foundation

struct RequestHeaderInterceptor: ApolloInterceptor {
    let id: String = UUID().uuidString

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
