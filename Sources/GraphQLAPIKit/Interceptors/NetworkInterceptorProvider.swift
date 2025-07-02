import Apollo
import ApolloAPI

struct NetworkInterceptorProvider: InterceptorProvider {
    private let defaultHeaders: [String: String]
    private let interceptors: [ApolloInterceptor]

    init(
        defaultHeaders: [String: String],
        interceptors: [ApolloInterceptor]
    ) {
        self.defaultHeaders = defaultHeaders
        self.interceptors = interceptors
    }

    func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
        interceptors
    }
}
