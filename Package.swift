// swift-tools-version: 5.9
import PackageDescription

// The shared engine. Both app targets in project.yml link these products as a
// local path package, so iOS and macOS ship one engine under one App Store
// Connect record. Logic lives here, not in the app targets — it is what
// `swift test` can exercise without a simulator, which is what makes the
// oracle fast enough to run on every change.
let package = Package(
    name: "Henge",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HengeCore", targets: ["HengeCore"]),
        .library(name: "HengeUI", targets: ["HengeUI"])
    ],
    targets: [
        // HengeCore — platform-independent domain logic. No SwiftUI, no
        // UIKit/AppKit, no I/O. Everything here is unit-testable in isolation.
        .target(
            name: "HengeCore",
            path: "Sources/HengeCore"
        ),
        // HengeUI — the shared SwiftUI surface both apps present. Depends on
        // HengeCore; never the other way round.
        .target(
            name: "HengeUI",
            dependencies: ["HengeCore"],
            path: "Sources/HengeUI"
        ),
        .testTarget(
            name: "HengeCoreTests",
            dependencies: ["HengeCore"],
            path: "Tests/HengeCoreTests"
        )
    ]
)
