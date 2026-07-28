# henge — roadmap

Forward direction as sized milestones. Sizes: S ≤ 1 session, M = 1–2, L = 2–4.

- [x] **M1 — The Light (L).** *Landed 2026-07-27.* Metal renderer, terrain
      plane, one procedural trilithon and the Heel Stone on the true axis;
      `HengeAstro` sun position, ΔT and seasons; Preetham physical sky with the
      sun disc at its real angular size; three-cascade sun shadows; time
      scrubber to 100,000×. **The shadow-agreement test landed here** — it is
      the gate that makes everything after it trustworthy.

- [x] **M2 — The Stones (L).** *Mostly landed 2026-07-27.* The full monument in
      both states: 30 sarsen uprights and a continuous lintel ring, five
      trilithons, bluestone circle and horseshoe, Altar Stone, Slaughter Stone
      and portal, four Station Stones, 56 Aubrey holes. Terrain displaced into
      the ground from the surveyed heightfield. Sarsen / bluestone / chalk
      materials. Four camera stations at 1.7 m eye height, drag and pinch.
      **Still outstanding:** the ditch, bank and Avenue earthworks; lichen and
      weathering maps; PCSS penumbra widening (and with it the re-measured
      shadow tolerance).

- [~] **M3 — The Night (L).** *Moon landed 2026-07-27.* Position, phase,
      distance and apparent size from a truncated ELP-2000; topocentric
      parallax; the 18.61-year nodal cycle and standstill envelope, emerging
      from the arithmetic rather than scripted. Rendered as a sphere lit by the
      real sun direction, with earthshine, plus unshadowed moonlight on the
      stones. **Remaining:** Moon with correct phase geometry, earthshine and
      apparent size; the 18.61-year nodal cycle so standstills emerge rather
      than being scripted. Hipparcos star catalogue, constellation lines, Milky
      Way. Precession and deep-time mode — Thuban as pole star.
      **Blocked until `SECURITY.md`'s constellation-figure licence is settled.**

- [x] **M4 — The Calendar (M–L).** *In progress.* The Wheel of the Year has
      landed: eight stations solved from apparent solar longitude, festival
      jumps that land on the sunrise of the day rather than midnight of a
      calendar date, and the tier badge shown at the point of use. The lore
      type system landed with it — `LoreTier`, `Citation`, `LoreNote`, and the
      tests that make MISSION.md's third invariant enforceable rather than
      aspirational. Note the honest number the wheel exposes: the customary
      cross-quarter dates run three to seven days ahead of the sun.

      **Complete.** The events engine solves moon phases, eclipse seasons and
      the standstills from position; the ribbon shows what is coming and jumps
      to it; the Aubrey 56 counter ships badged as hypothesis and scored
      against the ephemeris (42 caught, 0 missed, 9 false alarms over a
      decade); and `Alignment` answers how far off the line the sun is right
      now. The definition of done below is a passing test.

- [~] **M5 — The Soul (L).** *Partly landed.*

      **Done.** PCSS penumbra derived from the sun's real angular size, with a
      test that quadruples the sun and watches the shadows follow — the oldest
      deferred item in the project, flagged in M1 and closed here. Lore panels
      with the tier badge and sources at the point of reading. Reduced-motion
      support (the time-lapse caps at 100× rather than disappearing) and a
      Dynamic Type pass on the readout. *Landed 2026-07-28:* golden-hour light
      shafts marched against the real shadow cascades (the first piece of
      weather dressing); per-seed individual stone meshes over a multifractal,
      with variance-preserving texture blending and micro-shadowing; the
      geometry overlay and gold Aubrey-marker modes, tier-badged on screen;
      the almanac as a top strip with phase glyphs.

      **Not done, and why.** Ambient sound and torchlit ceremony mode are real
      work with no blocker other than time. Weather dressing beyond the haze
      (cloud, rain, frost) likewise.
      "Mistletoe & Oak" as a full design language is unstarted — what exists is
      a functional layout, not a designed one. Hosek–Wilkie still waits on its
      data licence. MetalFX is unexplored; 120 Hz is set on the view but has not
      been profiled. (Moon-cast shadows are no longer on this list: the shared
      cascades are fitted to the moon when it is up and bright enough, and only
      thin-crescent nights fall back to unshadowed moonlight.)

## Still open, needing a decision

- **Hipparcos star catalogue** (M3). ESA, free with attribution. Vendoring a
  second data set is a stops-and-asks under invariant 5 — unasked as yet, so
  the sky has no stars.
- **The Milky Way** (M3). Needs a licensed texture. May be worth dropping the
  way constellation figures were.

## Definition of done for the demo

Scrub to 21 June 2026, 04:52 BST and stand at the Altar Stone: the sun breaches
the horizon beside the Heel Stone and its first shadow spears down the Avenue
into the heart of the circle, within a solar diameter of where it does in
Wiltshire.

**This is a passing test** — `AlignmentTests.testTheDefinitionOfDone`, run
against the baked Salisbury Plain heightfield. It asserts the sunrise bearing
is inside one solar diameter of the surveyed axis and that the first shadow
runs down the Avenue. An acceptance criterion that is prose can be argued
with; this one cannot.
