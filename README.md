# GraphQLAPIKit

Lightweight GraphQL API client based on [Apollo iOS](https://github.com/apollographql/apollo-ios).
Developed to simplify [Futured](https://www.futured.app) in-house development of applications, that work with GraphQL APIs.

## Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- Apollo iOS 2.0.4

## Limitations

Currently there is no support for some Apollo's features:
- Apollo built-in cache
- Custom interceptors

Network observers are available for logging and analytics.

## Installation

Install or add following line to your dependencies:

```swift
.package(url: "https://github.com/futuredapp/GraphQLAPIKit.git", from: "1.0.0")
```

## Setup Your Project

**Make sure that `GraphQLAPIKit` is added as a package dependency to your project**

#### 1. Create `GraphQLGenerated` folder at your `ProjectName.xcodeproj` level

#### 2. Add Apollo configuration file

Add `apollo-codegen-config.json` file and add it to `GraphQLGenerated` folder.
Copy and paste json configuration to the newly created file:
```json
{
  "schemaName" : "GraphQLGenerated",
  "input" : {
    "operationSearchPaths" : [
      "**/*.graphql"
    ],
    "schemaSearchPaths" : [
      "./schema.json"
    ]
  },
  "output" : {
    "schemaTypes" : {
      "path" : "./",
      "moduleType" : {
        "swiftPackage": {}
      }
    },
    "operations" : {
      "inSchemaModule" : {}
    },
    "testMocks" : {
      "swiftPackage": {
        "targetName": "GraphQLGeneratedMocks"
      }
    }
  }
}
```
#### 3. Add schema file
Add GraphQL JSON schema to the `GraphQLGenerated` folder and name it `schema.json`.

#### 4. Add Queries And Mutations Folders
Add `Queries` and `Mutations` folders to `GraphQLGenerated` folder.

#### 5. Define Your first GraphQL Query Or Mutation
Add your first Query or Mutation and save it with `.graphql` extension to `Queries` or `Mutations` folders.

#### 6. Add Xcode Build Phase Script
At your main app's target add a new build phase named `Generate GraphQL Operations`.
Move your newly created build phase above the `Compile Sources` phase.
Add script:
```sh
SDKROOT=$(/usr/bin/xcrun --sdk macosx --show-sdk-path)
SWIFT_PACKAGES="${BUILD_DIR%/Build/*}/SourcePackages/checkouts"

${SWIFT_PACKAGES}/GraphQLAPIKit/Resources/apollo-ios-cli generate --path ./GraphQLGenerated/apollo-codegen-config.json
```

#### 7. Disable User Script Sandboxing
Go to your application main target's Build Settings and set `User Script Sandboxing` to `NO`

#### 8. Build your main target

#### 9. Add GraphQLGenerated local package
- Go to Xcode -> File -> Add Package Dependencies..
- Choose `Add Local...`
- Add `GraphQLGenerated` as local Swift Package.
Make sure, that `GraphQLGenerated` library was added to your main's target `Frameworks, Libraries, and Embedded Content` list.
For your project's test target add `GraphQLGeneratedMocks` library if necessary.

#### 10. Update `.gitignore` file
Add `*.graphql.swift` to your repository's git ignore file to ignore Apollo generated code.

**Content of generated `Schema` folder has to be commited to the repository**

#### 11. Exclude `GraphQLGenerated` folder from your linter's rule if necessary

## Usage

### Defining Query or Mutation
```swift
import GraphQLAPIKit
import GraphQLGenerated

let query = MyExampleQuery()
let mutation = MyExampleMutation()
```

### Fetching the query/perform mutation
```swift
import GraphQLAPIKit
import GraphQLGenerated

let configuration = GraphQLAPIConfiguration(
    url: URL(string: "https://api.example.com/graphql")!
)
let apiAdapter = GraphQLAPIAdapter(configuration: configuration)
let queryResult = try await apiAdapter.fetch(query: query)
let mutationResult = try await apiAdapter.perform(mutation: mutation)
```

### Subscriptions
```swift
let subscriptionStream = try await apiAdapter.subscribe(subscription: MySubscription())

for try await data in subscriptionStream {
    print("Received: \(data)")
}
```

### Deferred Responses (@defer)
```swift
let deferredStream = try apiAdapter.fetch(query: MyDeferredQuery())

for try await data in deferredStream {
    // Data arrives progressively as deferred fragments complete
    print("Received: \(data)")
}
```

## Contributors

- [Ievgen Samoilyk](https://github.com/samoilyk), <ievgen.samoilyk@futured.app>.

## License

GraphQLAPIKit is available under the MIT license. See the [LICENSE file](LICENSE) for more information.