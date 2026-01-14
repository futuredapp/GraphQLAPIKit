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

    // MARK: - Observer Protocol Tests

    func testProtocolMethodSignatures() {
        let observer = MockObserver()
        let url = URL(string: "https://api.example.com/graphql")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")

        // Test willSendRequest returns Context
        let context = observer.willSendRequest(request)
        XCTAssertTrue(observer.willSendRequestCalled)
        XCTAssertNotNil(context.requestId)
        XCTAssertEqual(observer.lastRequest?.url, url)
        XCTAssertEqual(observer.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(observer.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")

        // Test didReceiveResponse
        observer.didReceiveResponse(for: request, response: nil, data: nil, context: context)
        XCTAssertTrue(observer.didReceiveResponseCalled)

        // Test didFail
        observer.didFail(request: request, error: NSError(domain: "Test", code: 1), context: context)
        XCTAssertTrue(observer.didFailCalled)
    }

    func testObserverContextContainsTimingInfo() {
        let observer = MockObserver()
        let url = URL(string: "https://api.example.com/graphql")!
        let request = URLRequest(url: url)

        let beforeTime = Date()
        let context = observer.willSendRequest(request)
        let afterTime = Date()

        // Verify context contains start time within expected range
        XCTAssertGreaterThanOrEqual(context.startTime, beforeTime)
        XCTAssertLessThanOrEqual(context.startTime, afterTime)
    }

    func testObserverContextRequestIdIsUnique() {
        let observer = MockObserver()
        let url = URL(string: "https://api.example.com/graphql")!
        let request = URLRequest(url: url)

        let context1 = observer.willSendRequest(request)
        let context2 = observer.willSendRequest(request)
        let context3 = observer.willSendRequest(request)

        XCTAssertNotEqual(context1.requestId, context2.requestId)
        XCTAssertNotEqual(context2.requestId, context3.requestId)
        XCTAssertNotEqual(context1.requestId, context3.requestId)
    }
}
