import Foundation

/// Additional headers to the request such as `Authorization`, `Accept-Language` or `Content-Type`
public protocol RequestHeaders: Sendable {
    var additionalHeaders: [String: String] { get }
}
