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
      *Since landed:* the ditch, bank and Avenue earthworks
      (`Earthwork`, 2026-07-31); lichen and weathering in the stone shader
      (2026-07-28); PCSS penumbra widening (M5, 2026-07-28). Nothing of M2
      is outstanding.

- [x] **M3 — The Night (L).** *Complete 2026-09-15.* *Moon landed 2026-07-27.* Position, phase,
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
      the sky was labelling three stars "Kaus". *Landed 2026-09-15:* the
      Milky Way from NASA's Deep Star Maps (public domain, Gaia-derived),
      precessing with the stars; and a zodiac-only sky switch that keeps
      the twelve figures' stars and the planets and puts the rest out. M3
      is complete.

- [x] **M4 — The Calendar (M–L).** *Complete.* The Wheel of the Year has
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
      **Both App Store Connect gates are through as of 2026-08-04.**
      The app record exists — Henge, `io.river.henge`, Apple ID
      6798126839, SKU `io.river.henge`, iOS 1.0 Prepare for Submission —
      created in the web console, because Apple's `apps` resource refuses
      `CREATE` for an API key and does so for every repo here, not just
      this one. The in-app purchase exists too: `io.river.henge.full`,
      non-consumable, $19.99 base USD across 175 regions, English
      localisation written.
      One thing the console turned up that nothing else would have: an
      older record was already holding the name "Henge" on the bundle id
      `riverio.henge`, with an expired TestFlight build that had locked
      its bundle id permanently. It is renamed "Henge (retired)" rather
      than deleted, so its history survives and the name is free.
      **The first build is on TestFlight**: 0.1.0 (1), uploaded by
      `fastlane ios beta` and processed to *Ready to Submit*, expiring in
      90 days. The lane created the "Stone Circle" external group. Beta
      App Description and Feedback Email are written.
      **Submitted to Beta App Review 2026-08-05**; 0.1.0 (1) is *Waiting
      for Review* in "Stone Circle", whose public link is already live at
      `https://testflight.apple.com/join/YJk7Uejj`. Test Information is
      complete: beta description, feedback address, reviewer contact,
      review notes, and What to Test. Sign-in is declared *not* required,
      which is true — the app has no account and no network.
      **On sale.** The version record moved to 0.1.0 and the build went
      to review with the non-consumable; 0.1.0 reached *Ready for Sale*
      in August, and **0.2.0 has been Ready for Sale since 2026-08-27**
      (App Store Connect API, checked 2026-09-15) at $19.99 for the full
      unlock. The landing and wiki pages point at the listing and the
      twelve-minute walkthrough.
      **macOS** ships outside the store: `make dmg` / `scripts/build_dmg.sh
      --release` builds the universal Release app into a verified image,
      tags a GitHub release and stages the download at www.river.io/henge.
      Only **v0.1.0 (early build)** has gone out that way, 2026-08-03; the
      download page states how it is signed.
      **0.2.1 submitted 2026-09-15** (23:29 UTC): the refraction and
      skyline corrections, the Milky Way, the zodiac-only sky, the credits
      and the measured frame budget. Build 0.2.1 (2) went up by `fastlane
      ios beta`; the version record, What's New in nine languages, the
      build attachment and the review submission were all done through the
      API (`scripts/asc.py` plus a POST/PATCH helper) — for an update, with
      the purchase already approved, nothing needed the console. State:
      *Waiting for Review*. The Mac image `Henge-0.2.1.dmg` is published
      at the v0.2.1 GitHub release and committed into the river-io-site
      checkout, not pushed.
      **Left:** (1) The app icon's store-quality pass, on nobody's list but
      ours. (2) A Developer ID for the Mac image, so the download stops
      admitting to ad hoc signing.

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

- **Ambient sound** (M5). Wind over the plain, birds at dawn, the torch's
  fire. No blocker but time — and a licence conversation for any recorded
  material, which synthesis would avoid entirely. The invariant-5 question
  (provenance first) applies to sound as it did to every texture.
