# henge — mission

## What this is

**Henge** is a photoreal, real-time 3D simulation of Stonehenge that is also a
working calendar. The monument is the instrument: sun, moon and stars move
across a physically modelled sky for any date the user chooses, and the shadows
the stones cast are astronomically accurate. Stand at the Altar Stone on the
summer solstice and the sun breaks the horizon beside the Heel Stone exactly as
it does on Salisbury Plain.

It is **druidic in spirit and ceremony, archaeological in fact**. The voice, the
art direction and the eightfold festival wheel come from living druidry; the
claims about who raised the stones and why are stated straight, with their
uncertainty attached.

Native iOS and macOS, one engine, hand-rolled Metal 3. No game engine.

## Sacred invariants (do not cross)

An agent that finds itself about to violate one of these stops and asks. They
hold even when crossing them would help.

1. **Astronomy is computed, never faked.** Every celestial position comes from
   `HengeAstro`. No hardcoded azimuths, no hand-tuned curves, no "close enough"
   fudge to make an alignment look better than it is. The solstice bearing is
   epoch-dependent and must be derived; the fact that it does not perfectly fit
   the built axis is a finding, not a bug to paper over.

   *Accuracy, as measured by the suite rather than asserted here:* solar
   apparent longitude within 0.001° and right ascension and declination within
   0.002° of Meeus's published examples; obliquity within 0.0001° via Laskar,
   which is what keeps 2500 BC honest. Loosening any of these tolerances is a
   stops-and-asks.

2. **The shadows are the calendar, and they are verifiable.** Rendered shadows
   must agree with `HengeGeometry`'s analytic solution to a stated, measured
   tolerance — currently **0.28 m on the ground**, set by the shadow map's texel
   and the filter tap, not by preference. Visual plausibility is never a
   substitute for agreement. If a rendering change moves that number, the number
   gets re-measured and re-justified; it does not get relaxed.

3. **Archaeological honesty is enforced by the type system.** Every lore
   assertion is data carrying a tier — **Established**, **Debated**, or **Modern
   tradition** — and at least one citation. A test asserts that none ships
   untiered or uncited (arrives with the lore panels in M5).

   Druidry is presented as living inheritance, never as the builders' religion.
   The stones are c. 3000–1500 BC; the Iron Age druids arrive some two millennia
   later; the association begins with Aubrey and Stukeley in the 17th and 18th
   centuries. The app says so plainly.

4. **Raw Metal, no engine.** The main scene is hand-rolled Metal 3. No SceneKit,
   no RealityKit, no third-party renderer. That constraint is the demonstration.

5. **No third-party runtime dependencies.** `Package.swift` has none and a cold
   clone builds offline. Vendored data carries its provenance and licence in
   `SECURITY.md`. Adding either a dependency or a data set is a stops-and-asks.

6. **On-device and silent.** No network, no telemetry, no analytics, no account.
   The almanac works in a field with no signal.

7. **Accessible by construction.** Every stone and control carries a VoiceOver
   label; Dynamic Type throughout the chrome; reduced-motion alternatives for
   the time-lapse and camera moves.

8. **The monument is modelled from the archaeology.** Dimensions trace to cited
   survey data. "As it was" and "as it stands" are distinct, labelled states,
   never blended. Hypothetical restorations — the Heel Stone's lost companion,
   the Slaughter Stone's portal pair — are toggles badged as hypothesis.

## Non-goals

Scope creep dies here, and an agent needs to know what *not* to propose.

- **Not a game.** No scoring, quests, inventory, or fantasy creatures.
- **Not a general planetarium.** The sky serves the monument, not the reverse.
- **No AR or VR** in v1.
- **No multiplayer, sharing, or backend.** There is no server to add to.
- **No neo-pagan claim dressed as archaeology**, and no ancient-astronaut
  material at any tier.
- **No modern intrusions** in the landscape: no road, fence, car park or visitor
  centre. The plain is pre-modern.
- **No stellar proper motion.** Footnoted as a known simplification.
- **Monetisation is undecided** and is a separate conversation.

## Where it is now

**M1 "The Light" has landed** (2026-07-27). Sun position, physical sky,
cascaded shadow maps, one procedural trilithon and the Heel Stone on the true
axis, a time scrubber running to 100,000×, and the shadow-agreement test that
makes every later milestone trustworthy. 46 tests green; both platforms build
warning-clean.

What the engine already establishes, computed rather than assumed:

| | 2500 BC | 2026 |
|---|---:|---:|
| Midsummer sunrise bearing (flat horizon) | 47.71° | 48.77° |
| Midsummer sunrise (0.6° skyline) | 49.08° | 50.11° |
| Midwinter sunset (0.6° skyline) | 230.10° | 231.12° |

Against a built axis of 49.9°, **midwinter sunset is the tighter fit** — 0.2°
off the reciprocal, where midsummer sunrise misses by 0.8°. That is a real
result out of the ephemeris, and it is the sort of thing the lore panels exist
to explain rather than smooth over.

## Direction

`ROADMAP.md` carries the milestones. The gravity points at M2 "The Stones" —
the full monument in both states — then M3 "The Night", which is where the
star-catalogue licensing question in `SECURITY.md` must be settled before any
data is vendored.
