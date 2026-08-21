import Apollo
import ApolloAPI

/// A no-op cache interceptor that skips all cache operations.
/// Used when caching is disabled.
struct NoCacheInterceptor: CacheInterceptor {
    func readCacheData<Request: GraphQLRequest>(
        from store: ApolloStore,
        request: Request
    ) async throws -> GraphQLResponse<Request.Operation>? {
        // Never read from cache
        nil
    }

    func writeCacheData<Request: GraphQLRequest>(
        to store: ApolloStore,
        request: Request,
        response: ParsedResult<Request.Operation>
    ) async throws {
        // Never write to cache - no-op
    }
}
