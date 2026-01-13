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
        let contextStore = ObserverContextStore<MockObserver.Context>()

        let interceptor1 = ObserverInterceptor(observer: observer, contextStore: contextStore)
        let interceptor2 = ObserverInterceptor(observer: observer, contextStore: contextStore)

        XCTAssertNotNil(interceptor1.id)
        XCTAssertNotNil(interceptor2.id)
        XCTAssertNotEqual(interceptor1.id, interceptor2.id)
        XCTAssertFalse(observer.willSendRequestCalled)
    }

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

    // MARK: - Context Store Tests

    func testContextStoreOperations() async {
        let store = ObserverContextStore<String>()

        // Test store and retrieve
        await store.store("context-1", for: "request-1")
        await store.store("context-2", for: "request-2")
        await store.store("context-3", for: "request-3")

        // Retrieve in different order
        let context2 = await store.retrieve(for: "request-2")
        let context1 = await store.retrieve(for: "request-1")
        let context3 = await store.retrieve(for: "request-3")

        XCTAssertEqual(context1, "context-1")
        XCTAssertEqual(context2, "context-2")
        XCTAssertEqual(context3, "context-3")

        // Verify retrieve removes context
        let secondRetrieve = await store.retrieve(for: "request-1")
        XCTAssertNil(secondRetrieve)
    }
}
