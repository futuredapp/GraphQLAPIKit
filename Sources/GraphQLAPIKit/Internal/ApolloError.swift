import Apollo

struct ApolloError: Error {
    let errors: [Apollo.GraphQLError]
}
