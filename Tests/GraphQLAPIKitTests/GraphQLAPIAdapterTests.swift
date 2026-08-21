import Apollo
import ApolloAPI
@testable import GraphQLAPIKit
import XCTest

final class GraphQLAPIAdapterTests: XCTestCase {
    // swiftlint:disable:next force_unwrapping
    let testURL = URL(string: "https://api.example.com/graphql")!

    // MARK: - Initialization Tests

    func testAdapterInitializationWithMinimalParameters() {
        let configuration = GraphQLAPIConfiguration(url: testURL)
        let adapter = GraphQLAPIAdapter(configuration: configuration)
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithCustomHeaders() {
        let headers = [
            "Authorization": "Bearer token123",
            "Content-Type": "application/json",
            "X-API-Key": "secret"
        ]
        let configuration = GraphQLAPIConfiguration(
            url: testURL,
            defaultHeaders: headers
        )
        let adapter = GraphQLAPIAdapter(configuration: configuration)
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithCustomURLSessionConfiguration() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60

        let configuration = GraphQLAPIConfiguration(
            url: testURL,
            urlSessionConfiguration: sessionConfig
        )
        let adapter = GraphQLAPIAdapter(configuration: configuration)
        XCTAssertNotNil(adapter)
    }
}
