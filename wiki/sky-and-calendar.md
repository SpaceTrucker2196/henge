# The sky and the calendar

## The ephemeris stack — *Established*

Everything the app computes about the sky, and the published work it is
computed from. Each is pinned by fixtures a reader can check against the
printed page.

| Piece | Source |
|---|---|
| Solar position | Meeus, *Astronomical Algorithms* 2nd ed., ch. 25 (abridged VSOP87) |
| Obliquity | Laskar's polynomial, Meeus eq. 22.3 |
| ΔT (TT−UT) | Espenak & Meeus, NASA/TP-2006-214141 |
| Calendar ↔ Julian Day | Meeus ch. 7, astronomical years, Julian/Gregorian reform honoured |
| Moon | truncated ELP-2000 (position, distance, parallax); phases by elongation root-find |
| Planets | truncated VSOP87D (CDS VI/81), magnitudes from Astronomical Almanac formulae |
| Precession | series fitted to the modern era; the 2800 BC pole costs about half a degree and `StarFieldTests` says so out loud |
| Stars | Hipparcos ESA SP-1200 (CDS I/239), V ≤ 6.5, proper motion applied |
| Star names | IAU-CSN register (E. Mamajek), regenerated whole by `scripts/generate_star_names.py` |
| Refraction & rise | standard −0.833° sunrise definition throughout |
| Sky model | Preetham et al. 1999, closed form |
| Moon face | NASA SVS CGI Moon Kit (LRO), public domain |

## The wheel of the year — *Established arithmetic, Debated meaning*

- Eight stations solved from apparent solar longitude — the quarters
  (equinoxes, solstices) and cross-quarters (Imbolc, Beltane,
  Lughnasadh, Samhain) at exact 45° steps of the sun.
- The honest number the app shows rather than hides: the customary
  festival dates run **three to seven days** from the sun's own
  cross-quarter moments. Two calendars, two questions.
- That the *quarters* mattered at Stonehenge is Established (the axis is
  the plan); that the *cross-quarters* were observed there is tradition
  read backwards — the lore panel tiers it.

## The constellation figures — *our own drawings*

29 figures, 188 segments, authored in-repo against the vendored
catalogue (`scripts/generate_constellation_lines.py`). Membership is
ancient common knowledge (Ptolemy's *Almagest*); the stick figures are
ours, which is what keeps the layer licence-free. Thuban rides in Draco
because it held the pole for the builders — the deep-time sky's
load-bearing fact, pinned in `StarFieldTests`.

## The zodiac — *Established positions, labelled as constellations*

Twelve IAU constellation centroids (Delporte 1930 / Roman 1987, VizieR
VI/42), riding precession with their stars. Constellations, not signs:
the two have drifted a full sign apart since Babylon, and an app about
precession keeps the distinction.

## The lunar machinery — *Debated*

Hawkins 1963/1965 and Hoyle 1966 read the 56 Aubrey holes as an eclipse
computer. `research/lunar-markers.md` holds the audit; the app's
gold-marker mode enacts Hoyle's scheme, badged on screen every time,
scored honestly against the ephemeris.
