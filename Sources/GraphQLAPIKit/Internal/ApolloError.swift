import Apollo

struct ApolloError: Error {
    let errors: [GraphQLError]
}
