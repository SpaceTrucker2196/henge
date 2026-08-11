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
| `make dmg` | Release build of the Mac app, wrapped in a verified installer image |
| `make generate` | regenerate `Henge.xcodeproj` after adding or moving files |
| `make clean` | drop `.build/` and the generated project |

Run `make generate` after adding a file under `App/`, `iOSApp/` or `macOSApp/`.
Files under `Sources/` and `Tests/` are picked up by SwiftPM automatically.

## Shipping the Mac build

`scripts/build_dmg.sh --release` is the whole release path: Release
build, universal-binary check, signing (Developer ID when the keychain
has one; ad hoc until then, which the download page admits to), a
verified UDZO image, a GitHub release tagged `v<MARKETING_VERSION>`,
and the public copy staged into the `river-io-site` checkout
(`RIVER_IO_SITE` overrides the default `../river-io-site`) with the
page's version and size stamped from the artifact. Committing and
pushing river-io-site is deliberately left manual — that repo deploys
www.river.io on push, and publishing the company site should be a
decision, not a side effect. The version lives in `project.yml`
(`MARKETING_VERSION`); bump it there and everything downstream
follows.

## fastlane (iOS)

The iOS side answers to fastlane as well as make — owner's order, kept
thin so the two doors cannot drift. Every lane regenerates the Xcode
project first and builds with `CODE_SIGNING_ALLOWED=NO` for the
simulator, exactly as the make targets do.

| Lane | Does |
|---|---|
| `fastlane ios build` | Debug simulator build, warning-filtered |
| `fastlane ios release_build` | Release compile proof (archiving waits on signing) |
| `fastlane ios sim` | build → install → launch on the booted simulator |
| `fastlane ios uitest` | the pixel-level `BuildFlowUITests` inspection |
| `fastlane ios beta` | archive, sign, upload to TestFlight |

`make test` remains the oracle and the gate before any push; fastlane
does not replace it.

The beta lane signs automatically with the App Store Connect API key
(`AuthKey_H3U2MJCD77.p8`, probed from the standard key directories) and
the river.io llc team (U3Z59VXPUB → `DEVELOPMENT_TEAM` in project.yml);
no profile lives in the repo. It registered the `io.river.henge` bundle
id itself. The **app record** is the one artefact Apple will not let an
API key create — a one-time human step (`fastlane produce` with an
Apple ID, or App Store Connect → My Apps → ＋); the lane archives
regardless and stops before upload with instructions until the record
exists. Build numbers come from TestFlight (`latest + 1`) and are
injected as a build-setting override because the project is generated.

That the record is manual is not a gap in this repo's tooling. Both
shipped siblings do it by hand as well — `clientAPT`'s FACTORY.md §5
"One-time setup" step 2 is *App Store Connect → My Apps → "+" → New App*
— and the `apps` resource refuses `CREATE` for both of the account's API
keys. It is a house-wide human step.

**Both are done** (2026-08-04), through the web console:

| Thing | Value |
|---|---|
| App record | Henge, `io.river.henge`, Apple ID 6798126839, SKU `io.river.henge` |
| In-app purchase | `io.river.henge.full`, non-consumable, $4.99 USD base, 175 regions |

`io.river.henge.full` had to exist before StoreKit would return
anything, and its absence fails quietly rather than loudly:
`Product.products(for:)` comes back empty, the paywall falls through to
`StoreProducts.fallbackPrice`, and the button looks entirely correct
while doing nothing. `Henge.storekit` is the local storefront that lets
the flow be rehearsed in the simulator; it is scheme configuration and
has no bearing on what the App Store sells.

**The house pattern for the store fields**, read off `Corn 3000` and
`Spacetrucker Galactic` rather than invented here:

| Field | Pattern | Henge |
|---|---|---|
| Support URL | `https://www.river.io/<app>.html#support` | `…/henge.html#support` |
| Marketing URL | `https://www.river.io/<app>.html` | `…/henge.html` |
| Copyright | `2026 river.io LLC` | same |
| Release | Automatically release this version | same |
| Review contact | Jeff Kunzelman, 6088651284, jeff@river.io | same |

Two things the survey settled. The reviewer contact lives on the *version*
page under App Review Information, not in TestFlight — TestFlight keeps its
own copy and neither fills the other. And `Spacetrucker Galactic` shipped
through **internal testing only**, with no external group at all: external
TestFlight is Henge's own choice, not the house default, and it is the
thing that drags in Beta App Review.

**A trap worth knowing about.** An older record already held the name
"Henge" on the bundle id `riverio.henge`. Apple locks a record's bundle
id permanently once any build is uploaded, and that one had an expired
TestFlight build — so it could never have been pointed at
`io.river.henge`. It is renamed "Henge (retired)", not deleted: the name
is freed, the history survives. If a store name ever appears to be taken
by a stranger, check this account first.

## The App Store listing (2026-08-11)

`fastlane ios store_metadata` is the listing door: it pushes
`fastlane/metadata/` — nine locales, matching the app's own languages —
plus review information and screenshots to App Store Connect, against
whatever version is editable. Screenshots live in `fastlane/screenshots/`
(gitignored; the canonical copies are on App Store Connect).

What the survey of shipping this taught, so nobody re-derives it:

