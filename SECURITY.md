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
| **Terrain** | **SRTM 1-arc-second (NASA/USGS)**, fetched as Skadi `.hgt` tiles N51W002 and N51W003 | **Public domain** (US government work). Baked by `scripts/bake_terrain.py`; the bake script and the tile names are in-tree so the result is reproducible | **In use** — `Sources/HengeGeometry/Resources/salisbury-plain.heightfield`, 1.18 MB, 768x768 at 40 m (±15.3 km) |
| Star catalogue | **Hipparcos / Tycho-2 (ESA)** | Free with attribution, no share-alike | **Decided, not yet vendored** (M3) |
| Constellation figures | undecided | — | **OPEN — blocks M3** |
| Lunar theory | ELP2000 truncation, from the IMCCE-published series | To be confirmed before vendoring | Pending (M3) |
| Milky Way texture | undecided | — | Pending (M3) |

The terrain is the first data this repo vendors, and it went in under the rule
in MISSION.md invariant 5: provenance settled first. SRTM is a US government
work and therefore public domain, with no attribution obligation — though the
app will credit it anyway, because a claim about where the sun rises should say
what it was measured against.

### Notes on the open questions

- **Yale BSC5 was considered and rejected.** The brief named it, but its terms
  for commercial redistribution are not clearly permissive and river.io sells
  its software. Hipparcos gives the same ~9,000 stars brighter than magnitude
  6.5 with terms that are unambiguous.
- **Stellarium's constellation lines are GPL** and therefore incompatible with a
  closed application. Either draw a line set from the public IAU boundaries or
  license one. This is the last thing standing between M3 and a night sky.
- **Meeus's printed tables are not transcribed wholesale.** Algorithms are
  implemented from the published method and cited; where a long series is
  needed, it comes from the original IMCCE machine-readable data.
