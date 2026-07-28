# henge — progress

## 2026-07-27 — M3 begins: the moon

Position, phase, distance and apparent size from a truncated ELP-2000 (Meeus
ch. 47), with topocentric parallax — which matters for the moon in a way it
never does for the sun, since an observer on the surface sees it up to a degree
from where a geocentric ephemeris puts it, twice its own width.

It checks out against Meeus's Example 47.a to 0.01° in longitude and latitude
and 60 km in distance, which is the truncation's real accuracy rather than a
claim. Nine tests, green first run.

**The 18.61-year cycle emerges rather than being written down.** Nothing in the
code states that period; a test searches for when the ascending node returns to
its starting longitude and finds 18.61 years. Another sweeps twenty years of
standstill declinations and finds the envelope swinging between 28.6° and 18.3°
— beyond the solstice sun at one end and well short of it at the other. That
swing is what the Station Stone rectangle points at, and it now falls out of
the arithmetic.

The moon is drawn as the sphere it is: each point on the disc shaded by the
real angle between its own surface normal and the direction to the sun, so the
terminator is where that crosses zero. A half moon comes out straight-edged and
a crescent curved without anyone drawing either, and the horns point away from
the sun because they cannot do anything else. Earthshine lifts the dark limb.

Moonlight falls on the stones, deliberately unshadowed and dim — giving the
moon its own cascades is M5, and until then it is kept faint enough that the
missing shadows do not read as a mistake.

**Still blocked:** the constellation-figure licence. Stars and the Milky Way
wait on it.


## 2026-07-27 — the sun over *here*, not only over Wiltshire

A sundial only agrees with the clock in your pocket if it stands at your
longitude. The app now defaults to showing the sun where the device is: solar
noon falls when the sun is actually overhead for you, and the stones light and
shadow accordingly. A picker switches to Wiltshire for the monument's own sky.

Longitude comes from the device's time zone — the *standard* offset, daylight
saving removed first, at 15° per hour. Deliberately approximate and labelled as
such: a zone can be 7.5° wide, which is half an hour of solar time, and plenty
are drawn far from their meridian for political reasons. The alternative is
asking for location, and a monument that works in a field with no signal should
not need permission to say where the sun is.

Latitude stays Stonehenge's. The monument's geometry is latitude-specific — the
Station Stone rectangle is only a rectangle at 51.18° — so moving it would
quietly break the thing the app exists to demonstrate.

Verified on a device in America/Phoenix: 13:56:49 MST, sundial 13:50:16. The
six and a half minutes between them is the equation of time, with no longitude
term because Phoenix sits on its zone's own meridian. Wiltshire at the same
instant was in twilight.


## 2026-07-27 (last) — the front of every stone was being culled

"As if the surface facing the camera is transparent" was the exact
description, and it named the bug.

**Metal treats clockwise as front-facing unless told otherwise.** These meshes
are built counter-clockwise seen from outside — the right-hand rule, so that a
cross product of two edges points out. Nothing ever stated the convention, so
`cullMode(.back)` discarded precisely the faces pointing at the camera and drew
the ones behind them. What you saw was the inside of each stone's back wall.

Three earlier fixes were all real defects and none of them was this: the mesh
was watertight, the winding was self-consistent, the depth buffer was precise.
They just were not the reason.

**Why the test suite missed it.** `OpacityTests` flood-fills for background
pixels enclosed by the stone. Drawing the far faces instead of the near ones
fills exactly the same silhouette — the coverage is identical, so there was
nothing to find. Colour cannot answer this question at all.

`NearSurfaceTests` can, and does it with depth: put a stone of known thickness
squarely in front of the camera at a known range, read the depth buffer at the
centre of the frame, and invert the reverse-Z mapping. It must come back as the
distance to the **near** face. It reported 30.7999 m where the near face was at
29.2 m and the far face at 30.8 m — the far face, to four decimal places.

Fixed by stating `setFrontFacing(.counterClockwise)` on both passes rather than
inheriting a default that disagreed with the geometry.

**And a knock-on worth recording.** The ground mesh had been wound the other
way, so it had been rendering only because the convention was inverted. With
the convention corrected it faced the earth's core and vanished from above —
which the overhead shadow tests caught immediately, since they look straight
down. Ground winding now matches the stones.

78 tests green.


## 2026-07-27 (later still) — Petrie numbering, from reading the literature

Looked at what already exists rather than continuing to invent. The English
Heritage / Greenhatch laser survey of 2011 is the definitive record — 1 mm
across the circle — but it is not openly licensed, so it stays a thing to read
about. What was worth taking was free: **Petrie's numbering**, devised in
1874–77 and still the scheme every paper uses.

