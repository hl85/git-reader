// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestableGitReader",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "TestableGitReader",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/TestableGitReader"
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: [
                "TestableGitReader",
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/TestRunner"
        )
    ]
)
