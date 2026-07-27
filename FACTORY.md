# henge — factory runbook

Build and infrastructure. The charter is `MISSION.md`; agent rules are
`AGENTS.md`; the pattern and the autonomy contract are
`factory/dark-factory.md`.

## 0. TL;DR

```sh
git clone git@github.com:SpaceTrucker2196/henge.git && cd henge
brew install xcodegen        # the only tool beyond Xcode
make test                    # the oracle — must exit 0
make build                   # both platforms — must be warning-clean
```

If `make test` is green and `make build` produces no warnings, the factory is
operational.

## Layout

```
henge/
  Package.swift          the shared engine (SwiftPM), Swift 6 language mode
  project.yml            xcodegen source of truth for the app targets
  Henge.xcodeproj        GENERATED — never hand-edit, never committed
  Sources/
    HengeAstro/          time, sun, seasons, refraction, alt-az. Foundation only
    HengeGeometry/       site constants, stone meshes, analytic shadow solution
    HengeEngine/         Metal 3 renderer
      Shaders/Henge.metal  MSL, shipped as a package resource
    HengeUI/             SwiftUI chrome and the MTKView bridge
  Tests/
    HengeAstroTests/     layer 1 — the ephemeris against published values
    HengeGeometryTests/  layer 1 — the analytic shadow against trigonometry
    HengeEngineTests/    layer 2 — the rendered shadow against the analytic one
  App/                   @main, compiled into BOTH app targets
  iOSApp/  macOSApp/     Info.plists and platform-specific files
  factory/               dark-factory.md (the pattern), converge.md (the loop)
```

The dependency rule the layout exists to enforce: **`HengeAstro` imports nothing
but Foundation, and `HengeGeometry` imports no Metal.** Logic that ends up in a
view or a shader is logic the oracle cannot reach. Full rules in `AGENTS.md`.

## Toolchain

| Piece | Version | Install |
|---|---|---|
| Swift | 6.0 language mode (6.3 toolchain) | ships with Xcode |
| iOS deployment target | 17.0 | `project.yml` |
| macOS deployment target | 14.0 | `project.yml` |
| xcodegen | any recent | `brew install xcodegen` |

No third-party packages. `Package.swift` has no remote dependencies, so a cold
clone builds offline. Adding the first one is a stops-and-asks.

## The oracle

The product's output is pixels, and a dark factory needs `make test` to be a
gate worth trusting. Three layers:

**Layer 1 — headless truth. Always runs; this is the gate.** Pure Swift, no GPU,
about a tenth of a second. The ephemeris against Meeus's worked examples, ΔT
across five millennia, the Stonehenge alignments, and the analytic shadow
against independent trigonometry.

**Layer 2 — GPU agreement.** Renders headlessly through an overhead
orthographic-ish camera so a pixel maps linearly to a position on the ground,
walks out along the shadow's centre line, finds the brightness edge, and asserts
it lands within **0.28 m** of `ShadowSolver`'s analytic outline. Where no Metal
device exists these **skip loudly** — never a silent pass.

**Layer 3 — performance budget.** Not yet built. Arrives with M5.

`make test` runs layers 1 and 2.

## Shader build integration

SwiftPM does not produce a `default.metallib` for a library target. The two ways
out are to let the *app* target compile the shaders — which would leave the
renderer unreachable from `swift test` — or to ship the source as a package
resource and compile it at renderer start.

Henge does the second. `Shaders/Henge.metal` travels in the bundle,
`HengeRenderer.makeLibrary` compiles it once at start, and
`testShadersCompile` keeps a syntax error from surviving to runtime. The cost is
a fraction of a second at launch. The benefit is a renderer the oracle can
actually drive, which invariant 2 requires.

If startup cost ever matters, the replacement is a SwiftPM build plugin emitting
a metallib — not moving the shaders into the app target.

## Commands

| Command | What it does |
|---|---|
| `make test` | the oracle: layers 1 and 2 |
| `make build` | both platforms, warning-clean check |
| `make build-ios` / `make build-mac` | one platform |
| `make run-mac` | build and launch the macOS app |
| `make generate` | regenerate `Henge.xcodeproj` after adding or moving files |
| `make clean` | drop `.build/` and the generated project |

Run `make generate` after adding a file under `App/`, `iOSApp/` or `macOSApp/`.
Files under `Sources/` and `Tests/` are picked up by SwiftPM automatically.

## CI

None yet. The merge gate is the **local green suite enforced pre-push**. When CI
arrives it is a post-hoc judge, never the gate. Adding it is a stops-and-asks:
it bills minutes on a private repo.

## Cold-start sanity loop

1. Fresh clone; `brew install xcodegen`.
2. `make test` → exit 0, 46 tests.
3. `make build` → `** BUILD SUCCEEDED **` twice, no warnings.
4. `make run-mac`, or open the project and run either scheme. Drag **Bearing**
   to about 230° and **Height** to 12°: the Great Trilithon stands with the Heel
   Stone beyond it, and the shadows run down the axis. Press play with the rate
   up and watch them sweep.

## Where to read next

| Question | Read |
|---|---|
| What is this product? | `MISSION.md` |
| How do agents behave here? | `AGENTS.md`, `factory/dark-factory.md` |
| How does one order ship? | `factory/converge.md` |
| What's in flight? | `PROGRESS.md` |
| What data ships, and under what licence? | `SECURITY.md` |
