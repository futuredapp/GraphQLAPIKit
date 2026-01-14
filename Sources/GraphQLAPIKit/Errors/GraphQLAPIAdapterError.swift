import Apollo
import Foundation

public enum GraphQLAPIAdapterError: LocalizedError, Sendable {
    /// Network error with HTTP status code
    case network(code: Int, error: Error)

    /// The app is offline or doesn't have access to the network.
    case connection(Error)

    /// Unhandled error
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
        } else if error is CancellationError {
            self = .cancelled
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled:
                self = .cancelled
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                self = .connection(urlError)
            default:
                self = .unhandled(urlError)
            }
        } else {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                if nsError.code == NSURLErrorCancelled {
                    self = .cancelled
                } else if nsError.code == NSURLErrorNotConnectedToInternet ||
                          nsError.code == NSURLErrorNetworkConnectionLost {
                    self = .connection(error)
                } else {
                    self = .unhandled(error)
                }
            } else {
                self = .unhandled(error)
            }
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
