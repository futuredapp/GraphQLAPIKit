import Apollo
import Foundation

public enum GraphQLAPIAdapterError: LocalizedError {
    /// Network error received by Apollo from `URLSessionTaskDelegate`
    case network(code: Int, error: Error)

    /// The app is offline or doesn't have access to the network.
    case connection(Error)

    /// Unhandled network error received from `Apollo.URLSessionClient`
    case unhandled(Error)

    /// Request was cancelled
    case cancelled

    /// GraphQL errors
    /// Errors returned by GraphQL API as part of `errors` field
    case graphQl([GraphQLError])


    init(error: Error) {
        if let error = error as? GraphQLAPIAdapterError {
            self = error
        } else if let error = error as? ApolloError {
            self = .graphQl(error.errors.map(GraphQLError.init))
        } else if let error = error as? URLSessionClient.URLSessionClientError,
            case let URLSessionClient.URLSessionClientError.networkError(_, response, underlyingError) = error
        {
            if let response = response {
                self = .network(code: response.statusCode, error: underlyingError)
            } else {
                self = .connection(underlyingError)
            }
        } else {
            self = .unhandled(error)
        }
    }

    public var errorDescription: String? {
        switch self {
        case .network(_, let error), .connection(let error), .unhandled(let error):
            return error.localizedDescription
        case .graphQl(let error):
            return error.first?.errorDescription
        case .cancelled:
            return nil
        }
    }
}
