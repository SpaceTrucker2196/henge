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
    // Every user-facing string travels in a String Catalog beside the code
    // that says it, and `.module` resolves against this as the base language.
    // The app ships in nine: English plus the eight most spoken on the App
    // Store.
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HengeAstro", targets: ["HengeAstro"]),
        .library(name: "HengeGeometry", targets: ["HengeGeometry"]),
        .library(name: "HengeEngine", targets: ["HengeEngine"]),
        .library(name: "HengeStore", targets: ["HengeStore"]),
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
            // Salisbury Plain as a heightfield, baked from SRTM by
            // scripts/bake_terrain.py. Provenance in SECURITY.md.
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // The Metal 3 renderer. Shaders travel as a package resource and are
        // compiled at load — see FACTORY.md "Shader build integration" for why
        // that beats relying on the app bundle's default library.
        .target(
            name: "HengeEngine",
            dependencies: ["HengeAstro", "HengeGeometry"],
            path: "Sources/HengeEngine",
            resources: [.copy("Shaders"), .process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // The trial clock, the entitlement and the one StoreKit conversation.
        // Foundation and StoreKit only — no SwiftUI, no Metal — so that every
        // rule about what is allowed is a value type a test can build by hand
        // (`Access`), and only the part that genuinely needs Apple on the
        // other end talks to Apple.
        .target(
            name: "HengeStore",
            path: "Sources/HengeStore",
            // Classic `<lang>.lproj/Localizable.strings`, not a String
            // Catalog. `swift build` copies a .xcstrings into the bundle
            // verbatim — it never runs xcstringstool — so every lookup came
            // back as its own key under `swift test` and the oracle could not
            // see the translations at all. Only Xcode would have compiled
            // them, which is a difference between the tested app and the
            // shipped one. .strings are read directly by Foundation in both.
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // SwiftUI chrome, and the only place the two worlds meet: the
        // MTKView bridge lives here so HengeEngine never imports SwiftUI.
        .target(
            name: "HengeUI",
            dependencies: ["HengeAstro", "HengeGeometry", "HengeEngine",
                           "HengeStore"],
            path: "Sources/HengeUI",
            // Classic `<lang>.lproj/Localizable.strings`, not a String
            // Catalog. `swift build` copies a .xcstrings into the bundle
            // verbatim — it never runs xcstringstool — so every lookup came
            // back as its own key under `swift test` and the oracle could not
            // see the translations at all. Only Xcode would have compiled
            // them, which is a difference between the tested app and the
            // shipped one. .strings are read directly by Foundation in both.
            resources: [.process("Resources")],
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
        ),
        // The paywall's rules, checked without a storefront: the trial clock's
        // arithmetic and every branch of `Access`, on both policies. What
        // cannot be tested here is StoreKit itself, which is exactly why so
        // little of the decision lives in `PurchaseController`.
        .testTarget(
            name: "HengeStoreTests",
            dependencies: ["HengeStore"],
            path: "Tests/HengeStoreTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // `SkyModel` is the app's whole state machine — every jump, every
        // clock, every readout the almanac shows — and it had no tests at all
        // until the wind needed one. Added when that gap became load-bearing.
        .testTarget(
            name: "HengeUITests",
            dependencies: ["HengeUI", "HengeEngine", "HengeGeometry", "HengeAstro"],
            path: "Tests/HengeUITests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
