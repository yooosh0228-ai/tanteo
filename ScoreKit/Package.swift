// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScoreKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "ScoreKit", targets: ["ScoreKit"])
    ],
    targets: [
        .target(name: "ScoreKit"),
        .testTarget(name: "ScoreKitTests", dependencies: ["ScoreKit"])
    ]
)
