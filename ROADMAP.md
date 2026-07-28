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

- [ ] **M5 — The Soul (L).** Lore panels in a bardic register with every claim
      tiered and cited. "Mistletoe & Oak" design language. Weather and season
      dressing — solstice mist down the Avenue, frost, rain on the bluestones.
      Ambient sound. Torchlit ceremony mode. Hosek–Wilkie sky if its data
      licence clears. MetalFX, 120 Hz, and the accessibility audit.

## Definition of done for the demo

Scrub to 21 June 2026, 04:52 BST and stand at the Altar Stone: the sun breaches
the horizon beside the Heel Stone and its first shadow spears down the Avenue
into the heart of the circle, within a solar diameter of where it does in
Wiltshire.
