// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "MelloRunner",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "MelloRunner", targets: ["MelloRunner"])
    ],
    targets: [
        .target(name: "MelloRunner"),
        .testTarget(name: "MelloRunnerTests", dependencies: ["MelloRunner"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v6]
)
