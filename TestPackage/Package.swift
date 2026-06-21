// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestableGitsReader",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "TestableGitsReader",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/TestableGitsReader"
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: [
                "TestableGitsReader",
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/TestRunner"
        )
    ]
)
