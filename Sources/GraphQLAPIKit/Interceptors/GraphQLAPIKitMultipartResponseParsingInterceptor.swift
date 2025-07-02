import Apollo
import ApolloAPI
import Foundation

struct GraphQLAPIKitMultipartResponseParsingInterceptor: InjectableInterceptor {
    let placement: InterceptorPlacement = .afterNetworkFetch(priority: InterceptorPriority.normal)
    let id: String = UUID().uuidString
    private let actualInterceptor = MultipartResponseParsingInterceptor()

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
