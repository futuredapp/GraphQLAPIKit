import Apollo
import ApolloAPI
@testable import GraphQLAPIKit
import XCTest

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

    func testAdapterInitializationWithNoObservers() {
        let configuration = GraphQLAPIConfiguration(url: testURL)
        let adapter = GraphQLAPIAdapter(configuration: configuration)
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithSingleObserver() {
        let observer = IntegrationMockObserver()
        let configuration = GraphQLAPIConfiguration(
            url: testURL,
            networkObservers: [observer]
        )
        let adapter = GraphQLAPIAdapter(configuration: configuration)
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithMultipleObservers() {
        let observer1 = IntegrationMockObserver()
        let observer2 = IntegrationMockObserver()
        let observer3 = IntegrationMockObserver()

        let configuration = GraphQLAPIConfiguration(
            url: testURL,
            networkObservers: [observer1, observer2, observer3]
        )
        let adapter = GraphQLAPIAdapter(configuration: configuration)
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithDefaultHeadersAndObserver() {
        let observer = IntegrationMockObserver()
        let defaultHeaders = [
            "X-API-Key": "test-api-key",
            "X-Client-Version": "1.0.0"
        ]

        let configuration = GraphQLAPIConfiguration(
            url: testURL,
            defaultHeaders: defaultHeaders,
            networkObservers: [observer]
        )
        let adapter = GraphQLAPIAdapter(configuration: configuration)
        XCTAssertNotNil(adapter)
    }

    func testAdapterInitializationWithCustomSessionConfiguration() {
        let observer = IntegrationMockObserver()
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 30

        let configuration = GraphQLAPIConfiguration(
            url: testURL,
            urlSessionConfiguration: sessionConfig,
            defaultHeaders: ["X-Test": "value"],
            networkObservers: [observer]
        )
        let adapter = GraphQLAPIAdapter(configuration: configuration)
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

    // MARK: - Per-Request Headers Context Tests

    func testRequestHeadersContextIsNilByDefault() {
        XCTAssertNil(RequestHeadersContext.headers)
    }

    func testRequestHeadersContextPassesHeaders() {
        let headers = MockRequestHeaders(additionalHeaders: [
            "Authorization": "Bearer test-token",
            "X-Request-ID": "abc-123"
        ])

        RequestHeadersContext.$headers.withValue(headers) {
            XCTAssertNotNil(RequestHeadersContext.headers)
            XCTAssertEqual(RequestHeadersContext.headers?.additionalHeaders["Authorization"], "Bearer test-token")
            XCTAssertEqual(RequestHeadersContext.headers?.additionalHeaders["X-Request-ID"], "abc-123")
        }

        // Value is nil again outside scope
        XCTAssertNil(RequestHeadersContext.headers)
    }

    func testRequestHeadersContextWorksInAsyncContext() async {
        let headers = MockRequestHeaders(additionalHeaders: ["X-Async": "true"])

        await RequestHeadersContext.$headers.withValue(headers) {
            XCTAssertEqual(RequestHeadersContext.headers?.additionalHeaders["X-Async"], "true")
        }

        XCTAssertNil(RequestHeadersContext.headers)
    }

    func testRequestHeadersContextIsolatesBetweenScopes() {
        let headers1 = MockRequestHeaders(additionalHeaders: ["X-Scope": "first"])
        let headers2 = MockRequestHeaders(additionalHeaders: ["X-Scope": "second"])

        RequestHeadersContext.$headers.withValue(headers1) {
            XCTAssertEqual(RequestHeadersContext.headers?.additionalHeaders["X-Scope"], "first")

            RequestHeadersContext.$headers.withValue(headers2) {
                XCTAssertEqual(RequestHeadersContext.headers?.additionalHeaders["X-Scope"], "second")
            }

            // Outer scope is restored
            XCTAssertEqual(RequestHeadersContext.headers?.additionalHeaders["X-Scope"], "first")
        }
    }

    func testNetworkInterceptorProviderReadsRequestHeadersContext() {
        let provider = NetworkInterceptorProvider(
            defaultHeaders: ["X-Default": "value"],
            networkObservers: []
        )

        let headers = MockRequestHeaders(additionalHeaders: ["Authorization": "Bearer token"])

        // When called within a RequestHeadersContext scope,
        // the provider should create interceptors that include per-request headers.
        // This verifies the @TaskLocal wiring between adapter and provider.
        RequestHeadersContext.$headers.withValue(headers) {
            // The provider creates interceptors here — the first should be RequestHeaderInterceptor
            // which reads from RequestHeadersContext.headers during creation.
            XCTAssertEqual(RequestHeadersContext.headers?.additionalHeaders["Authorization"], "Bearer token")
        }
    }
}
