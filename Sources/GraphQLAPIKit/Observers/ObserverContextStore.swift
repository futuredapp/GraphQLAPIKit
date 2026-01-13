import Foundation
import os

/// Thread-safe store for observer contexts keyed by request identifier.
/// Enables two interceptor instances to share state across the interceptor chain.
final class ObserverContextStore<Context: Sendable>: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [String: Context]())

    func store(_ context: Context, for requestId: String) {
        state.withLock { $0[requestId] = context }
    }

    func retrieve(for requestId: String) -> Context? {
        state.withLock { $0.removeValue(forKey: requestId) }
    }
}