Stones now carry it. The outer circle is 1–30 clockwise from the sarsen east of
the axis, its lintels 101–130; trilithon uprights 51–60 with lintels 152–160;
bluestone circle 31–49, horseshoe 61–72; Altar Stone 80, Slaughter Stone 95,
Heel Stone 96, Station Stones 91–94. "Stone 56" now means something to a reader
who knows the site, where `great-upright-left` meant nothing to anyone.

It immediately caught a bug: this reconstruction raises forty bluestones where
Petrie could number nineteen, so the circle ran straight into the trilithons'
51–60 and two different stones shared an id. Surplus stones now carry a marked
scheme instead of borrowing numbers, and `testEveryStoneHasAUniqueIdentifier`
holds it.


## 2026-07-27 (later) — reverse-Z, and why the walls looked transparent

Reported as walls going see-through **at some angles** — which was the clue.
Geometry does not come and go with the camera; depth precision does.

Extending the ground to the terrain's 15 km horizon put the far plane at 40 km
against a 0.2 m near plane. A conventional projection spends nearly all of a
depth buffer's precision in the first few metres, so at that ratio two faces of
the same stone, a metre apart at sixty metres out, landed in the same depth
bucket. They z-fought, and which one won depended on the angle.

Thickening the walls would have masked it. The fix is **reverse-Z**: the near
plane maps to 1 and distance tends to 0, which puts the floating-point
exponent's dense region where the geometry is. With a float depth buffer it is
accurate across the whole range, and the far plane can go to infinity.

Camera projection reversed, scene depth comparison now `.greater`, sky
`.greaterEqual` and drawn at z = 0, depth cleared to 0 in both the view and the
offscreen path. The shadow cascades stay conventional — they are orthographic,
where precision is uniform and there is nothing to win.

`testProjectionIsReverseZ` asserts the mapping and, more to the point, that a
metre of stone at sixty metres still separates in the buffer.


In-flight state. Newest first.

## 2026-07-27 (M2) — the whole monument, standing on real ground

The plain is now the plain: `TerrainModel` displaces the ground mesh, on a grid
warped by a cubic so resolution is spent underfoot rather than on the horizon.
The monument stands at its surveyed 101 m with Stonehenge Bottom falling away
north, and the ground reaches as far as the data does.

All of it is raised: 30 sarsen uprights with a continuous, level lintel ring;
five trilithons in a horseshoe opening north-east; a 40-stone bluestone circle
and a 19-stone inner horseshoe; the Altar Stone; the Slaughter Stone and its
portal partner; four Station Stones; 56 Aubrey holes as chalk discs. Sarsen,
bluestone and chalk are distinct materials. Both states are generated from the
same rules, so the ruin is a filter over the complete monument rather than a
second model that could drift from it.

Four camera stations — aerial, Altar Stone, Heel Stone, Avenue — at a standing
eye height taken from the terrain, plus drag and pinch. On the ground, drag
turns your head and pinch narrows the field of view, because you cannot walk
backwards out of a stone circle to see more of it.

### Two placement bugs the tests caught before the eye did

- A trilithon upright was standing **inside** a bluestone: the horseshoe was at
  11.2 m and the bluestone circle at 11.6 m, 0.47 m apart. Both radii adjusted.
- The Station Stone rectangle came out **18 m across instead of 33 m**. The
  offsets had been picked because ±12° looked symmetrical; the figure is only
  the surveyed 80 × 33 m if the corners sit at ±22.3° on an 87 m circle. That
  one matters: the rectangle's proportions are the lunar alignment.

`testNoTwoStonesStandInTheSamePlace` and `testTheStationStonesFormARectangle`
now hold both, the second by checking equal diagonals rather than equal sides —
a rhombus has equal sides too.

### Why the pillars looked unclosed

Reported twice, and the mesh was watertight both times. The cause was the
parameterisation: sweeping a UV sphere onto a box spends nearly all its
vertices around the long axis and leaves the small top face covered by a ring
or two, so the top came out a coarse faceted bevel that reads as the rim of an
open tube. The stone is now a **welded box grid** — six face grids sharing
vertices by position key, rounded and displaced by functions of position alone
so shared vertices cannot disagree. Even coverage, closed top, same watertight
and opacity guarantees.


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

## 2026-07-27 — M3: deep time, and a scope cut

**Constellation figures are out.** The owner's call, and it dissolves the licence
question that had been holding up the whole of M3: Stellarium's line data is GPL,
drawing a set from IAU boundaries was work with no product in it, and licensing
one was a cost. The sky gets stars without lines. That is also closer to honest —
the figures are a two-thousand-year-later overlay on the same points of light, and
this app has a rule about not dressing later tradition as the builders' own.

