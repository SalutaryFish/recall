// swift-tools-version:5.10
// Pure-Swift logic for Recall: model, day math, mutations, seed, insights.
// Foundation only, so it builds and tests on Linux (nix dev shell) as well
// as inside the Xcode project, which depends on it as a local package.
import PackageDescription

var targets: [Target] = [.target(name: "RecallCore")]

#if os(Linux)
// nixpkgs' Swift ships without libIndexStore, which SwiftPM needs to discover
// XCTest cases on Linux. There the tests build as a plain executable driven by
// main.swift (`just core-test` regenerates its list); elsewhere they are a
// normal test target.
targets.append(.executableTarget(name: "RecallCoreTests", dependencies: ["RecallCore"],
                                 path: "Tests/RecallCoreTests"))
#else
targets.append(.testTarget(name: "RecallCoreTests", dependencies: ["RecallCore"],
                           exclude: ["main.swift"]))
#endif

let package = Package(
    name: "RecallCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RecallCore", targets: ["RecallCore"]),
    ],
    targets: targets
)
