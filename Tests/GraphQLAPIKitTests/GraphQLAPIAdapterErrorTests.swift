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

    func testURLSessionClientNetworkErrorWithResponse() {
        // Given
        let underlyingError = NSError(
            domain: "TestDomain",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Server error"]
        )
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!
        let urlSessionError = URLSessionClient.URLSessionClientError.networkError(
            data: Data(),
            response: response,
            underlying: underlyingError
        )

        // When
        let error = GraphQLAPIAdapterError(error: urlSessionError)

        // Then
        if case let .network(code, error) = error {
            XCTAssertEqual(code, 500)
            XCTAssertEqual(error.localizedDescription, "Server error")
        } else {
            XCTFail("Expected .network error")
        }
    }

    func testURLSessionClientNetworkErrorWithoutResponse() {
        // Given
        let underlyingError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "No internet connection"]
        )
        let urlSessionError = URLSessionClient.URLSessionClientError.networkError(
            data: Data(),
            response: nil,
            underlying: underlyingError
        )

        // When
        let error = GraphQLAPIAdapterError(error: urlSessionError)

        // Then
        if case let .connection(error) = error {
            XCTAssertEqual(error.localizedDescription, "No internet connection")
        } else {
            XCTFail("Expected .connection error")
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
