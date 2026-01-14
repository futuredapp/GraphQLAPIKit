import XCTest
import Apollo
@testable import GraphQLAPIKit

final class GraphQLAPIAdapterErrorTests: XCTestCase {
    func testGraphQLAPIAdapterErrorPassthrough() {
        // Given
        let originalError = GraphQLAPIAdapterError.cancelled

        // When
        let error = GraphQLAPIAdapterError(error: originalError)

        // Then
        if case .cancelled = error {
            // Success
        } else {
            XCTFail("Expected .cancelled error")
        }
    }

    func testApolloErrorConversion() {
        // Given
        let graphQLErrors = [
            Apollo.GraphQLError(["message": "Field error", "extensions": ["code": "FIELD_ERROR"]])
        ]
        let apolloError = ApolloError(errors: graphQLErrors)

        // When
        let error = GraphQLAPIAdapterError(error: apolloError)

        // Then
        if case let .graphQl(errors) = error {
            XCTAssertEqual(errors.count, 1)
            XCTAssertEqual(errors.first?.message, "Field error")
            XCTAssertEqual(errors.first?.code, "FIELD_ERROR")
            XCTAssertEqual(error.errorDescription, "Field error")
        } else {
            XCTFail("Expected .graphQl error")
        }
    }

    func testURLErrorNotConnectedToInternet() {
        // Given
        let urlError = URLError(.notConnectedToInternet)

        // When
        let error = GraphQLAPIAdapterError(error: urlError)

        // Then
        if case .connection = error {
            // Success
        } else {
            XCTFail("Expected .connection error")
        }
    }

    func testURLErrorNetworkConnectionLost() {
        // Given
        let urlError = URLError(.networkConnectionLost)

        // When
        let error = GraphQLAPIAdapterError(error: urlError)

        // Then
        if case .connection = error {
            // Success
        } else {
            XCTFail("Expected .connection error")
        }
    }

    func testURLErrorCancelled() {
        // Given
        let urlError = URLError(.cancelled)

        // When
        let error = GraphQLAPIAdapterError(error: urlError)

        // Then
        if case .cancelled = error {
            // Success
        } else {
            XCTFail("Expected .cancelled error")
        }
    }

    func testCancellationError() {
        // Given
        let cancellationError = CancellationError()

        // When
        let error = GraphQLAPIAdapterError(error: cancellationError)

        // Then
        if case .cancelled = error {
            // Success
        } else {
            XCTFail("Expected .cancelled error")
        }
    }

    func testUnhandledError() {
        // Given
        let unknownError = NSError(
            domain: "UnknownDomain",
            code: 999,
            userInfo: [NSLocalizedDescriptionKey: "Unknown error"]
        )

        // When
        let error = GraphQLAPIAdapterError(error: unknownError)

        // Then
        if case let .unhandled(error) = error {
            XCTAssertEqual(error.localizedDescription, "Unknown error")
        } else {
            XCTFail("Expected .unhandled error")
        }
    }

    func testCancelledErrorDescription() {
        // Given
        let error = GraphQLAPIAdapterError.cancelled

        // Then
        XCTAssertNil(error.errorDescription)
    }

    func testNetworkErrorDescription() {
        // Given
        let underlyingError = NSError(
            domain: "TestDomain",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Not found"]
        )
        let error = GraphQLAPIAdapterError.network(code: 404, error: underlyingError)

        // Then
        XCTAssertEqual(error.errorDescription, "Not found")
    }

    func testConnectionErrorDescription() {
        // Given
        let underlyingError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "No internet"]
        )
        let error = GraphQLAPIAdapterError.connection(underlyingError)

        // Then
        XCTAssertEqual(error.errorDescription, "No internet")
    }

    func testUnhandledErrorDescription() {
        // Given
        let underlyingError = NSError(
            domain: "TestDomain",
            code: 123,
            userInfo: [NSLocalizedDescriptionKey: "Test error"]
        )
        let error = GraphQLAPIAdapterError.unhandled(underlyingError)

        // Then
        XCTAssertEqual(error.errorDescription, "Test error")
    }

    func testGraphQLErrorDescription() {
        // Given
        let graphQLErrors = [
            Apollo.GraphQLError(["message": "First error"]),
            Apollo.GraphQLError(["message": "Second error"])
        ]
        let apolloError = ApolloError(errors: graphQLErrors)
        let error = GraphQLAPIAdapterError(error: apolloError)

        // Then
        // Should return the first error's message
        XCTAssertEqual(error.errorDescription, "First error")
    }

    func testGraphQLErrorDescriptionWithEmptyArray() {
        // Given
        let error = GraphQLAPIAdapterError.graphQl([])

        // Then
        XCTAssertNil(error.errorDescription)
    }
}
