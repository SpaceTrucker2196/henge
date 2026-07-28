# henge — security

## Threat model

Henge holds nothing of the user's. There is no account, no document, no
location history — the site is a constant, and the only input is a date the
user chooses. The thing to protect is therefore the *absence* of a surface:
this app should still work, unchanged, on a phone in a field with the radios
off.

The house rule across river.io software applies: data stays on the device that
made it.

## Outbound surface (frozen)

Every network destination, credential, and external process this repo touches.
Adding to this list is a stops-and-asks (`factory/dark-factory.md` §4).

- **none.** `Package.swift` declares no remote dependencies; the app makes no
  network calls; there are no credentials, no entitlements beyond the default,
  and no external processes. A cold clone builds offline.

## Data provenance

Astronomical data is vendored, not fetched. Each row records what it is, where
it came from, and under what terms — because MISSION.md invariant 5 makes
adding a data set a deliberate act rather than a convenience.

| Data | Source | Licence | Status |
|---|---|---|---|
| Solar theory | Meeus, *Astronomical Algorithms* 2nd ed., ch. 25 (abridged series) | Algorithms, implemented from the published method and cited | **In use** (M1) |
| Obliquity | Laskar's polynomial, Meeus eq. 22.3 | As above | **In use** (M1) |
| ΔT | Espenak & Meeus, NASA/TP–2006–214141 | US government work | **In use** (M1) |
| Sky model | Preetham et al. (1999), closed form | Published formula, no data tables to vendor | **In use** (M1) |
| **Surface textures** | **ambientCG** `Rock030` and `Grass004`, 1K JPG sets (colour, normal, roughness) | **CC0 1.0 Universal** — public domain dedication, no attribution required. Credited anyway | **In use** — `Sources/HengeEngine/Resources/{rock,grass}-{albedo,normal,roughness}.jpg`, 1.7 MB total, colour and normal downsampled to 1024/512 |
| **Terrain** | **SRTM 1-arc-second (NASA/USGS)**, fetched as Skadi `.hgt` tiles N51W002 and N51W003 | **Public domain** (US government work). Baked by `scripts/bake_terrain.py`; the bake script and the tile names are in-tree so the result is reproducible | **In use** — `Sources/HengeGeometry/Resources/salisbury-plain.heightfield`, 1.18 MB, 768x768 at 40 m (±15.3 km) |
| Star catalogue | **Hipparcos / Tycho-2 (ESA)** | Free with attribution, no share-alike | **Decided, not yet vendored** (M3) |
| Constellation figures | — | — | **Dropped from scope** (owner, 2026-07-27). Stars will be drawn as a field without lines, which removes the only GPL entanglement in the project |
| Lunar theory | ELP2000 truncation, from the IMCCE-published series | To be confirmed before vendoring | Pending (M3) |
| Milky Way texture | undecided | — | Pending (M3) |

The terrain is the first data this repo vendors, and it went in under the rule
in MISSION.md invariant 5: provenance settled first. SRTM is a US government
work and therefore public domain, with no attribution obligation — though the
app will credit it anyway, because a claim about where the sun rises should say
what it was measured against.

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
  open LiDAR. Nothing to gain: this repo already bakes the terrain from SRTM
  itself, which is public domain and reproducible from `scripts/bake_terrain.py`.
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
  a closed application. Rather than draw a set or license one, constellation
  figures were dropped from scope. The sky gets stars without lines, which is
  arguably truer to what the builders saw anyway — the figures are a much later
  overlay on the same points of light.
- **Pole stars** are seven published J2000 positions cited as constants, not a
  catalogue. Nothing to license.
- **Meeus's printed tables are not transcribed wholesale.** Algorithms are
  implemented from the published method and cited; where a long series is
  needed, it comes from the original IMCCE machine-readable data.