**Precession landed, and it is computed.** `Precession.swift` carries the
Capitaine (2003) IAU 2006 series and derives the north celestial pole in ecliptic
coordinates: one obliquity from the ecliptic pole, swinging around it as
precession accumulates. `Star` holds seven published J2000 positions — the stars
that have held the pole or will — which is a handful of cited constants, not a
catalogue, and nothing to license.

The payoff is the brief's demo moment, and it arrives as a *search* rather than an
assertion. `testThubanWasNearestAroundTwentyEightHundredBC` sweeps −4000 to −1500
in 25-year steps and finds the minimum at 2800 BC, within half a degree. Nobody
told it that. In the same era Polaris sits more than 20° off the pole and is no
use to anyone; today it is under 1°, and in 13,700 AD the office passes to Vega.
Six tests, green first run — which after the Metal winding saga is worth noting
as the difference between a domain with a closed-form answer and one with a
convention you can only discover by reading back depth.

A known simplification, stated: proper motion is ignored. Over five millennia it
moves the brightest stars by up to a degree — enough to matter for a close call,
not enough to change which star is nearest the pole. It is in MISSION.md's
non-goals and repeated in the doc comment where it could bite.

The pole star is now a readout row, so deep time is visible without a mode switch.

**Still open in M3:** the Hipparcos star field and the Milky Way. The catalogue
needs fetching and baking into a second vendored data set, which is a
stops-and-asks under invariant 5 — raise it before doing it.

## 2026-07-27 — M4 opens: the Wheel of the Year, and a type that enforces honesty

Two things landed together because neither is any good without the other.

**`Wheel`** solves all eight stations of the year from apparent solar longitude —
the four solstices and equinoxes plus the four cross-quarter midpoints — by the
same Newton iteration `Seasons` uses, and a test asserts the two agree to a
microsecond where they overlap. Two implementations, one answer.

One bug worth recording because the shape of it recurs. Imbolc sits at 315°, and
seeding the search by mapping longitude linearly onto the calendar year puts the
first guess in mid-November; the nearest solution from there is the *following*
February, so Imbolc came out 368 days from its customary date. Newton has no
opinion about which year you meant. The fix walks whole tropical years until the
answer lands in the year asked for and re-solves — bounded, and it cannot drift
the way a hand-tuned seasonal offset would. The test that caught it was the
honesty test, not a numerical one.

**`Lore`** is the type system MISSION.md's third invariant has been promising
since the mission was written. `LoreNote` cannot be constructed without a
`LoreTier` and citations; `LoreTests` closes what the type cannot — empty
citation lists, blank sources, duplicate identifiers, and a check that all three
tiers are actually in use, because a tier nobody reaches for means the content
has quietly flattened into one voice.

The tiering is the product, not the metadata. The two solstices are `established`
as alignments. The equinoxes are `modernTradition`: nothing at Stonehenge points
at them, and an equinox is defined by arithmetic on the year rather than by
anything the sun visibly does that morning. The cross-quarters are
`modernTradition` throughout — Gaelic quarter days, medieval Irish sources,
attached to Stonehenge by Ross Nichols and Gerald Gardner in the 1950s. A test
asserts exactly that split, so softening it later requires editing an assertion
rather than a sentence.

And the wheel reports a number most calendars hide: `traditionalOffset` gives the
gap between the customary festival date and the sun's own arrival at the
midpoint. It runs three to seven days, positive — the sun is always late to the
feast. That is not an error in either direction; they are two calendars answering
two different questions, and the app shows both.

The UI gets eight jump buttons that land on the **sunrise** of the station rather
than midnight of its calendar date, with the horizon altitude measured off the
baked heightfield rather than assumed flat. The tier badge sits beside the next
station at the point of use, not in a disclaimer nobody reads.

**Next in M4:** lunar phases and standstill seasons as events, the today ribbon,
alignment moments, and the Aubrey 56 eclipse count — which ships as a toy,
labelled as one, with Hoyle's paper and Ruggles' rebuttal both cited.

### And the gate was lying

Found while chasing a compile error that `make build` had reported as success:
the build recipes ended `| tail -5`, which does two bad things at once. It hides
the diagnostics — the errors were twenty lines above the tail — and it hands the
recipe's exit status to `tail`, so **`make build` returned 0 on a failed build**.
Every "both platforms warning-clean" claim in this file was resting on a check
that could not fail.

Fixing it took three passes, which is worth recording because each failure looked
like success:

1. `.SHELLFLAGS := -o pipefail -c` — ignored. macOS ships GNU make **3.81**, and
   `.SHELLFLAGS` arrived in 3.82. `set -o pipefail` now goes inside the recipe.
2. `xcodebuild | grep ... || true` — `||` binds looser than `|`, so this parses
   as `(xcodebuild | grep) || true` and swallows the failure pipefail had just
   surfaced. Braces keep the `|| true` on grep, which legitimately exits 1 when a
   clean build gives it nothing to match.
3. Verified the only way that means anything: drop a file with a type error into
   `HengeAstro`, run `make build-mac`, confirm exit 2 and the error printed; then
   remove it and confirm exit 0.

That third step is the actual lesson, and it is the same one the Metal winding
bug taught in a different key: **a check nobody has watched fail is not a check.**
The winding bug survived a green suite because no test read back depth; this one
survived because nobody ever broke the build on purpose to see what the gate did.

## 2026-07-27 — M4 continues: the events engine and the Aubrey ring

**`Events`** solves what is coming rather than tabulating it: moon phases by
Newton on the elongation, eclipse seasons by Meeus's ecliptic limits, the
standstills by bisecting the declination envelope's own turning points rather
than reading the node's longitude. The distinction is not academic — a mean
lunation of 29.530588 days is right on average and wrong by up to fourteen hours
for any particular new moon, and an eclipse season turns on a few degrees.

The test that matters asks for 2026's eclipse seasons without being told when
they are, and gets February's annular solar, March's total lunar and August's
total solar. A second test checks the flags against the node distance in both
directions, so the plumbing cannot drift from the definition.

**Time scales, crossed once.** The ephemeris works in TT and the calendar reads
UT, and every solver here now takes TT and returns TT with the conversion done
at the boundary in `Events.upcoming`. Getting that wrong is invisible today —
ΔT is about a minute — and hours out in the builders' era, which is to say it
would be correct everywhere except the epoch the app exists for. There is a deep
time test that converts a full moon's UT instant back to TT and asserts the
elongation is still 180°.

**The Aubrey ring** ships as the hypothesis it is. Rather than simulating
Hoyle's marker-shuffling — which would be a simulation of an argument — it
projects the real computed sun, moon and node onto the 56 holes and lets the
alignment arrive. That choice makes the toy *testable against the ephemeris*,
which the marker game is not, and the score is worth stating: over the decade
from 2020, from 247 syzygies, the ring **caught 42 eclipse seasons, missed none,
and cried wolf 9 times**. Perfect recall and a 4% false-alarm rate, from three
holes of tolerance.

That is a better argument for Hoyle than a hand-wave and a better argument
against him than a dismissal, and the readout says only what the ring can say —
"holes to node" — never a prediction. `AubreyRing.note` is `debated` and carries
both Hoyle's paper and Ruggles' rebuttal; a test asserts both are present.

One bug, and it is instructive. The ring initially measured to the ascending
node alone, so with the sun at the *descending* node it read 28 holes and saw
nothing: recall 52%, and every miss was a real eclipse. The fix folds to the
nearer node. Worth noting that a self-consistency test would have passed this
happily — it took scoring the toy against the ephemeris to see it.

The UI gets a scrolling ribbon of what is coming, eclipse entries tinted, each
one a jump; and the Aubrey row.

**Remaining in M4:** alignment moments — the notification that the sun is *on*
the axis right now rather than merely near it.

### The gate immediately earned its keep

First `make build` after the fix surfaced a warning in `Terrain.swift` that
`tail -5` had been swallowing since the heightfield landed — `withUnsafeMutableBytes`
returning `copyBytes`' byte count into a discarded result. Harmless in itself,
and fixed with an explicit `_ =` and a comment saying why.

The point is the correction it forces to this file: **"both platforms
warning-clean" was not true**, in this entry or in several before it. It was a
claim resting on a check that could not fail and a filter that could not report.
It is true now, and now it means something.

## 2026-07-28 — M4 closes: alignment moments, and the definition of done as a test

`Alignment` finishes M4. The type exists because an alignment is a fact about a
*moment*, not about a day: "the sun rises on the axis at midsummer" is true to
about a degree for a week either side, because the sun's declination barely
moves at the turn — that is what a solstice is. The readout now says how far off
the line the sun is right now.

**ROADMAP.md's definition of done is now a test.** It renders the 21 June 2026
sunrise against the baked terrain and asserts the bearing is within a solar
diameter of the surveyed axis and that the first shadow runs down the Avenue.
It passed on the first run, which is the first time this project's acceptance
criterion has been a computation rather than a paragraph.

