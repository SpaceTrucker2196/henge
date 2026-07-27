// swift-tools-version: 6.0
import PackageDescription

// The shared engine. Both app targets in project.yml link these products as a
// local path package, so iOS and macOS ship one engine and cannot drift apart.
//
// The layering is the point, and AGENTS.md states it as rules: HengeAstro is
// provable with no GPU, HengeGeometry holds the analytic shadow solution the
// renderer is checked against, HengeEngine owns Metal, HengeUI owns SwiftUI.
let package = Package(
    name: "Henge",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HengeAstro", targets: ["HengeAstro"]),
        .library(name: "HengeGeometry", targets: ["HengeGeometry"]),
        .library(name: "HengeEngine", targets: ["HengeEngine"]),
        .library(name: "HengeUI", targets: ["HengeUI"])
    ],
    targets: [
        // Ephemeris. Foundation only — no Metal, no SwiftUI, no I/O. Its
        // correctness must be provable on a machine with no GPU.
        .target(
            name: "HengeAstro",
            path: "Sources/HengeAstro",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // The monument: site constants, procedural stone meshes, and the
        // analytic shadow solution. Never imports Metal or SwiftUI, so the
        // shadow check the renderer is measured against is a unit test.
        .target(
            name: "HengeGeometry",
            dependencies: ["HengeAstro"],
            path: "Sources/HengeGeometry",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // The Metal 3 renderer. Shaders travel as a package resource and are
        // compiled at load — see FACTORY.md "Shader build integration" for why
        // that beats relying on the app bundle's default library.
        .target(
            name: "HengeEngine",
            dependencies: ["HengeAstro", "HengeGeometry"],
            path: "Sources/HengeEngine",
            resources: [.copy("Shaders")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // SwiftUI chrome, and the only place the two worlds meet: the
        // MTKView bridge lives here so HengeEngine never imports SwiftUI.
        .target(
            name: "HengeUI",
            dependencies: ["HengeAstro", "HengeGeometry", "HengeEngine"],
            path: "Sources/HengeUI",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        .testTarget(
            name: "HengeAstroTests",
            dependencies: ["HengeAstro"],
            path: "Tests/HengeAstroTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HengeGeometryTests",
            dependencies: ["HengeGeometry", "HengeAstro"],
            path: "Tests/HengeGeometryTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Layer 2 of the oracle: renders headlessly and checks the rasterised
        // shadow against HengeGeometry's analytic line. Skips loudly where no
        // Metal device exists — never silently passes.
        .testTarget(
            name: "HengeEngineTests",
            dependencies: ["HengeEngine", "HengeGeometry", "HengeAstro"],
            path: "Tests/HengeEngineTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
