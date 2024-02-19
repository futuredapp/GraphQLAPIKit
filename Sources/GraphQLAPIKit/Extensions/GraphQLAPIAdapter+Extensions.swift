import Apollo
import ApolloAPI
import Foundation

public extension GraphQLAPIAdapterProtocol {
    func fetch<Query: GraphQLQuery>(
        query: Query,
        context: RequestHeaders?,
        queue: DispatchQueue
    ) async -> Result<Query.Data, GraphQLAPIAdapterError> {
        let cancellable = CancellableContinuation<Query.Data>()

        return await withTaskCancellationHandler { [weak self] in
            await withUnsafeContinuation { continuation in
                cancellable.requestWith(continuation) {
                    self?.fetch(query: query, context: context, queue: queue, resultHandler: continuation.resume)
                }
            }
        } onCancel: {
            cancellable.cancel()
        }
    }

    func perform<Mutation: GraphQLMutation>(
        mutation: Mutation,
        context: RequestHeaders?,
        queue: DispatchQueue
    ) async -> Result<Mutation.Data, GraphQLAPIAdapterError> {
        let cancellable = CancellableContinuation<Mutation.Data>()

        return await withTaskCancellationHandler { [weak self] in
            await withUnsafeContinuation { continuation in
                cancellable.requestWith(continuation) {
                    self?.perform(mutation: mutation, context: context, queue: queue, resultHandler: continuation.resume)
                }
            }
        } onCancel: {
            cancellable.cancel()
        }
    }
}

private final class CancellableContinuation<T> {
    private var continuation: UnsafeContinuation<Result<T, GraphQLAPIAdapterError>, Never>?
    private var cancellable: Cancellable?

    func requestWith(
        _ continuation: UnsafeContinuation<Result<T, GraphQLAPIAdapterError>, Never>,
        cancellable: @escaping () -> Cancellable?
    ) {
        self.continuation = continuation
        self.cancellable = cancellable()
    }

    func resume(returning value: Result<T, GraphQLAPIAdapterError>) {
        continuation?.resume(returning: value)
        continuation = nil
        cancellable = nil
    }

    func cancel() {
        continuation?.resume(returning: .failure(GraphQLAPIAdapterError.cancelled))
        continuation = nil

        cancellable?.cancel()
        cancellable = nil
    }
}
