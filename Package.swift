// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "MelloRunner",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "MelloRunner", targets: ["MelloRunner"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/WasmKit.git", from: "0.4.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.10.1"),
        .package(url: "https://github.com/ChrisRodStar/zipmello.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MelloRunner",
            dependencies: [
                .product(name: "WasmKit", package: "WasmKit"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "ZipMello", package: "zipmello")
            ]
        ),
        .testTarget(name: "MelloRunnerTests", dependencies: ["MelloRunner"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v6]
)
