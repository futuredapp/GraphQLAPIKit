@_spi(Execution)
@_spi(Unsafe)
import ApolloAPI
import Foundation
@testable import GraphQLAPIKit
import XCTest

final class GraphQLQueryRetryTests: XCTestCase {
    private var testURL: URL {
        guard let url = URL(string: "https://proof.example/graphql") else {
            preconditionFailure("Invalid test URL")
        }
        return url
    }

    func testRetriesNetworkConnectionLost() async throws {
        StubURLProtocol.reset(responses: [
            .failure(.networkConnectionLost),
            .success
        ])

        let data = try await makeAdapter(policy: .transientNetworkFailures)
            .fetch(query: TestQuery())

        XCTAssertEqual(data.value, "ok")
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func testRetriesTimedOut() async throws {
        StubURLProtocol.reset(responses: [
            .failure(.timedOut),
            .success
        ])

        let data = try await makeAdapter(policy: .transientNetworkFailures)
            .fetch(query: TestQuery())

        XCTAssertEqual(data.value, "ok")
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func testDoesNotRetryByDefault() async {
        StubURLProtocol.reset(responses: [
            .failure(.networkConnectionLost),
            .success
        ])

        do {
            _ = try await makeAdapter().fetch(query: TestQuery())
            XCTFail("Expected the query to fail")
        } catch {
            assertAdapterError(error, wraps: .networkConnectionLost)
        }

        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testDoesNotRetryOtherURLErrors() async {
        StubURLProtocol.reset(responses: [
            .failure(.notConnectedToInternet),
            .success
        ])

        do {
            _ = try await makeAdapter(policy: .transientNetworkFailures)
                .fetch(query: TestQuery())
            XCTFail("Expected the query to fail")
        } catch {
            assertAdapterError(error, wraps: .notConnectedToInternet)
        }

        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testStopsAfterConfiguredRetryCount() async {
        StubURLProtocol.reset(responses: [
            .failure(.timedOut),
            .failure(.timedOut),
            .failure(.timedOut),
            .success
        ])
        let policy = GraphQLQueryRetryPolicy(
            maxRetryCount: 2,
            retryableURLErrorCodes: [.timedOut]
        )

        do {
            _ = try await makeAdapter(policy: policy).fetch(query: TestQuery())
            XCTFail("Expected the query to fail")
        } catch {
            assertAdapterError(error, wraps: .timedOut)
        }

        XCTAssertEqual(StubURLProtocol.requestCount, 3)
    }

    func testDoesNotRetryMutations() async {
        StubURLProtocol.reset(responses: [
            .failure(.networkConnectionLost),
            .success
        ])

        do {
            _ = try await makeAdapter(policy: .transientNetworkFailures)
                .perform(mutation: TestMutation())
            XCTFail("Expected the mutation to fail")
        } catch {
            assertAdapterError(error, wraps: .networkConnectionLost)
        }

        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    private func makeAdapter(
        policy: GraphQLQueryRetryPolicy = .none
    ) -> GraphQLAPIAdapter {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [StubURLProtocol.self]
        return GraphQLAPIAdapter(
            configuration: GraphQLAPIConfiguration(
                url: testURL,
                urlSessionConfiguration: sessionConfiguration,
                queryRetryPolicy: policy
            )
        )
    }

    private func assertAdapterError(
        _ error: Error,
        wraps expectedCode: URLError.Code
    ) {
        guard let adapterError = error as? GraphQLAPIAdapterError else {
            XCTFail("Expected GraphQLAPIAdapterError, received \(error)")
            return
        }

        let underlyingError: Error
        switch adapterError {
        case let .network(_, error),
             let .connection(error),
             let .unhandled(error):
            underlyingError = error
        case .cancelled, .graphQl:
            XCTFail("Expected an error with an underlying URL error")
            return
        }

        let urlError = underlyingError as NSError
        XCTAssertEqual(urlError.domain, NSURLErrorDomain)
        XCTAssertEqual(urlError.code, expectedCode.rawValue)
    }
}

private enum StubResponse {
    case failure(URLError.Code)
    case success
}

private final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var responses: [StubResponse] = []
    private static var storedRequestCount = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedRequestCount
    }

    static func reset(responses: [StubResponse]) {
        lock.lock()
        defer { lock.unlock() }
        self.responses = responses
        storedRequestCount = 0
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        switch Self.nextResponse {
        case let .failure(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .success:
            sendSuccess()
        }
    }

    override func stopLoading() {
    }

    private func sendSuccess() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: "HTTP/2",
                  headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
            return
        }
        let data = Data(#"{"data":{"value":"ok"}}"#.utf8)

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static var nextResponse: StubResponse {
        lock.lock()
        defer { lock.unlock() }
        storedRequestCount += 1

        guard !responses.isEmpty else {
            return .success
        }
        return responses.removeFirst()
    }
}

// swiftlint:disable identifier_name
private struct TestQuery: GraphQLQuery {
    static let operationName = "TestQuery"
    static let operationDocument: OperationDocument = .init(
        definition: .init(#"query TestQuery { value }"#)
    )

    struct Data: TestSelectionSet {
        let __data: DataDict

        init(_dataDict: DataDict) {
            __data = _dataDict
        }

        static var __parentType: any ParentType {
            TestObjects.Query
        }

        static var __selections: [Selection] {
            [.field("value", String.self)]
        }

        static var __fulfilledFragments: [any SelectionSet.Type] {
            [Data.self]
        }

        var value: String {
            __data["value"]
        }
    }
}

private struct TestMutation: GraphQLMutation {
    static let operationName = "TestMutation"
    static let operationDocument: OperationDocument = .init(
        definition: .init(#"mutation TestMutation { value }"#)
    )

    struct Data: TestSelectionSet {
        let __data: DataDict

        init(_dataDict: DataDict) {
            __data = _dataDict
        }

        static var __parentType: any ParentType {
            TestObjects.Mutation
        }

        static var __selections: [Selection] {
            [.field("value", String.self)]
        }

        static var __fulfilledFragments: [any SelectionSet.Type] {
            [Data.self]
        }

        var value: String {
            __data["value"]
        }
    }
}
// swiftlint:enable identifier_name

private protocol TestSelectionSet: SelectionSet & RootSelectionSet where Schema == TestSchemaMetadata {}

private enum TestSchemaMetadata: SchemaMetadata {
    static let configuration: any SchemaConfiguration.Type = TestSchemaConfiguration.self

    static func objectType(forTypename typename: String) -> Object? {
        switch typename {
        case "Mutation":
            return TestObjects.Mutation
        case "Query":
            return TestObjects.Query
        default:
            return nil
        }
    }
}

private enum TestSchemaConfiguration: SchemaConfiguration {
    static func cacheKeyInfo(for type: Object, object: ObjectData) -> CacheKeyInfo? {
        nil
    }
}

private enum TestObjects {
    static let Mutation = Object(
        typename: "Mutation",
        implementedInterfaces: [],
        keyFields: nil
    )

    static let Query = Object(
        typename: "Query",
        implementedInterfaces: [],
        keyFields: nil
    )
}
