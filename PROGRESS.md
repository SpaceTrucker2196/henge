# henge — progress

In-flight state. Newest first. Each entry: date, what changed, what's next, and
anything a cold agent must know that isn't in a doc yet.

## 2026-07-27 (later) — real terrain, and the stones become solids

Two threads, both started by looking at the thing on an iPad.

### Salisbury Plain is now in the tree

`scripts/bake_terrain.py` turns SRTM 1-arc-second tiles into a 768x768
heightfield at 40 m spacing, ±15.3 km around the monument (1.18 MB, public
domain — see SECURITY.md). `TerrainModel` reads it, and `Skyline` solves rise
and set bearings over the real horizon by iterating, since the skyline altitude
depends on the bearing being solved for.

The bake lands the ground at the monument at **101 m**, matching the surveyed
figure, and finds Stonehenge Bottom falling away to the north exactly where it
should be — which is what the orientation tests now pin.

**The point was never scenery.** The horizon altitude toward midsummer sunrise
had been a hand-picked 0.6°, and it moves the bearing by more than a degree.
Measured from the terrain it is **0.71°**. The guess was close, which is
precisely why it would have survived indefinitely. It is now computed from
cited survey data, as invariant 1 requires.

### The stones are solids now, not slabs

The mesh builder was making six independent box faces and displacing each along
its own normal. Everything about that was wrong:

- **Unwelded.** Edge vertices existed twice and moved apart — the bright seams.
- **Perfectly sharp edges**, which read as concrete rather than sarsen.
- **Normals from winding**, which is only defined up to a sign, so half the
  faces lit from inside and the stones rendered black.
- **A mirrored transform.** The local-to-world rotation was written twice with
  a sign difference; one copy had determinant −1, inverting every triangle's
  winding. The uprights also sat 10° off the axis because of it.

The stone is now a single closed surface — a sphere swept onto a rounded box,
displaced radially so shared vertices cannot disagree — with smooth normals and
a silhouette that carries the solidity. `Stone.toWorld` is the one transform,
called by both the mesh builder and the shadow solver.

Lighting changed with it: a hemispheric ambient (sky above, ground bounce
below, chosen by the normal) instead of a weak uniform fill. Strength matters
as much as direction — the first attempt was 4× too strong and the stones went
flat pale, which looks worse than too dark because the sun stops being the
modelling light.

### Consequences worth knowing

The rendered stone is a rounded solid inscribed in its bounding box, so its
shadow is *smaller* than the box's. The agreement test now projects the mesh
the renderer actually draws rather than the idealised box —
`ShadowSolver.shadowOutline(of: Mesh)`. Comparing to the box would charge the
renderer for a difference of shape.

61 tests green, both platforms warning-clean, run and looked at on an iPad.

### Looking at bearing 320°

Worth recording, because it looked like a bug and half of it was.

**The half that is not:** 320° is within a tenth of a degree of the across-axis
direction (319.9°), the line joining the two uprights. From there they occlude
each other exactly and the lintel is seen end-on, so the trilithon collapses
into a single pillar. Correct geometry; just the one bearing where a doorway
stops looking like one.

**The half that was:** a ragged comb where the stone met the turf. The obvious
explanation — displacement noise crossing a flat ground plane — was wrong, or
at least incomplete. The real cause is that a shadow is stretched by
1/tan(altitude), and at the 6.5° sun in that frame that is a factor of nine: a
three-centimetre bump at the waterline throws a quarter-metre spike across the
ground. Low sun is precisely what this app is for, so it shows constantly.

Fixed by fading the displacement to nothing over the lowest 1.6 m and raising
the tessellation, and pinned by `WaterlineTests`. The lintel also now seats
0.25 m into the uprights: two rounded surfaces meeting at the nominal height
left a line of daylight along the joint.

### "Open sides" — investigated, and the mesh was innocent

Reported as see-through polygons. Three tests now settle it rather than an
opinion about a screenshot:

- `SolidityTests` proves the mesh is **watertight and consistently wound**:
  every directed edge appears exactly once with its reverse in the neighbouring
  triangle, V − E + F = 2, and no triangle faces inward.
- `OpacityTests` proves the **renderer** draws it opaque, by rendering the same
  view with and without the stone and flood-filling the untouched pixels in
  from the frame edge. Any enclosed background pixel is a hole you can see
  through. There are none.

That second test first reported 17 holes, which were an artefact of its own
classifier: a stone pixel whose colour lands within a dozen levels of the
background it replaced reads as uncovered. At a tighter threshold it reports
none, and the threshold now carries that reasoning.

What was actually open was **the world**. The ground plane stopped at 400 m and
sky showed beyond it, so a few hundred metres out the scene simply ended. It
now reaches 15 km, matching the terrain data, with the far plane raised to suit.

### Next

Terrain is loaded and measured but **not yet drawn** — the renderer still puts
the monument on a flat plane. Wiring `TerrainModel` into the ground mesh is the
first job of M2, along with the rest of the monument.

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
