// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Prism",
    platforms: [
        .macOS(.v13) // ScreenCaptureKit audio + MenuBarExtra
    ],
    products: [
        .executable(name: "Prism", targets: ["Prism"]),
        .library(name: "PrismCore", targets: ["PrismCore"]),
    ],
    targets: [
        // The portable, GUI-free analysis core: DSP + music theory.
        // No AppKit / SwiftUI imports live here so it can be ported (e.g. Windows).
        .target(
            name: "PrismCore"
        ),
        // The macOS app: overlay, capture, views — depends on the core.
        .executableTarget(
            name: "Prism",
            dependencies: ["PrismCore"]
        ),
        // Dependency-free verification runner: `swift run PrismCheck`.
        // Exercises the same cases as the XCTest suite, but needs no XCTest —
        // so it runs with only the Command Line Tools (no full Xcode required).
        .executableTarget(
            name: "PrismCheck",
            dependencies: ["PrismCore"]
        ),
        // Standard XCTest suite (run from Xcode, or `swift test` with full Xcode).
        .testTarget(
            name: "PrismCoreTests",
            dependencies: ["PrismCore"]
        ),
    ]
)