- **The name "Henge" is taken in some storefronts.** Adding a store
  locale fails with a trademark-claim error if the bare name is in use
  there. en-US plus the European locales took "Henge"; **ja and zh-Hans
  carry suffixed names** (`Henge · ストーンヘンジ暦`, `Henge · 巨石阵历`) —
  the Corn 3000 pattern. `fastlane/metadata/<locale>/name.txt` must match
  what App Store Connect holds or deliver fails trying to rename.
- **The age rating cannot go through deliver.** Apple's 2025 declaration
  schema added required fields (`advertising`, `ageAssurance`, …) this
  fastlane predates. `fastlane/rating.json` records the answers (all
  none); they were applied with a direct `PATCH
  /v1/ageRatingDeclarations/<appInfo id>`.
- **App privacy is the one field the API key cannot touch.** The
  data-usage endpoints answer only to an Apple ID session. The answers
  are `fastlane/app_privacy_details.json` (Data Not Collected — true:
  no account, no network); publishing them is a human step in App Store
  Connect → App Privacy, or
  `fastlane run upload_app_privacy_details_to_app_store` with an
  Apple ID. Submission for review is blocked until it is done
  (`STATE_ERROR.APP_DATA_USAGES_REQUIRED`).
- **Everything else went through the API key**: version string 0.1.0,
  copyright, categories (EDUCATION / REFERENCE), review contact, price
  (free; base territory USA), availability (all 175 territories,
  available in new ones), content rights (no third-party content), the
  IAP's nine localizations and its review screenshot — the paywall,
  captured from the simulator. `io.river.henge.full` sits in Ready to
  Submit and rides the version's review submission automatically.
- **Screenshots come from the simulator**, iPhone 17 Pro Max (6.9",
  1320×2868) and iPad Pro 13" (2064×2752) — both required display
  classes. simctl cannot inject touches, so scenes were staged with a
  temporary launch-environment hook in `RootView` (jump to a wheel
  station's sunrise, pick a station, torch on, and so on), captured, and
  the hook reverted before commit. `simctl status_bar override` gives the
  clean 9:41 bar. Allow ~30 s after launch: the stones raise
  asynchronously and a shot taken early is a progress bar on an empty
  plain.

The support and marketing URL is the live `https://www.river.io/henge/`;
the privacy policy is `https://www.river.io/henge-privacy.html`, staged
in the river-io-site checkout — publishing that site remains a
deliberate push, not a side effect of this repo.

## Xcode Cloud — the house pattern for shipping

`StatusGalactic-iOS` and `clientAPT` both ship through **Xcode Cloud**
rather than by archiving locally, and henge now carries the same
bootstrap so it can join them. Apple's runner builds inside App Store
Connect: signing, provisioning, archive upload and the TestFlight
notification all live in Apple's pipeline, so there is no certificate to
manage, nothing to rotate by hand, and no secret in GitHub.

| Path | Purpose |
|---|---|
| `ci_scripts/ci_post_clone.sh` | Apple-convention hook. Installs xcodegen if the VM lacks it and regenerates `Henge.xcodeproj`, which is generated and gitignored — without this the runner has nothing to open. |

**One difference from the siblings, deliberately.** Both of them also
stage a hand-committed `ci_scripts/Package.resolved`, because Xcode Cloud
disables automatic SPM resolution and will not build without a lockfile.
That is about *remote* dependencies. henge has none — the first is a
stops-and-asks — and its only package is `HengeLocal`, a local path
package pointing at the repo root. Nothing resolves over the network, so
there is nothing to pin. The script says where the sibling pattern would
go back if that ever changes.

### One-time wiring in App Store Connect

Nothing here is automatable; all of it is behind an Apple ID.

1. The **app record** must exist first (see below) — Xcode Cloud is
   configured *on* an app, so there is nowhere to enable it until then.
2. App Store Connect → My Apps → Henge → **Xcode Cloud → Get Started**.
   Pick the GitHub repo; grant Apple's GitHub app read access.
3. First workflow: accept the *Build* + *Archive* template, then edit —
   **Start condition** Tag changes, pattern `v*`; **source-branch filter**
   `master` (henge works on `master`, inherited from the repo's first
   life); **Environment** most recent stable Xcode; keep the *Archive*
   action; add **Post-Actions → TestFlight** with the "Stone Circle"
   group. Add the *Test* action if you want XCTest ahead of each archive.
4. Grant Access when the first archive asks to manage signing.

The tag start condition does not filter by branch — "tags come from
`master`" is enforced by only ever tagging a `master` commit.

### Cutting a release

```sh
git switch master && git pull --ff-only
# MARKETING_VERSION in project.yml must already match the tag, less the v.
git tag v0.1.0
git push origin v0.1.0
```

### Which door to use

Both doors stay open and they do different jobs. `fastlane ios beta`
archives and signs **locally** — the fastest way to prove the release
path still works after a change, and it is what proved the paywall and
the nine localisations were correctly signed and bundled. Xcode Cloud is
the door a *release* goes through. Neither replaces `make test`.

## CI

No pre-merge CI. The merge gate is the **local green suite enforced
pre-push**; when CI arrives it is a post-hoc judge, never the gate.
Xcode Cloud above is a release pipeline rather than a merge gate, and it
bills only on tags.

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
