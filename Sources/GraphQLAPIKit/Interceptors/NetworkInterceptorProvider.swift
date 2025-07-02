import Apollo
import ApolloAPI

struct NetworkInterceptorProvider: InterceptorProvider {
    private let defaultHeaders: [String: String]
    private let interceptors: [any InjectableInterceptor]
    private let errorInterceptor: (any ApolloErrorInterceptor)?

    init(
        defaultHeaders: [String: String],
        interceptors: [any InjectableInterceptor],
        errorInterceptor: (any ApolloErrorInterceptor)?
    ) {
        self.defaultHeaders = defaultHeaders
        self.interceptors = interceptors
        self.errorInterceptor = errorInterceptor
    }

    func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
        interceptors.filter { interceptor in
            guard let specificOperationType = interceptor.operationSpecific else {
                return true
            }

            return type(of: operation) == specificOperationType
        }
    }

    func additionalErrorInterceptor<Operation: GraphQLOperation>(for operation: Operation) -> (any ApolloErrorInterceptor)?  {
        errorInterceptor
    }
}
