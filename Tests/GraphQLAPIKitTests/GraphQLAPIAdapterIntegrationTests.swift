import Apollo
import ApolloAPI
import XCTest
@testable import GraphQLAPIKit

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    /// Captured requests for verification
    static var capturedRequests: [URLRequest] = []

    /// Response to return
    static var mockResponse: (data: Data, statusCode: Int)?

    /// Error to return
    static var mockError: Error?

    /// Reset state between tests
    static func reset() {
        capturedRequests = []
        mockResponse = nil
        mockError = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        // Capture the request
        MockURLProtocol.capturedRequests.append(request)

        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = MockURLProtocol.mockResponse ?? (
            data: validGraphQLResponse,
            statusCode: 200
        )

        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// A valid GraphQL response with minimal data
    private var validGraphQLResponse: Data {
        """
        {"data": {"__typename": "Query"}}
        """.data(using: .utf8)!
    }
}

// MARK: - Mock GraphQL Schema and Query

enum MockSchema: SchemaMetadata {
    static let configuration: any SchemaConfiguration.Type = MockSchemaConfiguration.self

    static func objectType(forTypename typename: String) -> Object? {
        if typename == "Query" { return MockQuery.Data.self.__parentType as? Object }
        return nil
    }
}

enum MockSchemaConfiguration: SchemaConfiguration {
    static func cacheKeyInfo(for type: Object, object: ObjectData) -> CacheKeyInfo? {
        nil
    }
}

/// Minimal mock query for testing
final class MockQuery: GraphQLQuery {
    typealias Data = MockQueryData

    static let operationName: String = "MockQuery"
    static let operationDocument: OperationDocument = OperationDocument(
        definition: .init("query MockQuery { __typename }")
    )

    init() {}

    struct MockQueryData: RootSelectionSet {
        typealias Schema = MockSchema

        static var __parentType: any ParentType { Object(typename: "Query", implementedInterfaces: []) }
        static var __selections: [Selection] { [] }

        var __data: DataDict

        init(_dataDict: DataDict) {
            self.__data = _dataDict
        }
    }
}

// MARK: - Mock Request Headers

struct MockRequestHeaders: RequestHeaders {
    let additionalHeaders: [String: String]
}

// MARK: - Mock Observer for Integration Tests

final class IntegrationMockObserver: GraphQLNetworkObserver {
    struct Context: Sendable {
        let timestamp: Date
    }

    var capturedRequests: [URLRequest] = []
    var capturedResponses: [(response: HTTPURLResponse?, data: Data?)] = []
    var capturedErrors: [Error] = []

    func willSendRequest(_ request: URLRequest) -> Context {
        capturedRequests.append(request)
        return Context(timestamp: Date())
    }

    func didReceiveResponse(for request: URLRequest, response: HTTPURLResponse?, data: Data?, context: Context) {
        capturedResponses.append((response, data))
    }

    func didFail(request: URLRequest, error: Error, context: Context) {
        capturedErrors.append(error)
    }
}

// MARK: - Integration Tests

final class GraphQLAPIAdapterIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// Creates a URLSessionConfiguration that uses MockURLProtocol
    private func mockSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }

    // MARK: - Default Headers Tests

    func testObserverReceivesDefaultHeaders() {
        let expectation = expectation(description: "Request completed")

        let observer = IntegrationMockObserver()
        let defaultHeaders = [
            "X-API-Key": "test-api-key",
            "X-Client-Version": "1.0.0"
        ]

        let adapter = GraphQLAPIAdapter(
            url: URL(string: "https://api.example.com/graphql")!,
            urlSessionConfiguration: mockSessionConfiguration(),
            defaultHeaders: defaultHeaders,
            networkObservers: [observer]
        )

        _ = adapter.fetch(query: MockQuery(), context: nil, queue: .main) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Verify observer captured the request
        XCTAssertEqual(observer.capturedRequests.count, 1)

        guard let capturedRequest = observer.capturedRequests.first else {
            XCTFail("No request captured")
            return
        }

        // Verify default headers are present
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "X-API-Key"), "test-api-key")
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "X-Client-Version"), "1.0.0")
    }

    func testObserverReceivesContextHeaders() {
        let expectation = expectation(description: "Request completed")

        let observer = IntegrationMockObserver()
        let contextHeaders = MockRequestHeaders(additionalHeaders: [
            "Authorization": "Bearer test-token",
            "X-Request-ID": "request-123"
        ])

        let adapter = GraphQLAPIAdapter(
            url: URL(string: "https://api.example.com/graphql")!,
            urlSessionConfiguration: mockSessionConfiguration(),
            defaultHeaders: [:],
            networkObservers: [observer]
        )

        _ = adapter.fetch(query: MockQuery(), context: contextHeaders, queue: .main) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Verify observer captured the request
        XCTAssertEqual(observer.capturedRequests.count, 1)

        guard let capturedRequest = observer.capturedRequests.first else {
            XCTFail("No request captured")
            return
        }

        // Verify context headers are present
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "X-Request-ID"), "request-123")
    }

    func testObserverReceivesBothDefaultAndContextHeaders() {
        let expectation = expectation(description: "Request completed")

        let observer = IntegrationMockObserver()
        let defaultHeaders = [
            "X-API-Key": "api-key-456",
            "Accept-Language": "en-US"
        ]
        let contextHeaders = MockRequestHeaders(additionalHeaders: [
            "Authorization": "Bearer context-token",
            "X-Trace-ID": "trace-789"
        ])

        let adapter = GraphQLAPIAdapter(
            url: URL(string: "https://api.example.com/graphql")!,
            urlSessionConfiguration: mockSessionConfiguration(),
            defaultHeaders: defaultHeaders,
            networkObservers: [observer]
        )

        _ = adapter.fetch(query: MockQuery(), context: contextHeaders, queue: .main) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        guard let capturedRequest = observer.capturedRequests.first else {
            XCTFail("No request captured")
            return
        }

        // Verify both default and context headers are present
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "X-API-Key"), "api-key-456")
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "Accept-Language"), "en-US")
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "Authorization"), "Bearer context-token")
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "X-Trace-ID"), "trace-789")
    }

    // MARK: - Multiple Observers Tests

    func testMultipleObserversAllReceiveHeaders() {
        let expectation = expectation(description: "Request completed")

        let observer1 = IntegrationMockObserver()
        let observer2 = IntegrationMockObserver()
        let observer3 = IntegrationMockObserver()

        let defaultHeaders = ["X-Shared-Header": "shared-value"]

        let adapter = GraphQLAPIAdapter(
            url: URL(string: "https://api.example.com/graphql")!,
            urlSessionConfiguration: mockSessionConfiguration(),
            defaultHeaders: defaultHeaders,
            networkObservers: [observer1, observer2, observer3]
        )

        _ = adapter.fetch(query: MockQuery(), context: nil, queue: .main) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Verify all observers captured the request with headers
        for (index, observer) in [observer1, observer2, observer3].enumerated() {
            XCTAssertEqual(observer.capturedRequests.count, 1, "Observer \(index + 1) should have captured 1 request")

            guard let capturedRequest = observer.capturedRequests.first else {
                XCTFail("Observer \(index + 1) did not capture request")
                continue
            }

            XCTAssertEqual(
                capturedRequest.value(forHTTPHeaderField: "X-Shared-Header"),
                "shared-value",
                "Observer \(index + 1) should see the shared header"
            )
        }
    }

    // MARK: - Apollo Headers Tests

    func testObserverReceivesApolloHeaders() {
        let expectation = expectation(description: "Request completed")

        let observer = IntegrationMockObserver()

        let adapter = GraphQLAPIAdapter(
            url: URL(string: "https://api.example.com/graphql")!,
            urlSessionConfiguration: mockSessionConfiguration(),
            defaultHeaders: [:],
            networkObservers: [observer]
        )

        _ = adapter.fetch(query: MockQuery(), context: nil, queue: .main) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        guard let capturedRequest = observer.capturedRequests.first else {
            XCTFail("No request captured")
            return
        }

        // Verify Apollo automatically adds these headers
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "X-APOLLO-OPERATION-NAME"), "MockQuery")
        XCTAssertNotNil(capturedRequest.value(forHTTPHeaderField: "Content-Type"))
    }

}
