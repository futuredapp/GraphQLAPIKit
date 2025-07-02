import Apollo
import ApolloAPI

public protocol InjectableInterceptor: ApolloInterceptor, Hashable {
    var placement: InterceptorPlacement { get }
    var specificOperations: [any GraphQLOperation.Type]? { get }
}

extension InjectableInterceptor {
    var specificOperations: [any GraphQLOperation.Type]? { nil }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public enum InterceptorPlacement: Equatable, Hashable {
    case beforeNetworkFetch(priority: Int)
    case afterNetworkFetch(priority: Int)

    var priority: Int {
        switch self {
        case let .beforeNetworkFetch(priority), let .afterNetworkFetch(priority):
            priority
        }
    }
}

public enum InterceptorPriority: Equatable, Hashable, Comparable {
    public static let high = 100
    public static let normal = 200
    public static let low = 300
}
