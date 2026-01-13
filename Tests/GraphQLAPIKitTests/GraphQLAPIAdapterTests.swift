import Apollo
import ApolloAPI
import XCTest
@testable import GraphQLAPIKit

final class GraphQLAPIAdapterTests: XCTestCase {
    let testURL = URL(string: "https://api.example.com/graphql")!

    // MARK: - Initialization Tests

    func testAdapterInitializationWithMinimalParameters() {
        let adapter = GraphQLAPIAdapter(url: testURL)
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithCustomHeaders() {
        let headers = [
            "Authorization": "Bearer token123",
            "Content-Type": "application/json",
            "X-API-Key": "secret"
        ]
        let adapter = GraphQLAPIAdapter(
            url: testURL,
            defaultHeaders: headers
        )
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithCustomURLSessionConfiguration() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        let adapter = GraphQLAPIAdapter(
            url: testURL,
            urlSessionConfiguration: config
        )
        XCTAssertNotNil(adapter)
    }

}
