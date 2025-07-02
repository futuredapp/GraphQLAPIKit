import Apollo
import ApolloAPI
import Foundation

struct GraphQLAPIKitNetworkFetchInterceptor: InjectableInterceptor {
    let placement: InterceptorPlacement = .beforeNetworkFetch(priority: InterceptorPriority.low)
    let id: String = UUID().uuidString
    private let actualInterceptor: NetworkFetchInterceptor

    init(client: URLSessionClient) {
        self.actualInterceptor = .init(client: client)
    }

    func interceptAsync<Operation: GraphQLOperation>(
        chain: any Apollo.RequestChain,
        request: Apollo.HTTPRequest<Operation>,
        response: Apollo.HTTPResponse<Operation>?,
        completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void) {
            actualInterceptor.interceptAsync(
                chain: chain,
                request: request,
                response: response,
                completion: completion
            )
        }
}
