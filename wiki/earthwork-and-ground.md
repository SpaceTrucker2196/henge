# The earthwork and the ground

## The enclosure ditch and bank — *Established*

Source: Cleal, Walker & Montague, *Stonehenge in its Landscape:
Twentieth-century excavations* (English Heritage Archaeological Report 10,
1995) — the definitive excavation synthesis.

- The earliest monument (c. 2900 BC) is the circular earthwork enclosure:
  a ditch with an **internal** bank and a low external counterscarp bank.
  The main bank *inside* the ditch is the reverse of the classic henge
  arrangement — by the strict typology, Stonehenge is not a henge.
- Circuit roughly **110 m across**; ditch about **5–6 m wide**, dug
  **1.4–2.1 m** into the chalk in irregular segments (it reads as a chain
  of conjoined pits); the fresh bank stood perhaps **2 m** of bright
  chalk rubble, about 6 m wide.
- Today both survive as gentle grassed swellings of roughly **half a
  metre** — silt in the ditch, slump on the bank.
- Two causeways break the circuit: the main **north-east entrance** on
  the monument's axis, where the Avenue meets the enclosure, and a
  smaller **southern** gap.
- Antler picks from the ditch bottom furnished the radiocarbon dates;
  the diggers backfilled placed deposits (cattle bone already old when
  buried) — the enclosure was never merely a quarry for the bank.

In the app: `HengeGeometry/Earthwork.swift` models the circuit as an
analytic profile (state-aware: as-dug against today's swell), tested in
`EarthworkTests` — causeway level on the axis, bank inside ditch, as-dug
dwarfing as-stands.

## The ground surface — *Established observation, Speculative palette*

Reference imagery: aerial photograph of the monument from the north-west
(supplied by the owner, 2026-07-31, from Nature's news coverage of the
Altar Stone work). What it shows, and what the renderer takes from it:

- Chalk downland is **not one green**: a patchwork metres across — thin
  worn turf reading pale where the chalk comes through, ranker growth,
  wear scars. The renderer's two-band mottle is calibrated to this.
- The earthwork ring reads **paler than the field** — thin sward over
  chalky bank material. The wear channel on the ring carries this.
- The enclosure interior reads differently from the surrounding pasture
  (mown versus grazed in the photograph — a modern management artefact,
  not reconstructed).
- Every colour triple in the renderer is an artistic reading —
  *Speculative* by construction; no source publishes reflectance spectra
  for this turf.

## The wider landscape — *Established*

- Terrain: NASA/USGS SRTM 1-arc-second heightfield, baked to a 768×768
  grid at 40 m spacing (±15.3 km) by `scripts/bake_terrain.py` — the
  skyline the sun actually rises over.
- Barrows and field boundaries visible in the reference photograph are
  not yet modelled.