Three assumptions of mine failed, and all three were mine rather than the code's.

**"Closest approach" was the wrong question.** `bestDay` searched for the morning
the sunrise came nearest the axis and walked straight to the edge of its window
— a fortnight before the solstice. The sunrise bearing never quite *equals* the
axis; it comes within about half a degree and turns back, so "closest" has its
minimum wherever you stop looking. What the monument marks is where the sun
**stops**. Rewritten as `extreme`, solving the turning point in declination.

**The tidy deep-time story is not true.** I expected the axis to fit 2500 BC
better than today — obliquity was greater, the sun rose further north. The first
half is right and the app derives it: measured on the same horizon, the
builders' midsummer sun rose **1.03° north of ours**. But against the surveyed
49.9° the modern sunrise sits 0.41° south of the axis and the builders' 0.62°
north of it. The axis lands *between* the two eras, inside a solar diameter of
each. Which is exactly why the alignment cannot be used to date the monument —
a point the literature makes, and one the app would have quietly contradicted if
I had tuned the test until it agreed with me. It now asserts the honest version.

**The line is not equally good read both ways.** Midsummer sunrise is 0.41° off
the axis; midwinter sunset is 1.85° off its reciprocal. The two solstitial
bearings are not 180° apart at this latitude — the horizon altitude differs
between north-east and south-west, and refraction applies to opposite
declinations — so one straight axis cannot catch both. The test pins that the
sunset fit is the *worse* one rather than pretending to a symmetry the sky does
not have.

The pattern in all three is the same and worth naming, because it is the third
time this project has produced it: **the test I wanted to write was a
description of what I expected, and the useful test was a measurement of what
happens.** The Metal winding bug, the Aubrey ring's 52% recall and these are one
failure mode wearing three hats.

M4 is complete. M5 remains: lore panels in a bardic register, the design
language, weather and season dressing, sound, ceremony mode, MetalFX and 120 Hz,
the accessibility audit, moon shadow cascades, and PCSS penumbra matched to the
sun's real 0.53°.

## 2026-07-28 — M5: PCSS, and the penumbra that follows the sun

The oldest deferred item in the project. `sampleShadow` had carried a note since
M1 saying the 3×3 filter would become PCSS "whose penumbra widens to match the
sun's real 0.53°". It does now, and — the part that matters — **nothing in it is
a tuned radius.**

The sun subtends about half a degree, so every shadow edge on the plain is a
penumbra whose width is set by how far its caster stands above the ground it
darkens. A stone 4 m up softens its edge by about 4 cm; the same stone at a low
midwinter sun, throwing a shadow forty metres, softens it to nearly 40 cm. You
can watch that happen at the monument. A fixed blur looks wrong at every hour
except the one it was tuned for.

`sunRadiance.w` already carried the sun's angular radius — the same number the
disc is drawn with — and a new `cascadeRadii` uniform converts shadow-map depth
back to metres and penumbra width back to UV. Change the sun's size and the
shadows follow, which `testTheSoftnessFollowsTheSunsAngularSize` asserts by
quadrupling it.

**Three failures on the way, and all three were the measurement, not the code.**
This is now so consistent it deserves to be treated as the project's normal
condition rather than a run of bad luck.

1. **The ruler was coarser than the thing measured.** The suite framed the whole
   shadow: 120 m across 512 pixels, one pixel 0.23 m, measuring a 0.17 m
   penumbra. Every reading came back as the same three pixels whatever the sun's
   size — which reads exactly like PCSS not working. The camera now frames the
   shadow *tip*, twelve metres across.
2. **The camera was in the wrong cascade.** At 120 m up the ground selects
   cascade 2, where one shadow texel covers 0.2 m — a 4 cm penumbra cannot be
   represented there at all, so both stone heights clamped to the texel floor
   and returned byte-identical numbers. Dropped to 20 m, inside cascade 0, where
   a texel is 1.4 cm.
3. **The blocker search capped the filter.** A fixed eight-texel search meant a
   4× sun widened the penumbra by only a third: the filter may never exceed the
   region the blocker was found in. The search radius is now derived the same
   way the penumbra is — a blocker within one cascade radius gives at most
   tan(θ)/2 in UV, independent of the radius, so tan(θ) covers it with headroom.
   At 0.53° that is about nine texels at 2048, near enough to the constant it
   replaces, but it now scales with the light.

The shadow-agreement test still passes unchanged at its M1 tolerance, which is
the result worth having: softening the edge did not move it. The penumbra's
midpoint sits where the hard edge was, so the calendar is still measuring what
it was measuring.

### Lore panels, accessibility, and where this stops

