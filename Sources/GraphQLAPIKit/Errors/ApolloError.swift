import Apollo

struct ApolloError: Error, Sendable {
    let errors: [Apollo.GraphQLError]
}
