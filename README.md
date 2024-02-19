# GraphQLAPIKit

Lightweight GraphQL API client based on [Apollo iOS](https://github.com/apollographql/apollo-ios).
Developed to simplify [Futured](https://www.futured.app) in-house development of applications, that work with GraphQL APIs.

Currently there is no support for some Apollo's features:
- Apollo built-in cache
- GraphQL subscriptions
- Custom interceptors

## Installation

Install or add following line to your dependencies:

```swift
.package(url: "https://github.com/futuredapp/GraphQLAPIKit.git", from: "1.0.0")
```

## Setup Your Project

#### 1. Create `GraphQLAPI` folder at your `ProjectName.xcodeproj` level

#### 2. Add Apollo configuration file

Add `apollo-codegen-config.json` file and add it `GraphQLAPI` folder.
Copy and paste json configuration to newly created file:
```json
{
  "schemaName" : "GraphQLAPI",
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
        "swiftPackageManager": {}
      }
    },
    "operations" : {
      "inSchemaModule" : {}
    },
    "testMocks" : {
      "swiftPackage": {
        "targetName": "GraphQLAPIMocks"
      }
    }
  }
}
```