- **Hosek–Wilkie sky** (M5). Waits on its data licence. Preetham serves.
- **MetalFX and 120 Hz** (M5). Unexplored and unprofiled; researched
  2026-09-15, see below.

(Settled since this list was written: the Hipparcos catalogue, vendored
2026-07-28; constellation figures, drawn in-repo 2026-07-30; the Milky Way,
NASA's public-domain map, 2026-09-15; the north-east skyline, moved from
SRTM to bare-earth LiDAR 2026-09-15 after a photographic panorama from the
circle showed the radar bake a quarter of a degree high.)

## Next, in order

1. **Ambient sound**, synthesized (M5).
2. **Icon store-quality pass** and a Developer ID Mac image (M6).
3. **Frame budget, second pass** (M5): the scene pass itself is what
   stands between 52 and 60 fps at the sunrise on M-class iPads.

## MetalFX and 120 Hz — research note, 2026-09-15

**What is true today.** `SceneView` asks the `MTKView` for 120 frames a
second. On iPad Pro that request is honoured; on iPhone it is inert,
because iOS caps third-party Metal views at 60 Hz unless the Info.plist
carries `CADisableMinimumFrameDurationOnPhone = YES`, and ours does not.
No frame has ever been timed. The drawable is native scale (2× on iPad,
3× on iPhone), single-sampled `bgra8Unorm`, and a frame is three shadow
cascades at 2048² plus the scene pass plus, in the golden hours, the
light-shaft march.

**First measurement** — GPU time per frame from the command buffer's own
clock (`gpuEndTime − gpuStartTime`), full monument, `swift test` harness
on the build Mac's **Apple M5 Pro**. Median of 20, after warm-up:

| Pixels | Golden hour, shafts, grass | Golden hour, no shafts, no grass | Noon, grass | Night, stars + Milky Way, grass |
|---|---|---|---|---|
| iPad Pro 13" native, 2752×2064 | 34.8 ms | 20.4 ms | 29.4 ms | 13.5 ms |
| iPhone 17 Pro native, 2622×1206 | 23.9 ms | 10.0 ms | 16.3 ms | 12.4 ms |
| iPad Pro 13" at 1×, 1376×1032 | 12.8 ms | 5.7 ms | 10.3 ms | 8.7 ms |

Read with three caveats, all of which make the real numbers *worse* than
the table except the first: (1) the harness renders in bursts with a
blocking wait, so the GPU never clocks up — minimums ran 30–40 % under
the medians and a sustained loop would sit nearer them; (2) this is a
16-core desktop-class GPU, and the iPad's M5 and the iPhone's A19 Pro
are slower; (3) the harness is a debug build, which does not touch GPU
time. What the table says regardless: **at native resolution the app is
a 30 fps app in the golden hour and a 60 fps app at night**, on the best
hardware it will ever run on. 120 Hz is out of reach by a factor of three
to four. The frame is fill-rate bound — quartering the pixels cut the
golden hour from 35 ms to 13 — with grass worth 8–9 ms at iPad
resolution and the shafts 6 ms on top.

**What MetalFX offers, and to whom** (Apple's documentation feed,
2026-09-15). `MTLFXSpatialScaler` and `MTLFXTemporalScaler`: iOS 16 /
macOS 13, so every device this app ships to (deployment iOS 17, macOS
14), gated by `supportsDevice`. `MTLFXTemporalDenoisedScaler`: iOS 18 /
macOS 26. `MTLFXFrameInterpolator` and the Metal 4 `MTL4FX*` family:
iOS 26 / macOS 26 only, needing colour, depth and per-pixel motion
vectors — which this renderer does not produce.

