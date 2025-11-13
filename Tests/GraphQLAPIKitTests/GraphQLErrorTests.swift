import XCTest
import Apollo
@testable import GraphQLAPIKit

final class GraphQLErrorTests: XCTestCase {
    func testGraphQLErrorWithMessageAndCode() {
        // Given
        let apolloError = Apollo.GraphQLError(
            ["message": "User not found", "extensions": ["code": "USER_NOT_FOUND"]]
        )

        // When
        let error = GraphQLError(from: apolloError)

        // Then
        XCTAssertEqual(error.message, "User not found")
        XCTAssertEqual(error.code, "USER_NOT_FOUND")
        XCTAssertEqual(error.errorDescription, "User not found")
    }

    func testGraphQLErrorWithMessageWithoutCode() {
        // Given
        let apolloError = Apollo.GraphQLError(
            ["message": "Internal server error"]
        )

        // When
        let error = GraphQLError(from: apolloError)

        // Then
        XCTAssertEqual(error.message, "Internal server error")
        XCTAssertNil(error.code)
        XCTAssertEqual(error.errorDescription, "Internal server error")
    }

    func testGraphQLErrorWithEmptyMessage() {
        // Given
        let apolloError = Apollo.GraphQLError(
            ["message": "", "extensions": ["code": "EMPTY_ERROR"]]
        )

        // When
        let error = GraphQLError(from: apolloError)

        // Then
        XCTAssertEqual(error.message, "")
        XCTAssertEqual(error.code, "EMPTY_ERROR")
        XCTAssertEqual(error.errorDescription, "")
    }

    func testGraphQLErrorWithExtensionsButNoCode() {
        // Given
        let apolloError = Apollo.GraphQLError(
            ["message": "Error with extensions", "extensions": ["other": "value"]]
        )

        // When
        let error = GraphQLError(from: apolloError)

        // Then
        XCTAssertEqual(error.message, "Error with extensions")
        XCTAssertNil(error.code)
    }
}
