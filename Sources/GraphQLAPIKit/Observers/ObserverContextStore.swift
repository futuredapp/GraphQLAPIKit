import Foundation

/// Actor that stores observer contexts keyed by request identifier.
/// Enables two interceptor instances to share state across the interceptor chain.
actor ObserverContextStore<Context> {
    private var contexts: [String: Context] = [:]

    func store(_ context: Context, for requestId: String) {
        contexts[requestId] = context
    }

    func retrieve(for requestId: String) -> Context? {
        contexts.removeValue(forKey: requestId)
    }
}
