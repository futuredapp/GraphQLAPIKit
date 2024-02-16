import Apollo

/// Additional headers to the request such as `Authorization`, `Accept-Language` or `Content-Type`
public protocol RequestHeaders: RequestContext {
    var additionalHeaders: [String: String] { get }
}
