import Apollo
import Foundation

public struct GraphQLAPIError: LocalizedError {
    public let message: String
    public let code: String?

    init(from graphQlError: GraphQLError) {
        if let message = graphQlError.message {
            self.message = message
        } else {
            self.message = "-No message-"
            assertionFailure("GraphQLError is missing required `message` field")
        }
        self.code = graphQlError.extensions?["code"] as? String
    }

    public var errorDescription: String? {
        message
    }
}
