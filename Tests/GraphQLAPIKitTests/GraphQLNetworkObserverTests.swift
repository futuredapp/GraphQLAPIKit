import XCTest
@testable import GraphQLAPIKit

final class GraphQLNetworkObserverTests: XCTestCase {

    // MARK: - GraphQLOperationContext Tests

    func testOperationContextInitialization() {
        let url = URL(string: "https://api.example.com/graphql")!
        let context = GraphQLOperationContext(
            operationName: "GetUser",
            operationType: "query",
            url: url
        )

        XCTAssertEqual(context.operationName, "GetUser")
        XCTAssertEqual(context.operationType, "query")
        XCTAssertEqual(context.url, url)
    }

    func testOperationContextSendable() {
        // Verify GraphQLOperationContext can be sent across actors
        let url = URL(string: "https://api.example.com/graphql")!
        let context = GraphQLOperationContext(
            operationName: "CreatePost",
            operationType: "mutation",
            url: url
        )

        Task {
            // This should compile without issues if Sendable conformance is correct
            await verifyContextOnAnotherActor(context)
        }
    }

    @MainActor
    private func verifyContextOnAnotherActor(_ context: GraphQLOperationContext) async {
        XCTAssertEqual(context.operationType, "mutation")
    }

    // MARK: - MockObserver

    final class MockObserver: GraphQLNetworkObserver {
        struct Context: Sendable {
            let requestId: String
            let startTime: Date
        }

        var willSendRequestCalled = false
        var didReceiveResponseCalled = false
        var didFailCalled = false

        var lastOperationContext: GraphQLOperationContext?
        var lastResponse: HTTPURLResponse?
        var lastData: Data?
        var lastError: Error?

        func willSendRequest(_ context: GraphQLOperationContext) -> Context {
            willSendRequestCalled = true
            lastOperationContext = context
            return Context(requestId: UUID().uuidString, startTime: Date())
        }

        func didReceiveResponse(
            for context: GraphQLOperationContext,
            response: HTTPURLResponse?,
            data: Data?,
            observerContext: Context
        ) {
            didReceiveResponseCalled = true
            lastResponse = response
            lastData = data
        }

        func didFail(for context: GraphQLOperationContext, error: Error, observerContext: Context) {
            didFailCalled = true
            lastError = error
        }
    }

    // MARK: - GraphQLRequestToken Tests

    func testRequestTokenCallsWillSendRequestImmediately() {
        let observer = MockObserver()
        let context = GraphQLOperationContext(
            operationName: "TestQuery",
            operationType: "query",
            url: URL(string: "https://example.com")!
        )

        XCTAssertFalse(observer.willSendRequestCalled)

        _ = GraphQLRequestToken(observer: observer, context: context)

        XCTAssertTrue(observer.willSendRequestCalled)
        XCTAssertEqual(observer.lastOperationContext?.operationName, "TestQuery")
    }

    func testRequestTokenDidReceiveResponse() {
        let observer = MockObserver()
        let context = GraphQLOperationContext(
            operationName: "TestQuery",
            operationType: "query",
            url: URL(string: "https://example.com")!
        )

        let token = GraphQLRequestToken(observer: observer, context: context)

        XCTAssertFalse(observer.didReceiveResponseCalled)

        token.didReceiveResponse(nil, nil)

        XCTAssertTrue(observer.didReceiveResponseCalled)
    }

    func testRequestTokenDidFail() {
        let observer = MockObserver()
        let context = GraphQLOperationContext(
            operationName: "TestMutation",
            operationType: "mutation",
            url: URL(string: "https://example.com")!
        )

        let token = GraphQLRequestToken(observer: observer, context: context)

        XCTAssertFalse(observer.didFailCalled)

        let testError = NSError(domain: "Test", code: 123)
        token.didFail(testError)

        XCTAssertTrue(observer.didFailCalled)
        XCTAssertNotNil(observer.lastError)
    }

    func testRequestTokenWeakReference() {
        var observer: MockObserver? = MockObserver()
        let context = GraphQLOperationContext(
            operationName: "TestQuery",
            operationType: "query",
            url: URL(string: "https://example.com")!
        )

        let token = GraphQLRequestToken(observer: observer!, context: context)

        XCTAssertTrue(observer!.willSendRequestCalled)

        // Release the observer
        observer = nil

        // Token should not crash when observer is deallocated
        token.didReceiveResponse(nil, nil)
        token.didFail(NSError(domain: "Test", code: 0))
    }

    // MARK: - Multiple Observers Tests

    func testMultipleObserversAllReceiveCallbacks() {
        let observer1 = MockObserver()
        let observer2 = MockObserver()
        let observer3 = MockObserver()

        let context = GraphQLOperationContext(
            operationName: "MultiTest",
            operationType: "query",
            url: URL(string: "https://example.com")!
        )

        let tokens = [observer1, observer2, observer3].map {
            GraphQLRequestToken(observer: $0, context: context)
        }

        // All should have willSendRequest called
        XCTAssertTrue(observer1.willSendRequestCalled)
        XCTAssertTrue(observer2.willSendRequestCalled)
        XCTAssertTrue(observer3.willSendRequestCalled)

        // Call didReceiveResponse on all
        tokens.forEach { $0.didReceiveResponse(nil, nil) }

        XCTAssertTrue(observer1.didReceiveResponseCalled)
        XCTAssertTrue(observer2.didReceiveResponseCalled)
        XCTAssertTrue(observer3.didReceiveResponseCalled)
    }
}
