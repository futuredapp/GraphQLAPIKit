import Apollo
import ApolloAPI
import XCTest
@testable import GraphQLAPIKit

// MARK: - Mock Request Headers

struct MockRequestHeaders: RequestHeaders {
    let additionalHeaders: [String: String]
}

// MARK: - Mock Observer for Integration Tests

final class IntegrationMockObserver: GraphQLNetworkObserver, @unchecked Sendable {
    struct Context: Sendable {
        let timestamp: Date
    }

    var capturedRequests: [URLRequest] = []
    var capturedResponses: [(response: URLResponse?, data: Data?)] = []
    var capturedErrors: [Error] = []

    func willSendRequest(_ request: URLRequest) -> Context {
        capturedRequests.append(request)
        return Context(timestamp: Date())
    }

    func didReceiveResponse(for request: URLRequest, response: URLResponse?, data: Data?, context: Context) {
        capturedResponses.append((response, data))
    }

    func didFail(request: URLRequest, error: Error, context: Context) {
        capturedErrors.append(error)
    }
}

// MARK: - Integration Tests

final class GraphQLAPIAdapterIntegrationTests: XCTestCase {
    let testURL = URL(string: "https://api.example.com/graphql")!

    // MARK: - Initialization Tests

    func testAdapterInitializationWithSingleObserver() {
        let observer = IntegrationMockObserver()
        let adapter = GraphQLAPIAdapter(
            url: testURL,
            networkObservers: observer
        )
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithMultipleObservers() {
        let observer1 = IntegrationMockObserver()
        let observer2 = IntegrationMockObserver()
        let observer3 = IntegrationMockObserver()

        let adapter = GraphQLAPIAdapter(
            url: testURL,
            networkObservers: observer1, observer2, observer3
        )
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithDefaultHeadersAndObserver() {
        let observer = IntegrationMockObserver()
        let defaultHeaders = [
            "X-API-Key": "test-api-key",
            "X-Client-Version": "1.0.0"
        ]

        let adapter = GraphQLAPIAdapter(
            url: testURL,
            defaultHeaders: defaultHeaders,
            networkObservers: observer
        )
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithCustomSessionConfiguration() {
        let observer = IntegrationMockObserver()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30

        let adapter = GraphQLAPIAdapter(
            url: testURL,
            urlSessionConfiguration: config,
            defaultHeaders: ["X-Test": "value"],
            networkObservers: observer
        )
        XCTAssertNotNil(adapter)
    }

    // MARK: - Observer Protocol Tests

    func testObserverCallbackSequence() {
        let observer = IntegrationMockObserver()
        let url = URL(string: "https://api.example.com/graphql")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Simulate the callback sequence
        let context = observer.willSendRequest(request)
        XCTAssertEqual(observer.capturedRequests.count, 1)

        observer.didReceiveResponse(for: request, response: nil, data: nil, context: context)
        XCTAssertEqual(observer.capturedResponses.count, 1)
    }

    func testObserverErrorCallback() {
        let observer = IntegrationMockObserver()
        let url = URL(string: "https://api.example.com/graphql")!
        let request = URLRequest(url: url)

        let context = observer.willSendRequest(request)
        let error = NSError(domain: "TestDomain", code: 500, userInfo: nil)
        observer.didFail(request: request, error: error, context: context)

        XCTAssertEqual(observer.capturedErrors.count, 1)
    }
}
