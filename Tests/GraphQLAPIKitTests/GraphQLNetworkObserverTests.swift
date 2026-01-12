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
        var lastResponse: HTTPURLResponse?
        var lastData: Data?
        var lastError: Error?

        func willSendRequest(_ request: URLRequest) -> Context {
            willSendRequestCalled = true
            lastRequest = request
            return Context(requestId: UUID().uuidString, startTime: Date())
        }

        func didReceiveResponse(
            for request: URLRequest,
            response: HTTPURLResponse?,
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
}
