// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "AppCat",
  platforms: [
    .iOS(.v13),
  ],
  products: [
    .library(name: "AppCat", targets: ["AppCat"]),
  ],
  targets: [
    .target(
      name: "AppCat",
      dependencies: ["AppCatCoreKit"],
      path: "Sources/AppCat"
    ),
    .binaryTarget(
      name: "AppCatCoreKit",
      path: "AppCatCoreKit.xcframework"
    ),
    .testTarget(
      name: "AppCatTests",
      dependencies: ["AppCat"],
      path: "Tests/AppCatTests"
    ),
  ]
)
