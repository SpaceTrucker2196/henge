# henge

A multiplatform Swift app for iOS and macOS, by [river.io](https://www.river.io).

**Early scaffold.** The project builds and its tests pass, but the product
itself is not defined yet — see `MISSION.md`.

## Build

```sh
brew install xcodegen
make test     # the oracle: 5 tests, no simulator needed
make build    # iOS + macOS, warning-clean
make generate && open Henge.xcodeproj
```

`Henge.xcodeproj` is generated from `project.yml` by xcodegen and is not
committed. Full runbook: `FACTORY.md`.

## Layout

Two thin app targets over one shared engine. `HengeCore` holds the logic and
imports no UI; `HengeUI` holds the SwiftUI surface both platforms present;
`App/` is the single `@main` entry point compiled into both targets. iOS 17+,
macOS 14+, no third-party dependencies.

## How this repo is run

henge is a [dark factory](factory/dark-factory.md): the mission, the
conventions, the tests and the autonomy boundary live in the tree, so an agent
can pick the work up cold. Production orders ship through
[the converge loop](factory/converge.md); every shipped order appends a row to
`METRICS.md`.

## History

henge was an Objective-C agricultural calendar built around Parse in 2014-15.
That code was wiped on 2026-07-27; its 20 commits remain in this repo's
history.
