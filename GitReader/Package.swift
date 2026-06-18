// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitReader",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(path: "../LocalPackages/swift-libgit2-local"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "GitReader",
            dependencies: [
                .product(name: "GitLib", package: "swift-libgit2"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "."
        )
    ]
)
