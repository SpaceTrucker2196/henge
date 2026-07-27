# henge — agent instructions

Repo-local rules for any coding agent (Claude Code, Copilot, Codex). Build and
infra runbook lives in `FACTORY.md`; charter in `MISSION.md`; the pattern and
the autonomy contract in `factory/dark-factory.md`.

## What henge is

A photoreal 3D Stonehenge that is also a working astronomical calendar, for iOS
and macOS, on a hand-rolled Metal 3 renderer. Druidic in spirit, archaeological
in fact. `MISSION.md` is the charter and it is binding.

## Architecture

Four modules, and the layering is the point rather than an organisational
preference:

| Module | Holds | May import |
|---|---|---|
| `HengeAstro` | time (JD, ΔT, UTC↔TT), sun, seasons, refraction, alt-az | Foundation only |
| `HengeGeometry` | site constants, stone meshes, **analytic shadow solution** | Foundation, simd, `HengeAstro` |
| `HengeEngine` | Metal 3 renderer, cascades, MSL shaders | Metal, MetalKit, `HengeAstro`, `HengeGeometry` |
| `HengeUI` | SwiftUI chrome, time controls, the MTKView bridge | SwiftUI + all of the above |

`App/` holds one `@main`, compiled into both app targets.

Four rules, stated as rules because they are what keep the product testable:

1. **`HengeAstro` imports Foundation and nothing else.** Its correctness must be
   provable on a machine with no GPU. No Metal, no SwiftUI, no I/O.
2. **`HengeGeometry` never imports Metal or SwiftUI.** The analytic shadow that
   the renderer is measured against lives here precisely so that the
   measurement is a unit test rather than an opinion about a screenshot.
3. **`HengeEngine` never imports SwiftUI.** The bridge lives in `HengeUI`.
4. **Logic in a view or a shader is logic the oracle cannot reach.** If a
   decision is being made, it belongs in `HengeAstro` or `HengeGeometry` where
   a test can pin it.

Both app targets link the identical package products, so iOS and macOS cannot
diverge in behaviour. Divergence in *presentation* goes behind `#if os(...)`
inside `HengeUI`.

## Discipline

- **Tests must pass.** `make test` returns 0 before any push. Never commit a red
  test, never skip one, never weaken an assertion to reach green.
- **Builds are warning-clean**, both platforms.
- **A bug fix ships with the test that would have caught it.** Every escape
  becomes a new inspection step — that is how the factory learns.
- **Never write a test that checks the code against itself.** Fixtures come from
  published sources (Meeus's worked examples, JPL/NOAA values) or from
  independent trigonometry a reader can redo on paper.
- **Compute, don't hardcode.** Any azimuth, obliquity, rise time or solstice
  date appearing as a literal outside a test fixture is a bug. The solstice is
  not on 21 June: in 2500 BC it falls in Julian July, and code that assumed
  otherwise measured the wrong morning for a whole afternoon of debugging.
- **`Henge.xcodeproj` is generated.** Never hand-edit it; it is gitignored. Edit
  `project.yml` and run `make generate`.
- **No third-party dependencies.** The first one is a stops-and-asks.

## Metal conventions

- **Shader source is a package resource**, compiled at renderer start. It is not
  built into a `default.metallib` by SwiftPM, and depending on the app bundle's
  library would make the engine untestable from `swift test`. `FACTORY.md`
  records the trade.
- **Struct layouts are matched by hand** between `ShaderTypes.swift` and
  `Shaders/Henge.metal`. A mismatch shows up as geometry in the wrong place, not
  as a compiler error, so `testUniformLayoutsAreTheExpectedSize` asserts the
  sizes. Change one side, change the other, update the test.
- **Uniforms are triple-buffered** behind a semaphore. Do not write to a frame
  buffer the GPU may still be reading, and do not block the render thread
  waiting for one.
- **Filtering on depth textures is `nearest`.** A linear sampler averages depths
  across the shadow edge before comparing, which drags the boundary toward the
  caster by a third of a metre here. The 3×3 comparison in the shader is the
  percentage-closer filter.
- **Shadow bias is a measurement cost, not a cosmetic knob.** It buys freedom
  from acne and pays in peter-panning, which in this app is error in a calendar.
  Front-face culling in the shadow pass does most of the work instead.
- **Metal's clip space is z ∈ [0,1]**, not [−1,1]. The projections in
  `MetalMath` are built for that; a GL-style matrix produces a plausible picture
  over a useless depth buffer.

## Swift 6 concurrency

The package builds in Swift 6 language mode with strict concurrency.

- `HengeRenderer` and `SkyModel` are `@MainActor`. `MTKView` drives `draw(in:)`
  on the main thread; the isolation is stated rather than assumed.
- Value types crossing boundaries are `Sendable` — `SceneState`, `Angle`,
  `JulianDay`, `Stone`, `Mesh`. Keep them so.
- The actor guards CPU-side state, not the command buffer. GPU work stays
  asynchronous.

## Conventions

- **Commit messages.** Imperative subject, blank line, body explaining the
  *why*. `Co-Authored-By` trailer when an agent landed the change.
- **Branches.** Work on `master` — inherited from the repo's first life and kept
  deliberately. No long-running feature branches.
- **`git add` specific files.** Never `git add -A` or `git add .`.
- **No destructive git operations** without explicit owner authorisation.
- **Swift style:** four-space indent, comments wrapped near 80 columns, and
  comments that explain *why* rather than restating the code.
- **Prose in the app is archaeological.** Any user-facing claim about the
  monument carries its tier and citation (invariant 3). If the tier is not
  obvious, it is Debated.

## Token / cost ledger

The owner bills from `LEDGER.md` (exact, never estimated). After every
substantive commit: run `~/.claude/billing/ledger.py --append --summary
"<desc>"`, then commit `LEDGER.md` as its own `chore(ledger): <sha>` commit.
Never hand-author, estimate, or rewrite rows — append-only. If the script cannot
produce a row, stop and surface it.

Start billable sessions **inside this repo**, not the workspace root:
`ledger.py` attributes by the session's project directory and cannot account for
sessions launched from outside.

## User context

User: Jeff Kunzelman (`SpaceTrucker2196` on GitHub). River.io LLC.
