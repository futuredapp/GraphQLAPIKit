import Apollo
import ApolloAPI

struct NetworkInterceptorProvider: InterceptorProvider {
    private let defaultHeaders: [String: String]
    private let interceptors: [ApolloInterceptor]
    private let errorInterceptor: (any ApolloErrorInterceptor)?

    init(
        defaultHeaders: [String: String],
        interceptors: [ApolloInterceptor],
        errorInterceptor: (any ApolloErrorInterceptor)?
    ) {
        self.defaultHeaders = defaultHeaders
        self.interceptors = interceptors
        self.errorInterceptor = errorInterceptor
    }

    func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
        interceptors
    }

    func additionalErrorInterceptor<Operation: GraphQLOperation>(for operation: Operation) -> (any ApolloErrorInterceptor)?  {
        errorInterceptor
    }
}
