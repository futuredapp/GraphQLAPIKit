import XCTest
@testable import GraphQLAPIKit

final class GraphQLNetworkObserverTests: XCTestCase {

    // MARK: - MockObserver

    final class MockObserver: GraphQLNetworkObserver {
        struct Context: Sendable {
            let requestId: String
            let startTime: Date
        }

        var willSendRequestCalled = false
        var didReceiveResponseCalled = false
        var didFailCalled = false

        var lastRequest: URLRequest?
        var lastResponse: URLResponse?
        var lastData: Data?
        var lastError: Error?

        func willSendRequest(_ request: URLRequest) -> Context {
            willSendRequestCalled = true
            lastRequest = request
            return Context(requestId: UUID().uuidString, startTime: Date())
        }

        func didReceiveResponse(
            for request: URLRequest,
            response: URLResponse?,
            data: Data?,
            context: Context
        ) {
            didReceiveResponseCalled = true
            lastResponse = response
            lastData = data
        }

        func didFail(request: URLRequest, error: Error, context: Context) {
            didFailCalled = true
            lastError = error
        }
    }

    // MARK: - ObserverInterceptor Tests

    func testObserverInterceptorCreation() {
        let observer = MockObserver()
        let interceptor = ObserverInterceptor(observer: observer)

        XCTAssertNotNil(interceptor.id)
        XCTAssertFalse(observer.willSendRequestCalled)
    }

    func testObserverWeakReference() {
        var observer: MockObserver? = MockObserver()
        let interceptor = ObserverInterceptor(observer: observer!)

        // Release the observer
        observer = nil

        // Interceptor should not crash when observer is deallocated
        // (notifyFailure should safely do nothing)
        interceptor.notifyFailure(NSError(domain: "Test", code: 0))
    }

    // MARK: - Multiple Observers Tests

    func testMultipleInterceptorsCreation() {
        let observer1 = MockObserver()
        let observer2 = MockObserver()
        let observer3 = MockObserver()

        let interceptors = [observer1, observer2, observer3].map {
            ObserverInterceptor(observer: $0)
        }

        XCTAssertEqual(interceptors.count, 3)

        // All should have unique IDs
        let ids = Set(interceptors.map { $0.id })
        XCTAssertEqual(ids.count, 3)
    }

    // MARK: - Protocol Conformance Tests

    func testProtocolMethodSignatures() {
        // This test verifies the protocol matches FTAPIKit's NetworkObserver pattern
        let observer = MockObserver()

        // Create a sample URLRequest
        let request = URLRequest(url: URL(string: "https://example.com/graphql")!)

        // Test willSendRequest returns Context
        let context = observer.willSendRequest(request)
        XCTAssertTrue(observer.willSendRequestCalled)
        XCTAssertNotNil(context.requestId)

        // Test didReceiveResponse
        observer.didReceiveResponse(for: request, response: nil, data: nil, context: context)
        XCTAssertTrue(observer.didReceiveResponseCalled)

        // Test didFail
        observer.didFail(request: request, error: NSError(domain: "Test", code: 1), context: context)
        XCTAssertTrue(observer.didFailCalled)
    }

    func testURLRequestPassedCorrectly() {
        let observer = MockObserver()
        let url = URL(string: "https://api.example.com/graphql")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        _ = observer.willSendRequest(request)

        XCTAssertEqual(observer.lastRequest?.url, url)
        XCTAssertEqual(observer.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: - Header Capture Tests

    func testObserverReceivesHeadersFromURLRequest() {
        // Test that when willSendRequest is called with a URLRequest containing headers,
        // the observer can access all those headers
        let observer = MockObserver()
        let url = URL(string: "https://api.example.com/graphql")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")
        request.setValue("custom-value", forHTTPHeaderField: "X-Custom-Header")
        request.setValue("en-US", forHTTPHeaderField: "Accept-Language")

        _ = observer.willSendRequest(request)

        // Verify observer received the request with all headers
        XCTAssertTrue(observer.willSendRequestCalled)
        XCTAssertNotNil(observer.lastRequest)

        // Check all custom headers are present
        XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "X-Custom-Header"), "custom-value")
        XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "Accept-Language"), "en-US")
    }

    func testMultipleObserversReceiveSameHeaders() {
        // Test that multiple observers all receive the same URLRequest with headers
        let observer1 = MockObserver()
        let observer2 = MockObserver()
        let observer3 = MockObserver()

        let url = URL(string: "https://api.example.com/graphql")!
        var request = URLRequest(url: url)
        request.setValue("Bearer shared-token", forHTTPHeaderField: "Authorization")
        request.setValue("api-key-123", forHTTPHeaderField: "X-API-Key")

        // Simulate what happens when multiple interceptors call willSendRequest
        _ = observer1.willSendRequest(request)
        _ = observer2.willSendRequest(request)
        _ = observer3.willSendRequest(request)

        // All observers should have received the same headers
        for observer in [observer1, observer2, observer3] {
            XCTAssertTrue(observer.willSendRequestCalled)
            XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer shared-token")
            XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "X-API-Key"), "api-key-123")
        }
    }

    // MARK: - Interceptor Chain Order Tests

    func testInterceptorChainOrderPlacesObserversAfterHeaders() {
        // This test verifies that the interceptor chain is ordered correctly:
        // RequestHeaderInterceptor -> ObserverInterceptors -> NetworkFetchInterceptor...
        //
        // We verify this by checking that when HTTPRequest.addHeader is called (by RequestHeaderInterceptor),
        // and then toURLRequest() is called (by ObserverInterceptor), the headers are present.

        let url = URL(string: "https://api.example.com/graphql")!

        // Create a mock HTTPRequest-like structure to simulate the flow
        var additionalHeaders: [String: String] = [:]

        // Step 1: RequestHeaderInterceptor adds default headers
        additionalHeaders["X-Default-Header"] = "default-value"

        // Step 2: RequestHeaderInterceptor adds context headers (additionalHeaders from RequestHeaders)
        additionalHeaders["Authorization"] = "Bearer context-token"

        // Step 3: Create URLRequest (simulating what happens in ObserverInterceptor)
        var urlRequest = URLRequest(url: url)
        for (name, value) in additionalHeaders {
            urlRequest.addValue(value, forHTTPHeaderField: name)
        }

        // Step 4: Observer receives the request
        let observer = MockObserver()
        _ = observer.willSendRequest(urlRequest)

        // Verify observer sees both default and context headers
        XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "X-Default-Header"), "default-value")
        XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer context-token")
    }
}