`LoreView` gives the tier system somewhere to be read. Every panel wears its
tier and its sources — one tap away rather than always open, because a wall of
citations under every paragraph turns the register from bardic into
bibliographic, but never further than one tap. The badge is deliberately neither
subtle nor alarming: "modern tradition" is not a warning. Beltane is a real
thing that real people really do. It is simply not Neolithic, and the reader
gets to know which they are holding.

Accessibility is invariant 7, so it is not an M5 nicety. Reduce Motion caps the
time-lapse at 100× rather than removing it — the calendar still runs, it just
does not spin — and clamps on the way in so a restored rate cannot outrun the
setting. The readout's fixed 210-point rows clipped at the larger Dynamic Type
sizes and now size themselves.

**M5 is partly landed and I am stopping here rather than pretending otherwise.**
Done: PCSS, lore panels, reduced motion, Dynamic Type. Not done: ambient sound,
torchlit ceremony mode, weather and season dressing, the "Mistletoe & Oak"
design language as an actual design rather than a functional layout, MetalFX,
120 Hz profiling, and moon shadow cascades — moonlight is still unshadowed and
kept dim enough that the absence does not read as a bug. None of those is
blocked; they are simply unbuilt.

Two things remain blocked on a decision, and neither has been taken
unilaterally: **vendoring the Hipparcos catalogue** for the star field, which
invariant 5 makes a stops-and-asks, and whether the **Milky Way** is worth a
licensed texture or should be dropped the way constellation figures were.

Nothing in this repository has been pushed. Eighteen commits sit local past
`v0.0.1`, awaiting the owner's word.

## 2026-07-28 — The chrome, and real surfaces

### The navigation overlay is gone

It was a slab of controls with sliders for bearing, height and range, floating
over the monument — in front of the thing it existed to help you look at, taking
the bottom third of the sky at exactly the hour the sky is worth watching. And
the sliders duplicated gestures that already worked: drag turns the view, pinch
pulls it in. A control that does what your thumb already does is furniture.

**Where you stand is now a tab bar**, which is what it always was — a choice
between four named places, not a continuum. Fine adjustment stays on the
gestures, and Recentre became a double tap, which is what people try anyway.
The rate slider became four labelled steps (real time, a minute a second, an
hour, a day); the log slider spent most of its travel in speeds where nothing
was legible.

Panels are glass — Liquid Glass where the OS has it, `.ultraThinMaterial`
elsewhere, and the fallback is not a consolation prize because the property that
matters is that the panel takes its colour from the sky behind it rather than
asserting one of its own.

`Theme.swift` is "Mistletoe & Oak", such as it is. The druidic register is
`Font.Design.serif` — New York, a modern face with old bones — because **a
typeface is data with a licence** and invariant 5 applies to it as much as to a
star catalogue. Numbers stay monospaced: an almanac that reflows its digits as
time runs is unreadable. Palette is desaturated stone, oak and bronze; nothing
with a strong colour of its own may sit over a physically-modelled sunrise and
lie about the light. The lore tier badges moved off the system traffic-light
colours for the same reason orange-and-green was wrong there — a modern-tradition
note is not a caution.

### Real surfaces

CC0 material sets from ambientCG (`Rock030`, `Grass004`) — colour, normal and
roughness — triplanar on the stones, tiled on the ground. Triplanar because
`StoneMesh` deliberately carries no UVs: any unwrap of a welded box grid seams
somewhere visible. Three fetches instead of one, and no seam. The ground gets a
second sample at an incommensurate frequency multiplied in, because one grass
tile repeating across fifteen kilometres is the most obvious tell in any outdoor
scene.

**The photographs supply detail, not colour.** Each map is divided by its own
mean and multiplied by the material albedo, so `SurfaceMaterial` still decides
what colour a stone is — sarsen and bluestone are different rocks and the app
says so. A single photographic albedo would flatten them into one.

The request was for granite. Recorded in SECURITY.md, and worth repeating: the
monument has none. The uprights are sarsen, a silcrete, and the smaller stones
are Preseli dolerite and rhyolite. Granite is speckled feldspar and mica and
would read as the wrong stone to anyone who has stood there, so a weathered grey
rock was used instead.

### Two bugs, and one of them mattered

**Unbound textures are not "no texture", they are black.** Adding a
`surfaceTexturing` flag, I stopped *binding* the maps but the shader kept
sampling them — and a sample from an unbound slot returns zero, which multiplied
the entire world to nothing. The geometry tests reported a lit/shade contrast of
0.003 and no shadow edge anywhere. The flag has to reach the shader as a branch.

