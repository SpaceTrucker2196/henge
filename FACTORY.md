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
  Package.swift          the shared engine (SwiftPM) — HengeCore, HengeUI
  project.yml            xcodegen source of truth for the app targets
  Henge.xcodeproj        GENERATED — never hand-edit, never committed
  Sources/
    HengeCore/           domain logic. No SwiftUI, no UIKit/AppKit, no I/O
    HengeUI/             the shared SwiftUI surface both apps present
  Tests/
    HengeCoreTests/      the oracle
  App/                   @main entry point, compiled into BOTH app targets
  iOSApp/                iOS-only files (Info.plist, platform code)
  macOSApp/              macOS-only files (Info.plist, platform code)
  factory/               dark-factory.md (the pattern), converge.md (the loop)
```

The dependency rule, which the whole layout exists to enforce: **HengeCore
imports nothing from HengeUI or the app targets.** Logic that ends up in a
view is logic the oracle cannot reach.

## Toolchain

| Piece | Version | Install |
|---|---|---|
| Swift | 5.9 | ships with Xcode |
| iOS deployment target | 17.0 | `project.yml` |
| macOS deployment target | 14.0 | `project.yml` |
| xcodegen | any recent | `brew install xcodegen` |

No third-party packages. `Package.swift` has no remote dependencies, so a cold
clone builds offline. Adding the first one is a stops-and-asks
(`factory/dark-factory.md` §4).

## The targets

Two app targets, one engine. `Henge` (iOS 17+, iPhone + iPad) and
`Henge-macOS` (macOS 14+) both compile `App/` and both link the same
`HengeCore` + `HengeUI` products from the local path package — so the
platforms cannot drift apart in logic. They deliberately share one bundle id,
`io.river.henge`, for a single App Store Connect record covering both.

Anything genuinely platform-specific goes behind `#if os(...)` in `HengeUI`,
or in `iOSApp/` / `macOSApp/`. The app targets stay thin shells.

## Commands

| Command | What it does |
|---|---|
| `make test` | `swift test` — the oracle. No simulator, runs in about a second |
| `make build` | both platforms, warning-clean check |
| `make build-ios` / `make build-mac` | one platform |
| `make generate` | regenerate `Henge.xcodeproj` after adding or moving files |
| `make clean` | drop `.build/` and the generated project |

Run `make generate` after adding a file under `App/`, `iOSApp/` or `macOSApp/`.
Files under `Sources/` and `Tests/` are picked up by SwiftPM automatically and
need no regeneration for `make test`.

## CI

None yet. The merge gate is the **local green suite enforced pre-push** —
`make test` returns 0 and `make build` is warning-clean on the machine doing
the work. When CI arrives it is a post-hoc judge, never the gate. Adding it is
a stops-and-asks: it bills minutes on a private repo.

## Cold-start sanity loop

1. Fresh clone; `brew install xcodegen`.
2. `make test` → exit 0, 5 tests.
3. `make build` → `** BUILD SUCCEEDED **` twice, no warnings.
4. Smoke-run: `open Henge.xcodeproj`, run either scheme. The window shows the
   wordmark, the version and a line saying the mission is not written yet.

## Where to read next

| Question | Read |
|---|---|
| What is this product? | `MISSION.md` — **not yet written** |
| How do agents behave here? | `AGENTS.md`, `factory/dark-factory.md` |
| How does one order ship? | `factory/converge.md` |
| What's in flight? | `PROGRESS.md` |
