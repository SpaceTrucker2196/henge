# henge

**A living stone calendar.** A photoreal, real-time 3D Stonehenge for iOS and
macOS that is also a working astronomical calendar — the sun, moon and stars
move across a physically modelled sky for any date you choose, and the shadows
the stones cast are accurate enough to be measured.

Druidic in spirit and ceremony, archaeological in fact. By
[river.io](https://www.river.io).

> **Early.** M1 of five has landed: the light, the shadows and the ephemeris
> that drive them. The monument is one trilithon and the Heel Stone so far. See
> `ROADMAP.md`.

## Build

```sh
brew install xcodegen
make test      # the oracle — 46 tests, about a tenth of a second
make build     # iOS + macOS, warning-clean
make run-mac   # build and launch
```

`Henge.xcodeproj` is generated from `project.yml` by xcodegen and is not
committed. Full runbook in `FACTORY.md`.

## How it is put together

Four modules over two thin app targets, and the layering is load-bearing:

- **`HengeAstro`** — Julian day, ΔT across five millennia, solar position,
  seasons, refraction, alt-azimuth. Foundation only, so its correctness is
  provable on a machine with no GPU.
- **`HengeGeometry`** — the site's measured constants, procedural stone meshes,
  and the **analytic shadow solution**. Imports no Metal, which is what lets the
  renderer be checked against it by a unit test.
- **`HengeEngine`** — a hand-rolled Metal 3 renderer: Preetham sky, Cook–Torrance
  PBR, three-cascade shadow maps, ACES tone mapping. No SceneKit, no
  RealityKit, no game engine.
- **`HengeUI`** — SwiftUI chrome and the one place SwiftUI and Metal meet.

iOS 17+, macOS 14+, Swift 6 language mode, **no third-party dependencies** — a
cold clone builds offline.

## The claim, and how it is kept

The app says the shadows are astronomically accurate, so the test suite checks
exactly that. `HengeGeometry` solves the shadow on paper; the renderer draws it;
a headless GPU test walks out along the shadow's centre line in an overhead
render and asserts the rendered edge lands within **0.28 m** of the analytic
answer. That tolerance was measured, not chosen, and it is documented where it
is asserted.

Building the solver before the renderer paid for itself immediately: the tests
caught a doubled refraction correction, a solstice search that missed by three
weeks in 2500 BC, an underground shadow camera, and a depth-texture filter that
dragged every shadow edge a third of a metre toward its caster.

## What it already establishes

Computed, never hardcoded — the bearings move with the epoch because the
obliquity does:

| | 2500 BC | 2026 |
|---|---:|---:|
| Midsummer sunrise (0.6° skyline) | 49.08° | 50.11° |
| Midwinter sunset (0.6° skyline) | 230.10° | 231.12° |

Against a built axis of 49.9°, midwinter sunset is the tighter fit.

## How this repo is run

henge is a [dark factory](factory/dark-factory.md): the mission, the
conventions, the tests and the autonomy boundary live in the tree, so an agent
can pick up the work cold. Production orders ship through
[the converge loop](factory/converge.md); every shipped order appends a row to
`METRICS.md`.

## History

henge was an Objective-C agricultural calendar built around Parse in 2014–15.
That code was wiped on 2026-07-27 and its 20 commits remain in this repo's
history, below the `v0.0.1` tag.