**The shadow bias must use the geometric normal.** Normal mapping swings the
shading normal by tens of degrees across a rough rock face, and the slope-scaled
depth bias is computed from n·l. Feeding it the bumped normal would make the bias
flicker texel to texel — acne on some pixels, peter-panning on their neighbours.
Caught by reasoning rather than by test, and the comment says why so it survives.

### And an honest note about the oracle

The geometry tests — shadow agreement, penumbra width, opacity — now render
**untextured**, and that deserves scrutiny rather than a footnote, because
switching a feature off inside a test is exactly how a bug hides.

Those tests read the shadow edge out of image luminance. Textured turf varies in
luminance by more than the shadow does: measured lit/shade contrast fell from
comfortably past the guard threshold to 0.03–0.045, with grain of comparable
amplitude on top. The edge did not move — the instrument stopped being able to
see it. Loosening the guard would have meant measuring noise and calling it
agreement. So the geometry oracle renders flat, and `testTexturingIsOnByDefault`
asserts the shipping path does not, because without it the whole app could ship
untextured with every test still green.

144 tests, both platforms warning-clean, and the macOS app launches and stays up.

## 2026-07-28 — Zoom, glass, weathering, and the shadow that was never there

### The one that matters: no shadows at sunrise

`buildFrameUniforms` gated the cascade fit on `sunDirection.y > 0.01`. That is an
altitude of **0.573°**, so the monument cast no shadow at all between the sun
appearing and its clearing half a degree of sky. The definition-of-done moment
and its midwinter mirror — the two instants the entire app is built around — drew
flat. The comment said the fit "produces garbage" below the horizon, which is
true, and 0.573° is not below the horizon.

A second fault sat behind it, and it was the larger one. Cascade boxes are fitted
to the *view* frustum, and a caster need not be visible to throw a shadow into
frame — at a grazing sun it usually is not. Standing at the Altar Stone at
sunrise, the thing shadowing you is behind you. With the light's eye at twice the
cascade radius, a stone thirty metres upwind fell outside the box, never reached
the depth pass and cast nothing. Pullback is now six radii over a thirteen-radius
box, and that span is passed to the shader in `cascadeRadii.w` rather than
hardcoded twice, because PCSS converts depth differences back into metres and
would otherwise mis-scale every penumbra the moment the two drifted.

**The first test I wrote for this did not catch it, and that is the interesting
part.** It measured shadow on the *ground*, and at 0.3° altitude the ground is
lit at 89.7° incidence: it receives almost nothing, so removing the sun from it
removes almost nothing. Readings were identical to three significant figures with
the bug present and absent. At sunrise the shadow lives on the **vertical
faces**, lit nearly head-on — which is also where you see it at the monument, the
Heel Stone's shadow thrown across the uprights.

Rewritten as a differential: render a receiving stone alone, render it again with
a caster upwind, require the second to be darker. Verified the only way that
counts — restored the old gate and watched five assertions fail, then restored
the fix and watched them pass. The threshold is 5% against an observed 8.7%,
which is modest on purpose: at sunrise the direct sun is heavily attenuated by
airmass and much of the light on that face comes from the sky. What the assertion
separates is a shadow from *no shadow at all*, and no shadow at all is 0.0%.

Two other measurements moved rather than their tolerances, both correct physics:
a 7 m stone at 20° throws its shadow 19 m and cannot reach a receiver at 30 m,
and at 10° it clears the receiver's foot but not its middle.

### Weathering

Four procedural effects over the photographic rock, each keyed to something
physical: a damp foot where groundwater wicks up (wet rock is darker *and*
glossier — lower albedo, lower roughness); lichen on upward ledges and the
sheltered north-east faces, which dry slowest, in the yellow-green of *Xanthoria*
and *Rhizocarpon* and matte because lichen is; rain streaking on vertical faces,
noise stretched hard along Y because that anisotropy is what makes a streak read
as a streak rather than a stain; and wind scour lightening the exposed tops.
Value noise, four octaves, seeded per stone from `Stone.seed` — nothing vendored,
and no two stones weather alike.

The test asserts the *shape* rather than a number: the base darkens and the upper
half does not. Weathering that dims the whole stone is a tint, not a damp course,
and a single-band measurement could not tell them apart — the first attempt read
a diluted 0.8% because the band straddled the stone's foot and the turf below it.

### Zoom and glass

