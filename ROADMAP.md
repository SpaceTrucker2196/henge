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
      real sun direction, with earthshine, plus moonlight on the stones.
      *Landed 2026-07-28:* the Hipparcos naked-eye sky with proper motion and
      precession — Thuban emerges at the 2800 BC pole from arithmetic; the
      five naked-eye planets from truncated VSOP87D, steady among shimmering
      stars; the Moon's photographed face (NASA LRO) at a doubled display
      size; the full IAU name register in a labels layer; Prussian night and
      starlit ground. *Landed 2026-07-29:* the zodiac as twelve labelled
      constellation centroids riding the precessing sky, glyphs and all,
      behind their own toggle. *2026-07-30:* the macOS starless-night escape
      found and closed — the catalogue's flat resource lookup failed in the
      one bundle layout the test suite does not build; the lookup the Mac
      needs is now pinned by a test. *Landed 2026-07-30:* the constellation
      figures — the licence problem dissolved by drawing our own: 29
      figures, 188 segments authored by hand against the vendored
      catalogue (membership is Ptolemy's, positions are Hipparcos's, the
      drawings are ours), riding the same instance buffer as the stars so
      they precess for free. Along the way the authoring caught a shipped
      register bug: multi-word IAU names truncated at the first space —
      the sky was labelling three stars "Kaus". **Remaining:** the Milky
      Way (licence undecided) — now the only thing left of M3.

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

      *Also landed 2026-07-28:* the torchlit ceremony mode (night-gated,
      wall-clock flicker); weather as chosen dressing — overcast, rain,
      frost — with every decision a tested CPU function; the app icon.

      *Landed 2026-07-29:* the chrome's settling. One twelve-point rhythm
      throughout; enclosure spent only where it informs — glass pills mark
      what responds, bronze marks what is true, readouts sit bare (the
      full Tufte de-boxing was tried and the owner correctly pulled it
      back to pills-as-affordance within the hour). Drawer handles became
      part of their drawers: tabs fused into the plates' silhouettes, the
      rail's handle its own first pill, closed tabs flush to the bezel.
      Launch gained a face — the mark on pre-dawn slate, then terrain and
      sky at once while the stones raise asynchronously behind the
      progress card. Date travel to any date in the model's range, the
      attributions view, deeper twilight, and dynamic inks for light
      appearance all shipped around it. The upside-down rebuild card in
      landscape became the project's first *pixel-level* inspection:
      `make uitest` screenshots the running app and holds render truth
      against layout truth, because the accessibility tree swore the text
      was fine while the screen showed it rotated.

      **Not done, and why.** Ambient sound is real work with no blocker but
      time — and a licence conversation for any recorded material.
      Hosek–Wilkie still waits on its data licence. MetalFX is unexplored;
      120 Hz is set on the view but has not been profiled. (Moon-cast
      shadows are no longer on this list: the shared cascades are fitted
      to the moon when it is up and bright enough, and only thin-crescent
      nights fall back to unshadowed moonlight.)

- [~] **M6 — The Ship (M).** *Pipeline landed 2026-07-29; standing at the
      human gate.* fastlane is the iOS front door: build, release proof,
      the one-command simulator loop, the pixel inspection, and `beta` —
      archive, automatic signing minted by the App Store Connect API key,
      build number from TestFlight, upload. The bundle id io.river.henge
      is registered and a signed App Store .ipa has been produced —
      re-proved 2026-08-04 with the paywall and the nine languages aboard:
      `Apple Distribution: river.io llc`, `UIDeviceFamily [1, 2]`, all nine
      `.lproj` present in both resource bundles.
      **Blocked on two owner actions, both behind Apple ID 2FA:**
      (1) Apple will not let an API key create the app *record* — the
      `apps` resource refuses `CREATE`, re-verified against both keys on
      2026-08-04. One-time `fastlane produce` with an Apple ID, or App
      Store Connect → My Apps → ＋.
      (2) The in-app purchase must be created in App Store Connect:
      non-consumable, product id `io.river.henge.full`, $4.99. Without it
      `Product.products(for:)` returns nothing and the paywall shows only
      its fallback price — the button looks right and does nothing.
      Then `fastlane ios beta` puts the first build on TestFlight. macOS
      distribution is not started; the app icon needs its store-quality
      pass on nobody's list but ours.

- [x] **M7 — The Ground Plan (M).** *Owner requests, 2026-07-31; landed the
      same day.* (1) The year bar's moon lights jump to the *moonrise* of
      their day, on a new sample-and-bisect lunar rise solver with the
      honest monthly no-rise fallback. (2) The sunrise landing was verified
      as an assertion over all eight stations rather than a recollection
      about one. (3) The geometry page was read into the wiki, tiered
      Speculative, and the overlay gained cardinals, feature labels and
      surveyed measurements mapped to the ground. Items as originally
      captured below.

      1. **Moon-phase jumps land on moonrise.** "When clicking a moon phase the
         time should go to moon rise." The events ribbon (M4) already jumps to
         solved events; the festival jumps already land on *sunrise of the day*
         rather than midnight. Moon-phase events should get the equivalent
         treatment against moonrise, which means a rise-time solve for the Moon
         alongside the existing sun one. Note the honest edge case: a phase can
         fall on a day when the Moon does not rise at all at high latitude, so
         the fallback needs deciding rather than crashing.

      2. **Solar-holiday jumps land on sunrise.** "For the solar holidays go to
         the sun rise." M4 records that Wheel-of-the-Year jumps already land on
         the sunrise of the day — so this is either a regression, or it does not
         hold for all eight stations. Verify against the ribbon before building
         anything; if it already works, close this and say so.

      3. **The geometry page, then the ground plan on screen.** "Read
         https://stonehengeology.com/stonehenge-geometry and add its knowledge
         to the wiki, then lay out the geometry it references in our view with
         the cardinal directions. Add labels in that view along with
         measurements mapped to the ground." The lore system (`LoreTier`,
         `Citation`, `LoreNote`) is the place for the reading, and every claim
         from that source needs a tier — it is one author's reconstruction, not
         survey data, so it is almost certainly *hypothesis* rather than
         *established*, and MISSION.md's third invariant makes that
         enforceable. The drawing half extends the existing geometry-overlay
         mode (M5): cardinal directions, labelled construction lines, and
         dimensions projected onto the terrain rather than floating.

## Still open, needing a decision

- **The Milky Way** (M3). Needs a licensed texture. May be worth dropping the
  way constellation figures were.

(The Hipparcos star catalogue was asked, answered and vendored 2026-07-28 —
the naked-eye sky is in, with proper motion and precession, attribution in
`SECURITY.md`. Constellation lines remain blocked on their licence.)

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
