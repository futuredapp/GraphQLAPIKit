import Apollo
import ApolloAPI
import Foundation

struct NetworkInterceptorProvider: InterceptorProvider {
    private let client: URLSessionClient
    private let defaultHeaders: [String: String]
    private let pairOfObserverInterceptors: [(before: ApolloInterceptor, after: ApolloInterceptor)]

    init(
        client: URLSessionClient,
        defaultHeaders: [String: String],
        networkObservers: [any GraphQLNetworkObserver]
    ) {
        self.client = client
        self.defaultHeaders = defaultHeaders
        // Create interceptor pairs with shared context stores
        self.pairOfObserverInterceptors = networkObservers.map { Self.makePair(of: $0) }
    }

    func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
        // Headers first, then before-observers, then network fetch, then after-observers
        [
            RequestHeaderInterceptor(defaultHeaders: defaultHeaders),
        ]
        + pairOfObserverInterceptors.map(\.before)  // Before network - captures timing
        + [
            MaxRetryInterceptor(),
            NetworkFetchInterceptor(client: client)
        ]
        + pairOfObserverInterceptors.map(\.after)   // After network - captures response
        + [
            ResponseCodeInterceptor(),
            MultipartResponseParsingInterceptor(),
            JSONResponseParsingInterceptor()
        ]
    }
    
    static private func makePair<T: GraphQLNetworkObserver>(of observer: T) -> (before: ApolloInterceptor, after: ApolloInterceptor) {
        let contextStore = ObserverContextStore<T.Context>()
        let beforeInterceptor = ObserverInterceptor(observer: observer, contextStore: contextStore)
        let afterInterceptor = ObserverInterceptor(observer: observer, contextStore: contextStore)
        return (before: beforeInterceptor, after: afterInterceptor)
    }
}
