# henge — security

## Threat model

Henge holds nothing of the user's. There is no account, no document, no
location history — the site is a constant, and the only input is a date the
user chooses. The thing to protect is therefore the *absence* of a surface:
this app should still work, unchanged, on a phone in a field with the radios
off.

The claim about location is a design decision rather than an accident, and it
is worth recording here. The "Here" viewpoint, which puts the sky over the
user's own meridian, derives its longitude from the device's *time zone*: the
standard offset at 15° per hour, with daylight saving removed first. It does
not use CoreLocation. Nothing in the app imports that framework, no
`NSLocation*` usage string exists in either target, and no location permission
is ever requested. The cost is real and is stated at `SkyModel.deviceSite`: a
time zone can be 7.5° wide, which is half an hour of solar time. The trade was
taken deliberately, because a monument that works in a field with no signal
should not need permission to tell you where the sun is.

The house rule across river.io software applies: data stays on the device that
made it.

## Outbound surface (frozen)

Every network destination, credential, and external process this repo touches.
Adding to this list is a stops-and-asks (`factory/dark-factory.md` §4).

- **The app itself: none.** `Package.swift` declares no remote dependencies.
  There is no `URLSession`, no socket, no App Transport Security configuration,
  no credentials, and no external processes. A cold clone builds offline and the
  almanac works with the radios off.
- **StoreKit, and only StoreKit.** Added with the paywall on 2026-08-04, and
  the reason this section no longer reads a flat "none". Buying or restoring the
  non-consumable `io.river.henge.full` goes through Apple's framework to Apple's
  servers. The app never sees a payment detail, there is no river.io server for
  anything to reach, and nothing about the user or the dates they choose leaves
  the device. The session clock and the entitlement are evaluated locally
  (`HengeStore/TrialClock.swift`, `HengeStore/Entitlement.swift`); purchase
  state arrives through `Transaction.updates` and nowhere else. The store
  listing's "no network" claim stands on this distinction: the app does not
  phone home, and the one outbound path is Apple's purchase pipe.

## Data provenance

Astronomical data is vendored, not fetched. Each row records what it is, where
it came from, and under what terms — because MISSION.md invariant 5 makes
adding a data set a deliberate act rather than a convenience.

Every row below was re-checked against the shipping source on 2026-09-07,
the day after 0.2.0 went on sale.

