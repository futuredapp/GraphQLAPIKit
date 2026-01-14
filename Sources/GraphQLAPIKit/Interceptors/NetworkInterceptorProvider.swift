import Apollo
import ApolloAPI
import Foundation

struct NetworkInterceptorProvider: InterceptorProvider {
    private let defaultHeaders: [String: String]
    private let networkObservers: [any GraphQLNetworkObserver]

    init(
        defaultHeaders: [String: String],
        networkObservers: [any GraphQLNetworkObserver]
    ) {
        self.defaultHeaders = defaultHeaders
        self.networkObservers = networkObservers
    }

    func graphQLInterceptors<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> [any GraphQLInterceptor] {
        [
            RequestHeaderInterceptor(defaultHeaders: defaultHeaders),
            MaxRetryInterceptor()
        ]
    }

    func httpInterceptors<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> [any HTTPInterceptor] {
        var interceptors: [any HTTPInterceptor] = networkObservers.map { observer in
            makeObserverInterceptor(observer)
        }
        interceptors.append(ResponseCodeInterceptor())
        return interceptors
    }

    func cacheInterceptor<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> any CacheInterceptor {
        // No-op cache interceptor - we don't use caching
        NoCacheInterceptor()
    }

    func responseParser<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> any ResponseParsingInterceptor {
        JSONResponseParsingInterceptor()
    }

    private func makeObserverInterceptor<T: GraphQLNetworkObserver>(
        _ observer: T
    ) -> any HTTPInterceptor {
        ObserverInterceptor(observer: observer)
    }
}