**Second measurement, on the iPad itself** — the owner plugged it in the
same afternoon. iPad Pro 13" (M5), Release build, Metal System Trace
attached for 15–20 s per run, frame cadence read from CoreAnimation's
`ClientDrawable` signposts (one per presented frame), each variant a
temporary patch reverted after its build. **A correction, recorded rather
than tidied away:** these runs were meant to stand at the Altar Stone at
the midsummer sunrise, but the app opens on the device's own location and
the patch left it there — so the scene was Arizona at civil dusk, sun
4.5° down, a first-quarter moon casting the shadows. Full monument, full
grass, same passes; the *relative* costs below hold, the label did not.
The true sunrise is measured in the third table.

| Variant | Median frame | Rate |
|---|---|---|
| As shipped | 29–33 ms | 30–34 fps, GPU 85 % busy |
| Light shafts off | 29 ms | 34 fps — no change: at first flash the sun is below the shafts' 0.2° gate, so they were not running |
| Grass blades off | 21 ms | 48 fps |
| Render scale 0.7× (1926×1445, confirmed in the trace) | 21 ms | 48 fps |
| Shadow cascades 1024² instead of 2048² | 29 ms | 34 fps against a 33 ms baseline in the same warm state |

The device warms across back-to-back runs — two identical baselines gave
29 and 33 ms — so read differences of a few milliseconds as indicative.
The shape is unambiguous: **the sunrise is a 30 fps frame on the best
iPad there is; grass and pixel count are each worth about 10 ms of it;
the shadow cascades about 4 ms.** The Mac estimate above was right to
within its own caveats.

**Third measurement — the true sunrise, before and after.** Viewpoint
Wiltshire, standing at the Altar Stone, 04:00 UT on 21 June 2026 with the
sun 0.7° up and the light shafts running, time playing at 1×, frame times
printed by the app itself over the device console (Instruments had lost
the device by then; `devicectl` had not). iPad Pro 13" (M5), Release:

| | Median frame | Rate | Shadow pass |
|---|---|---|---|
| As shipped in 0.2.0 | 30.8 ms | 32.5 fps | every frame |
| With the three changes below | 19.1 ms | 52 fps | once in 120 frames |

The three changes landed together on 2026-09-15 (the commit after this
note): the scene drawn at 0.7× and lifted to the drawable by
`MTLFXSpatialScaler` wherever a device has it; the grass field thinned
as the inverse square of distance beyond 8 m, its far blades widened to
about a pixel of ground (a third of the blades, the same turf); and the
shadow cascades refitted only when the light, the camera or the stones
have moved enough to see (`ShadowRefit`), at 1024² on iPhone
(`RenderBudget`). Screenshots of the two frames are indistinguishable at
arm's length. What remains between 52 and 60 is the scene pass itself.

**Recommendation, in order** — as written before the work, kept for the
record; items 1–3 are done.

1. **Render scale with MetalFX spatial upscaling** — the measured lever.
   Draw sky, scene and shafts at 0.7× into an offscreen target and let
   `MTLFXSpatialScaler` (iOS 16 / macOS 13, every device we ship to) put
   it on the drawable; the bare 0.7× already reached 48 fps. Two costs to
   design for: star point sprites are sized in pixels and must be scaled
   by the inverse render scale or they shrink and soften; and
   `renderOffscreen` — the shadow-agreement oracle's eye — stays at native
   scale so no measurement moves.
2. **Grass at half the cost.** Ten milliseconds is more than the blades
   are worth at a sunrise. Fewer blades beyond ten metres, or blades that
   fade by screen size rather than by distance alone, keep the foreground
   turf and drop the part nobody sees.
3. **Shadow cascades: 1024² on iPhone, and refit only when the sun or the
   camera moved** — three or four milliseconds, cheap to take.
4. With all three the golden hour should sit at 60 fps on M-class iPads.
   120 Hz stays out of reach at native quality; frame interpolation
   (iOS 26, needs motion vectors we do not produce) is the only MetalFX
   feature that would give the 120 Hz *feel*, and it is an M-sized
   renderer feature of its own.
5. **Do not add the iPhone 120 Hz plist key.** Until a frame fits in 8 ms
   it would only halve battery life for nothing. When it does fit, it is
   one line.

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
