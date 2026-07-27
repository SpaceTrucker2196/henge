# henge — progress

In-flight state. Newest first. Each entry: date, what changed, what's next, and
anything a cold agent must know that isn't in a doc yet.

## 2026-07-27 — mission set; M1 "The Light" landed

The charter arrived and `MISSION.md` is written, so the repo is out of the
Level-3 holding pattern it was in this morning. The modules were reshaped to
match it (`HengeCore` → `HengeAstro`, plus `HengeGeometry` and `HengeEngine`),
the package moved to Swift 6 language mode with strict concurrency, and M1 was
built: sun ephemeris, Preetham sky, three-cascade shadows, one trilithon and
the Heel Stone, a time scrubber, and the GPU shadow-agreement test.

**46 tests green. Both platforms build warning-clean.**

### Four bugs the oracle caught, worth knowing about

1. **Refraction was counted twice** in the rise/set solver — it compared a
   refracted altitude against −0.833°, which already includes refraction. That
   put sunrise minutes early and dragged the solstice bearing a degree north.
   Now the target carries only the sun's semi-diameter.
2. **The solstice is not on 21 June.** In 2500 BC the Julian calendar puts it on
   14 July. Searching a fixed date range measured the wrong morning entirely;
   `Seasons` now solves for solar longitude instead.
3. **The shadow camera was underground.** `eye = centre − sunDirection × d`
   placed it opposite the sun. Sign flipped.
4. **The depth texture was sampled with a linear filter**, averaging depths
   across the shadow edge before comparing and pulling the boundary a third of
   a metre toward the caster. Immune to bias tuning, because it is a filtering
   artefact. Sampler is now `nearest`; the 3×3 comparison does the filtering.

Only the fourth was found by looking at code. The rest were found by the tests
disagreeing with the mathematics, which is the whole argument for building the
analytic solver before the renderer.

### Decisions taken, and why

- **Preetham, not Hosek–Wilkie, for now.** HW needs a vendored coefficient table
  carrying its own licence; invariant 5 says data arrives with provenance
  settled. Preetham is closed-form with nothing to vendor and drops out cleanly
  at M5.
- **Shaders compile from a package resource at start**, not from a
  `default.metallib`. SwiftPM does not build one for a library target, and
  depending on the app bundle would put the renderer beyond `swift test`.
- **Shadow tolerance is 0.28 m**, found by walking the suite down through 0.24,
  0.20, 0.14 and 0.10 until it broke. The 225° diagonal is the limiting case;
  cardinal bearings are good to about 0.1 m.

### Next

**M2 — The Stones.** The full monument in both states. When PCSS lands, the
shadow tolerance gets re-measured rather than inherited.

**Open and blocking M3:** the constellation-figure licence (`SECURITY.md`).
Stellarium's data is GPL and cannot ship in a closed app.

**Run and looked at** (macOS, `make run-mac`): the Great Trilithon and the Heel
Stone stand on the axis, the sky graduates correctly from horizon to zenith, and
at 18:28 UT with the sun at azimuth 285° the shadows run east-south-east as they
should. The readout and the render agree because both read the same `SkyModel`.

**Honest about the finish:** the colour grade is serviceable, not beautiful. The
chalk plain reads pale and the mid-tones are flat — the sky ambient term is a
crude stand-in for a real irradiance probe, and exposure is a constant rather
than adapting. Neither affects the geometry or the shadow agreement, so it is
M2/M5 work rather than a defect, but nobody should read "photoreal" into the
current frame.

**Not yet done:** no run on an iOS device or simulator — iOS is verified by
compiling only.