| Data | Source | Licence | Status |
|---|---|---|---|
| Solar theory | Meeus, *Astronomical Algorithms* 2nd ed., ch. 25 (abridged series) | Algorithms, implemented from the published method and cited | **In use** (M1) |
| Obliquity | Laskar's polynomial, Meeus eq. 22.3 | As above | **In use** (M1) |
| ΔT | Espenak & Meeus, NASA/TP–2006–214141 | US government work | **In use** (M1) |
| Sky model | Preetham et al. (1999), closed form | Published formula, no data tables to vendor | **In use** (M1) |
| **Surface textures** | **ambientCG** `Rock030` and `Grass004`, 1K JPG sets (colour, normal, roughness) | **CC0 1.0 Universal** — public domain dedication, no attribution required. Credited anyway | **In use** — `Sources/HengeEngine/Resources/{rock,grass}-{albedo,normal,roughness}.jpg`, 1.7 MB total, colour and normal downsampled to 1024/512 |
| **Terrain** | **Environment Agency LIDAR Composite DTM 2022, 1 m** (bare earth), fetched from Defra's WCS as a float32 GeoTIFF already scaled to 40 m by `scripts/bake_terrain.py --fetch-lidar` | **Open Government Licence v3** — attribution required and given in the info view: "© Environment Agency copyright and/or database right 2022. All rights reserved." The request URL is in the script, so the result is reproducible | **In use** — `Sources/HengeGeometry/Resources/salisbury-plain.heightfield`, 1.18 MB, 768x768 at 40 m (±15.3 km). Replaced the SRTM 1-arc-second bake (NASA/USGS, public domain, tiles N51W002/N51W003, still the script's fallback for voids) on 2026-09-15: SRTM is a radar *surface* model and stood the north-east skyline at 0.71° where bare earth is 0.60° |
| Skyline check | **David Hoyle**'s Stellarium landscape `stonehenge_su1224742194`, a calibrated 360° panorama from inside the circle (51.178851 −1.826177), sent by **Simon Banton** | Courtesy of the authors; the panorama is **not vendored** | **Reference** — the cross-check on the terrain, not a source. Its skyline, read off the alpha channel at 1° steps, matches the LiDAR march all the way round (r = 0.96, mean difference 0.03°) and reads 0.57–0.60° across 48–50°. Against the SRTM bake it differed by 0.26° on average |
| Star catalogue | **Hipparcos (ESA)** — ESA, 1997, *The Hipparcos and Tycho Catalogues*, ESA SP-1200, via CDS I/239 `hip_main.dat` | Free with attribution, no share-alike — attribution here and in `StarCatalog.swift` | **In use** — `Sources/HengeGeometry/Resources/hipparcos-bright.csv`, the 8,870 stars with V ≤ 6.5 (HIP, ICRS J1991.25 position, V, B−V, proper motions), 443 KB |
| Moon colour map | **NASA SVS CGI Moon Kit** (`lroc_color_poles_1k`), from Lunar Reconnaissance Orbiter LROC data, NASA Goddard Scientific Visualization Studio | Public domain (US government work); credit appreciated and given here | **In use** — `Sources/HengeEngine/Resources/moon-albedo.jpg`, 1024×512 equirectangular, 139 KB |
| Planetary theory | **VSOP87D** — Bretagnon & Francou, "Planetary theories in rectangular and spherical variables", A&A 202, 309 (1988); machine-readable tables from CDS VI/81 | Freely redistributed by CDS; cited here and in the generated source | **In use** — `Sources/HengeAstro/VSOP87Tables.swift`, truncated to terms worth ≥ 0.2″ over ±5 millennia (2,774 terms, Earth + the naked-eye five) |
| Star names | **IAU-CSN** — the IAU Working Group on Star Names' Catalog of Star Names, maintained by E. Mamajek | Official IAU nomenclature, freely published; cited here and in `StarCatalog.swift` | **In use** — the 338 register names matching the bundled catalogue, generated into `StarCatalog.properNames` by `scripts/generate_star_names.py` |
| Constellation figures | **Authored in-repo** — which pairs of stars to join was drawn by hand for this app (`scripts/generate_constellation_lines.py`); constellation membership itself is ancient common knowledge (Ptolemy's *Almagest*) and star positions come from the Hipparcos row above | No external stick-figure dataset consulted — that authorship is what keeps the layer licence-free where the published figure sets (Stellarium sky cultures, H. A. Rey) were not | **In use** — 29 figures, 188 segments, `Sources/HengeGeometry/ConstellationLines.swift` |
| Lunar theory | **Meeus, *Astronomical Algorithms* 2nd ed., ch. 47**, a truncation of ELP-2000/82, keeping the larger periodic terms rather than the full series | Algorithms, implemented from the published method and cited. No series vendored | **In use** (M3) — `Sources/HengeAstro/Moon.swift`; checked against Meeus's own worked example to 0.01° in longitude and latitude and 60 km in distance |
| **Milky Way** | **NASA SVS Deep Star Maps 2020** (entry 4851, Ernie Wright), the Milky Way layer in ICRF/J2000 plate carrée, rendered from **Gaia DR2** | US government work, public domain; the SVS page asks credit for "NASA/Goddard Space Flight Center Scientific Visualization Studio" and "Gaia DR2: ESA/Gaia/DPAC", both given in the info view | **In use** — `Sources/HengeEngine/Resources/milkyway-2020.jpg`, 2048×1024: `sips -s format png` from the 4k EXR, then `sips -z 1024 2048 -s format jpeg -s formatOptions 85` (the one-step EXR→JPEG in sips writes black), no levels touched; the brightness is a shader constant (`HengeRenderer.milkyWayRadiance`) |
| **Stone plan** | **Tim Daw, *stonehenge-block-3d*, `data/locked_poses.json`** (commit `52e81ba`), 93 stones digitised from the M J Rees & Co 1989/90 survey of the monument, Historic England Archive sheet MP/STO0861, each graded by Daw's own `accuracy_class` | **CC BY-SA 4.0** — attribution given in the info view and in `Sources/HengeGeometry/Resources/stones/LICENSE-DATA.md`; share-alike honoured by publishing the derived CSV under the same licence (that file alone, not the app). Decision record: `docs/decisions/2026-09-23-stone-data-licences.md` | **In use** — `Sources/HengeGeometry/Resources/stones/daw-locked-poses.csv`, written by `scripts/import_daw_poses.py` from the pinned commit. Positions and yaw only for standing stones; footprints only for what lies. `seed_only` and `plan_digitised` rows ship as *provisional*. Daw's file does not cite Rees or Historic England; this repo does |

The terrain is the first data this repo vendors, and it went in under the rule
in MISSION.md invariant 5: provenance settled first. The Environment Agency
LiDAR is Open Government Licence, which obliges the attribution statement the
info view carries verbatim; the SRTM it replaced was public domain with no
obligation at all and was credited anyway, because a claim about where the sun
rises should say what it was measured against.

The surface textures were added at the owner's explicit request, which is what
resolves the stops-and-asks; CC0 is what makes it clean. Two notes on how they
are used, because both bear on invariant 8.

**They supply detail, not colour.** Each map is divided by its own mean and
multiplied by the material's albedo, so `SurfaceMaterial` stays in charge of
what colour a stone is. Sarsen and bluestone are different rocks and the app
distinguishes them; a single photographic albedo would flatten the two into one.

**They are not photographs of Stonehenge.** `Rock030` is a generic weathered
rock. It stands in for grain and pitting, and the app does not claim otherwise.
The request was for granite — worth recording that the monument has none: the
uprights are sarsen, a silcrete, and the smaller stones are Preseli dolerite and
rhyolite. Granite is speckled feldspar and mica and would read as the wrong
stone to anyone who has stood there, so a weathered grey rock was chosen over a
literal granite scan.

### Reference sources consulted, and deliberately not vendored

Existing Stonehenge models were reviewed before extending the geometry. None
were incorporated; what was taken is knowledge, not data.

- **English Heritage / Greenhatch Group laser survey (2011)** — the definitive
  record, 1 mm across the circle and 0.5 mm on four faces of interest, covering
  every visible face including the lintel tops. Not openly licensed for
  redistribution, so it is a thing to read about rather than to ship. If
  per-stone geometry ever matters more than the surveyed dimensions already in
  `Monument`, this is the source to license.
- **Petrie's numbering (1874–77)** — adopted. Not data, a convention, and the
  one the literature has used for 150 years.
- **Sketchfab LiDAR landscapes** — several are CC-BY over Environment Agency
  open LiDAR. Nothing to gain: this repo bakes the same Environment Agency
  LiDAR itself, straight from Defra's service, under the original OGL rather
  than a re-publisher's CC-BY, and reproducibly from `scripts/bake_terrain.py`.
- **Sketchfab monument models** — mixed licences, mostly artistic
  reconstructions rather than survey. Incorporating one would put a licence and
  an unverifiable provenance at the centre of a project whose first invariant is
  that its geometry traces to cited survey data.

### Notes on the open questions

- **Yale BSC5 was considered and rejected.** The brief named it, but its terms
  for commercial redistribution are not clearly permissive and river.io sells
  its software. Hipparcos gives the same ~9,000 stars brighter than magnitude
  6.5 with terms that are unambiguous.
- **Stellarium's constellation lines are GPL** and therefore incompatible with
  a closed application, and H. A. Rey's figures are in copyright. The feature
  was dropped for that reason on 2026-07-27, then recovered three days later by
  a third route: the figures were authored in this repo rather than licensed
  from anyone. 29 figures, 188 segments, drawn by hand against the bundled
  catalogue. Membership is Ptolemy's, the positions are Hipparcos's, the drawing
  is ours. That authorship is the whole reason the layer ships at all. See the
  constellation figures row above.
- **Pole stars** are seven published J2000 positions cited as constants, not a
  catalogue. Nothing to license.
- **The north-east skyline was in dispute, and the dispute is settled by
  data.** The original SRTM bake gave 0.71° at the solstice bearing. A
  calibrated photographic panorama from the circle (skyline check row above)
  reads 0.57–0.60° there, and the Environment Agency's bare-earth LiDAR gives
  0.60°: the photograph and the LiDAR agree all the way round the horizon to
  0.03° on average, and SRTM sits a quarter of a degree above both, which is
  tree canopy on the Larkhill ridge read as ground by radar. The LiDAR is now
  the source and the photograph the cross-check. Nothing here touched the sky
  or the shadows — it moved the rise and set bearings the almanac prints by a
  quarter of a degree, in the same direction as the refraction correction of
  issue #2, which is how the two errors had been hiding each other.
- **Meeus's printed tables are not transcribed wholesale.** Algorithms are
  implemented from the published method and cited; where a long series is
  needed, it comes from the original IMCCE machine-readable data.
