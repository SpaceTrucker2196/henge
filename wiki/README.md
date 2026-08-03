# henge — the knowledge base

Everything this app claims about the monument and the sky, with its
sources, in one place. The code carries the same citations at the point of
use (invariant 3) and `SECURITY.md` holds the machine-data provenance
registry; this wiki is the *reading* — assembled so a person can check what
we built against where it came from.

The site's front door is [the landing page](index.html); the Mac build
downloads from [river.io/henge](https://www.river.io/henge/).

Every claim carries a tier, the same register the app's lore system
enforces:

- **Established** — survey data, peer-reviewed work, or a published
  ephemeris; the app may state it plainly.
- **Debated** — real scholarship, contested or unreplicated; the app says
  who argues it.
- **Speculative** — one author's construction, an analogue, or our own
  artistic reading; the app must badge it on screen every time it shows.

## Pages

| Page | Holds |
|---|---|
| [The earthwork and the ground](earthwork-and-ground.md) | The enclosure ditch and bank, the turf, the reference imagery |
| [The stones and their journeys](stones-and-construction.md) | Sarsens, bluestones, the Altar Stone's Scottish provenance |
| [Geometry and alignments](geometry-and-alignments.md) | Surveyed dimensions, the axis, the station rectangle — and the speculative constructions, labelled as such |
| [The sky and the calendar](sky-and-calendar.md) | The ephemeris stack, the wheel of the year, the lunar hypotheses |
| [Data provenance](data-provenance.md) | Every vendored dataset, its licence and its file |

## In-repo research notes

Deeper working notes, each with its own audit trail:

- `research/lunar-markers.md` — Hawkins and Hoyle's Aubrey-hole machines
- `research/sarsen-geology.md` — sarsen petrology and weathering (parked,
  unapplied, per the owner)
- `research/stone-individuality.md` — how the per-stone meshes were read