Zoom worked on iPad and effectively did not on the Mac, where the gesture people
reach for is a two-finger scroll and SwiftUI has no gesture for it. The scene is
an `MTKView` behind an `NSViewRepresentable` and scroll events route by
hit-testing, so a transparent catcher would have had to be hit-testable — and
would then have swallowed the clicks the drag gesture needs. A local event
monitor sees the events without taking part in hit-testing at all. Trackpad and
wheel get separate divisors, because scaling both the same way makes the wheel
useless or the trackpad frantic, and the response is exponential because zoom is
multiplicative. Drag and magnify are now composed with `simultaneously` rather
than stacked, so a `minimumDistance: 0` drag cannot claim a pinch's first finger
and swing the view while the second is still arriving. VoiceOver gets explicit
zoom actions — it cannot pinch, and invariant 7 means a gesture-only control does
not exist for anyone using it.

The panels were already glass; what they lacked was a `GlassEffectContainer`.
Liquid Glass is not a per-view backdrop blur — nearby elements merge, refract
together and share one lensing pass. Without a container each panel is its own
island, which reads as several stacked plates of frosted plastic rather than one
piece of glass. The lore sheet takes a glass presentation background too, so the
monument stays faintly present behind the reading.

151 tests, both platforms warning-clean.

## 2026-07-28 — Reflections, matte grass, and wind on the plain

### The sky, reflected

Until now the only specular in the scene came from the sun, so away from its own
highlight every surface was purely diffuse — and a wet sarsen with no sheen off
the sky above it reads as chalk. The sky model is closed form, so it can simply
be evaluated down the reflection vector: the actual colour of the actual sky in
the direction the surface is looking. At dawn that puts the sunrise itself
faintly on the eastern faces, which is the whole point of the app. Weighted by
Fresnel, since reflections strengthen at grazing angles and that is most of why
wet things look wet, and folded down by roughness.

### Grass does not shine

`sampleGround` floored roughness at 0.2 — a polished floor, not a hillside — and
grass carried the full dielectric F0 of 0.04. Grass is not a solid surface: it is
a mass of thin blades with air between them, and most of what would be a
specular lobe scatters instead. Materials now carry a specular strength and a
roughness floor, turf at 0.22 and 0.74.

The test for it was wrong twice, in the two ways a rendering test usually is.
It looked *away* from the sun, so it could not have found a highlight if one
existed — a specular lobe only appears between viewer and light. And it sampled
to the horizon, where aerial perspective blends turf into sky, then read that fog
as a highlight thirty-two times the median. Reframed to look toward the sun and
sample the near ground, the ratio is 1.43 on a well-lit field. It also asserts
the ground is bright enough for the question to mean anything, because a black
frame has no highlight either.

### Wind

No blade geometry. What you actually see of wind in grass at eye height on a
plain is not individual blades but the *shading* changing as gusts lay the sward
over — the pale travelling cat's-paws that cross a meadow ahead of a squall.
That is a reflectance effect and belongs where reflectance lives.

Noise advected along the wind, which is what makes gusts travel rather than
pulse in place; two scales, because real wind has two. Bending both tilts the
normal downwind and pales the surface, and both are needed: the tilt changes n·l
so a gust reads differently depending on where the sun is, while a pure albedo
wobble would look identical in every light.

**Wind keeps wall-clock time, never the astronomical clock.** Time here runs at
up to a day a second; a breeze scaled by that would be a strobe, one frozen while
time is paused would be a photograph. It advances from real elapsed seconds and
is not gated on `isPlaying`.

Two bugs found by measurement rather than by looking:

**The gust fronts were bigger than the ground.** At 40 m a front is larger than
the patch a standing viewer has in front of them, so the whole near field gated
on and off together rather than a wave crossing it — six seconds of wind produced
a byte-identical frame. Fronts are now ~33 m and the ripple ~3 m, both varying
within a few paces. The hard gate became a soft modulation for the same reason:
wherever the front was weak the grass was perfectly still, and a windy day does
not look like that. The sward is always working; gusts are where it works hardest.

**Spatial and temporal factors must match.** `p·k − dir·speed·t·k` advects the
pattern at exactly `speed` m/s. Different factors send the gusts across the plain
at some speed other than the wind's, which reads as wrong without being nameable.

The shader also failed to compile at one point — `windField` called an `fbm`
declared below it, and MSL has no forward declarations. Nothing rendered at all,
which the suite caught instantly. The one failure mode a pixel test cannot miss.

### And a test target that should have existed

`SkyModel` is the app's whole state machine — every jump, every clock, every
number the almanac prints — and had no tests whatever until the wind needed one
and there was nowhere to put it. `HengeUITests` now covers the wall-clock/sky-clock
split, that the scene and the almanac share one sun, that station jumps land on
the sun's arrival rather than a calendar date, and that zoom is bounded at both
ends in both kinds of view.

163 tests, both platforms warning-clean.

