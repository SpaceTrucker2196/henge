# Sarsen geology, weathering and dressing — research notes

Produced by a multi-agent research pass with an independent citation audit,
28 July 2026. **This note replaces the geology strand that was lost to prompt
injection**; `research/stone-individuality.md` says that strand is "still
unusable" and that the mesh displacement ranges are "an artistic reading of
generic weathered rock, deliberately not a claim about sarsen specifically".
That sentence is what this note exists to retire.

Nothing here is implemented yet.

Tiers follow MISSION invariant 3. **Attested** = stated in a primary or
peer-reviewed source, quoted or verified verbatim by the auditor. **Debated** =
real source, but tertiary, unrefereed, unattributed, or contested between
sources. **Speculative** = derivation, analogue from another rock type, or
renderer interpretation. Every number below carries a tier; every colour
triple is Speculative by construction, because no source publishes reflectance
spectra for either the stone or its lichens.

**Injection status.** No counterfeit system-status blocks, deprecation
notices, or instruction-like text appeared in any fetched page in this pass.
The auditor independently re-fetched the primary PDFs and confirmed the same.
The only imperative text encountered was the search tool's own boilerplate.
Publisher 403s (ScienceDirect, ResearchGate, Taylor & Francis) are ordinary
bot defences — but they are the direct cause of the two citation errors the
audit caught, because they force reliance on search snippets where author
names cross-wire.

## Audit corrections folded in

Six claims from the raw strands are corrected or downgraded here, and are
flagged again at their point of use:

1. "Ullyott & Nash, *The sarsen stones of Stonehenge*, PGA 127(3), 2016" — the
   paper is real at that exact volume and pagination but is by **Mike Parker
   Pearson**. Confirmed against Nash et al. 2020's own reference list. The
   boulder dimensions attributed to it were never read from the paper, so they
   are dropped; Worsley 2019 and Clark et al. 1967 supply the same numbers
   from text the auditor read.
2. "Twidale & Bourne, gnammas of northwestern Eyre Peninsula, 2016" — that
   article is by **Timms & Rankin**. The pit/pan depth:diameter ratios were
   re-verified against the paper's own abstract text. Still **Debated** for
   our purposes: granite, not silcrete.
3. Bradwell & Armstrong 2007 — the strand had the sign inverted. North Wales
   *Rhizocarpon* growth is **66% faster** than southern Iceland, not slower
   ("being 66% greater at the maximum in north Wales than southern Iceland").
   So a temperate-maritime rate near 1.0 mm/yr diametral, not 0.4. The
   downstream conclusion (crustose patterns are static on human timescales)
   survives, but the number does not.
4. Axe-head carvings are on **Stones 3, 4, 5 and 53**. Stone 23 carries a
   *dagger*, not axes; the strand's list wrongly included it.
5. Heel Stone metrology (4.7 m, 7.6 m girth, ~35 t, 27° lean) and the Sarsen
   Circle averages (~30 m diameter, ~4.1 m above ground, ~3.2 m lintels,
   ~25 t) are **Debated**, not Attested: Wikipedia / English Heritage web /
   Britannica with no in-text citation, and Cleal, Walker & Montague 1995 was
   never consulted. That the Heel Stone is *unworked* is Attested (RR 32-2012).
6. **Polygonal surface cracking on sarsen is dropped entirely.** It is
   documented for other case-hardened sandstones and never for sarsen. So is
   the orange *Xanthoria*/*Caloplaca* bird-perch community — see Lichen.

## The material

Sarsen is a **groundwater silcrete**: Palaeogene quartz sand cemented under
phreatic conditions at or near an ancient water table by syntaxial quartz
overgrowths, then left as isolated durable boulders on the Chalk when the
uncemented sand around it eroded away (Ullyott & Nash 2006; Ullyott et al.
2004). **Attested.**

It is, for rendering purposes, a monomineralic quartz rock — quartz grains in
quartz cement:

- PXRF of all 52 surviving sarsens (260 analyses, 34 elements): the stones
  "typically comprise >99% silica". The Stone 58 core is SiO₂ ≥ 99.7 wt%,
  with 0.05–0.06 wt% Al₂O₃, 0.09–0.12 wt% Fe₂O₃, **0.01 wt% CaO** and
  0.06 wt% TiO₂ — a quartz arenite (Nash et al. 2020). **Attested.**
- Petrography of the same core: highly indurated, grain-supported,
  structureless; very well sorted, mean detrital grain diameter **187 μm**,
  predominantly 0.125–0.250 mm; cement in up to ~16 optically continuous
  overgrowth zones; **7.2–9.2 area % porosity** as a moderately connected
  intergranular network; quartz 99.57–99.68 area %, the remainder Fe
  oxides/hydroxides, kaolinite, chlorite, Ti-oxides, tourmaline, zircon,
  kyanite, staurolite, chromite (Nash et al. 2021). **Attested.**
- **The 0.01 wt% CaO matters to us specifically.** The shader comment at
  `Henge.metal:783` says the solution hollows form because rain "dissolves the
  silcrete's carbonate cement". There is essentially no carbonate cement to
  dissolve. The cement is quartz; hollows form by granular disintegration,
  removal of less-cemented patches, and loss of inclusions — not carbonate
  dissolution. This comment is wrong and should be replaced.

Colour of *fresh* stone: white (Munsell 10YR 8/1) to grey (10YR 6/1), with the
top 22 cm of core very pale brown (10YR 7/4 to 8/2) from iron-hydroxide
staining (Nash et al. 2021). **Attested — with the caveat the strand missed:
these are *wet* Munsell readings**, taken after moistening against the chart.
Dry stone is paler still. Converting Munsell value to luminance factor by
ASTM D1535 gives V=8 → Y ≈ 59%, V=7 → 43%, V=6 → 30% — that conversion is
**Speculative** (our arithmetic, not in the paper).

Mass and scale, all **Attested** from Nash et al. 2020 unless noted:

- Typical uprights: long axis **6.0–7.0 m** including buried sections, ~20 t.
- Largest: Stone 56 at **9.1 m**; Stone 54 above-ground ~30 t.
- Great Trilithon replica (Richards & Whitby 1997): uprights ~40 t each,
  lintel ~10 t, and the replica concrete density of **2380 kg/m³** was "very
  similar to that of sarsen". This is the single most usable published density
  figure we have.
- Natural field boulders rarely exceed 4.0–5.0 m long axis; parent silcrete
  lenses must locally have exceeded 1.5 m thickness. So the Stonehenge
  megaliths are at the extreme tail of the natural size distribution.
- Marlborough Downs source stones: 77% of Fyfield Down sarsens are 0.3–1.5 m
  (Clark et al. 1967 via Worsley 2019); 8,000–10,000 stones under 4–5 m long
  axis in a 750 × 60 m strip of Clatford Bottom (Small et al. 1970 via
  Worsley 2019). Generally tabular with rounded edges.

Derived bulk density: quartz 2.65 g/cm³ less 7.2–9.2% porosity gives
**2.41–2.46 g/cm³**. **Speculative** (our arithmetic) but it brackets the
independently published 2.38 t/m³ that Richards & Whitby matched, so
**2.4 t/m³ is the working figure**. Hardness is inferred as Mohs ~7 from the
mineralogy; no published Mohs or UCS value for Stonehenge sarsen was found.
**Speculative.**

Fracture behaviour (Harding 2025, all **Attested**): sub-conchoidal, with
diffuse bulbs of percussion, cones predominantly absent and indistinct
conchoidal rings, all attributable to the coarse grain — fresh breaks read as
slightly granular curved surfaces, not glassy flint shells. The rock's
homogeneity lets it split in straight lines in most directions, so ancient
split faces are surprisingly planar. Heat is not a shortcut: sarsen reacts
badly to it and becomes sugary and unresponsive, unlike silicates that improve
up to 400 °C.

Provenance, **Attested** (Nash et al. 2020): 50 of the 52 sarsens share one
chemistry and match **West Woods**, a ~6 km² plateau rising to 220 m asl in
the south-east Marlborough Downs, ~25 km north. Upright 26 and lintel 160 are
chemically distinct; the paper's LDA also flags **lintel 156 as a borderline
third outlier** while BPCA places it inside the cluster — the strand's "two
outliers" is really two firm plus one equivocal. The **Heel Stone (96) matches
the majority** and was not a local natural boulder.

## The weathering features, with scales

Five superimposed populations, each with its own scale band and spatial logic.
"Where" is stated in the terms the shader can actually test: upward-facing,
vertical, dressed, undressed, below/above head height.

| Feature | Typical size range | Where on the stone | Tier | Source |
|---|---|---|---|---|
| Coarse longitudinal ridges | 20–30 cm wide, 5–7.5 cm deep, running vertically | Exterior faces of Sarsen Horseshoe uprights only (52, 54, 58, 59; relic rib on 53) | Attested | Abbott & Anderson-Whymark 2012 |
| Transverse tooling bands within those ridges | ~10 cm wide, ~1 cm deep | Same faces, crossing the ridges | Attested | Abbott & Anderson-Whymark 2012 |
| Fine transverse tooling grooves | 5–10 cm wide × 20–30 cm long × 5–20 mm deep | All trilithon uprights; in the Circle only one rebate (Lintel 122) | Attested | Abbott & Anderson-Whymark 2012 |
| Fine longitudinal tooling grooves | 5–7.5 cm wide × 20–30 cm long × 5–15 mm deep | Sides of Trilithons 1 and 5 (51, 52, 59, 60); sides of 17 Circle uprights; Lintel 102; one side of the Slaughter Stone | Attested | Abbott & Anderson-Whymark 2012 |
| Fine pick dressing (pockmarks) | Sub-centimetre dimples; hammerstone < 1 kg | Final visible finish on virtually every dressed face | Attested | Abbott & Anderson-Whymark 2012 |
| Ground / polished patches | < 0.30 m across, plus the lower ~2 m of two faces | Interior NW faces of Stones 53 and 10; small patches on 52 (base) and 16 (NW side) | Attested | Abbott & Anderson-Whymark 2012 |
| Construction flake scars | Generally < 0.30 m; over 1 m at the base of Stone 30; large sub-conchoidal scar on Stone 3 exterior | Squared sides and bases | Attested | Abbott & Anderson-Whymark 2012 |
| Visitor / robbing flake damage | 55 recorded areas on 34 stones (~40%) | Concentrated on edges, especially of fallen stones | Attested | Abbott & Anderson-Whymark 2012 |
| Axe-head carvings | ~decimetre; an over-sized example 36 × 28 cm; ~0.5 mm deep | Lower ~2 m only, blade edges up, on Stones 3, 4, 5, 53 (a dagger on 23) | Attested | Abbott & Anderson-Whymark 2012; depth from Leong & Brolly |
| Natural cup-like hollows and pebble casts | cm to ~15 cm (Stone 51 has a c.0.15 m hole at waist height) | Any face, no gravity control; no tooling inside any of them | Attested | Abbott & Anderson-Whymark 2012 |
| Fossil root hollows | mm to a few cm, tapering, knobbly-walled | Any orientation, vertical and horizontal, inherited from the parent sand | Attested | Worsley 2019 (Carruthers 1886) |
| Invertebrate burrow tubes | 1–15 mm, commonly 3–7 mm, uniform diameter | Any orientation; undressed surfaces | Debated | General ichnology (Skolithos), not measured on sarsen |
| Pan-type solution basins | decimetre diameter, depth:diameter < 0.1 → cm-scale depth | Flat/horizontal surfaces only: lintel tops, seats of Stones 5 and 6, upward faces of fallen stones | Debated | Timms & Rankin 2016 (granite analogue); locations from Abbott & Anderson-Whymark 2012 |
| Pit-type basins | depth:diameter > 0.2 | Anywhere on an outcrop | Debated | Timms & Rankin 2016 (granite analogue) |
| Chemically eroded water channels | No sarsen-specific widths published; limestone runnels 2–10 cm wide, 6–15 cm deep, 1–3 m long as an *upper envelope* | Gravity-following, on dressed faces (documented on Lintel 152) | Debated | Existence and location Attested (Abbott & Anderson-Whymark 2012); dimensions are limestone karren, and silcrete karren are more subdued |
| Fruticose lichen clumps | ~40 mm diameter domes, low-single-digit mm proud | Above head height only | Attested | Abbott & Anderson-Whymark 2012 |
| Crustose lichen film | Thickness variation < 0.2 mm | Ground level upwards, discontinuous | Attested | Abbott & Anderson-Whymark 2012; Leong & Brolly |
| Net subaerial erosion since construction | Millimetres, not centimetres | Vertical above-ground dressed faces | Attested (as an implication) | Abbott & Anderson-Whymark 2012 |

That last row is the most valuable constraint in the whole note and it is easy
to miss. Gowland, Stone and Atkinson all overstated weathering loss; the laser
scan found that "on virtually all surfaces traces of stone-working are still
present", faint but present. **Tooling 5–20 mm deep has survived ~4,500 years
of Wiltshire rain.** A renderer that smooths the stones into featureless
boulders is not depicting weathering, it is depicting an erosion rate an order
of magnitude too high.

Two colour cues worth having: pooled rainwater in the depressions of the
recumbent Slaughter Stone reacts with iron in the stone and stains it rusty red
(English Heritage; **Debated**, tertiary), and the monument contains oddly
coloured sarsens — "purple-grey" (Stones 53, 154, 56) and "orange" (54, 55,
156) in Trilithons 2 and 3 (**Attested**, RR 32-2012).

Case-hardening — a hardened surface crust over softer interior, with
cementation varying between and within boulders — is reported by a sarsen
specialist writing outside peer review, with no crust thickness given.
**Debated**; usable as a reason for differential relief, not as a number.

## The dressing

The 2011 Greenhatch laser survey (0.5 mm scan; 1 mm analysis meshes for every
stone, 0.5 mm for four faces) recorded **448 discrete areas of stone-working**
and found working on virtually every stone. Everything in this section is
**Attested** from Abbott & Anderson-Whymark 2012 unless marked.

The governing pattern, and the one thing to take away: **everything visible
from the NE (Avenue) approach or from inside the monument is dressed; the
backs that face SW are rough or raw.** The report's own conclusion is that the
Circle "was built and dressed with an apparent emphasis on the NE–SW
solstitial axis". Whether the SW third was ever *completed* is **Debated**
(Tilley et al. 2007 vs Johnson 2008) and any app prose must say so.

The roughness ladder, coarsest first: large flaking (scars > 1 m, mauls up to
~30 kg) → coarse longitudinal dressing with ridges (1–5 kg mauls) → coarse
longitudinal channels without ridges → fine transverse tooling (0.5–2 kg) →
fine longitudinal tooling (0.5–2 kg) → fine pick dressing (< 1 kg) → grinding
to polish. Coarse and *very* coarse pick dressing are the **joint** textures:
tenons, seats, tongue-and-groove joints, lintel rebates — surfaces invisible in
the finished monument.

**Sarsen Circle uprights.** Interior and exterior faces are essentially
*crust removal only*: fine pick dressing over the natural sarsen surface,
which stripped the orange-brown or grey crust to reveal the grey-white
interior **without substantially flattening the stone**. Natural macro-relief
is retained. Exceptions dressed flatter than natural: inner faces of 10, 22,
28; exterior faces of 10, 11, 28, 30. The *sides* are much more extensively
dressed than the faces — fine longitudinal tooling on the sides of 17
uprights. Face-shape statistics for a generator: interior faces 17 of 21 flat
(77%); exterior faces 9 flat (47%), 9 slightly-to-very irregular (47%), 1
convex, 1 concave. NE arc (22–30, 1–9) dominated by trapezoidal faces (18
faces, 77%), giving an optical illusion of height; the rear is 67%
rectangular. **Unworked in the SW: exterior faces of Stones 14, 15 and 16, and
the sides of Stone 14. Backs of 10 and 11 carry only coarse finishes.**

**Trilithons 1, 2, 4, 5.** Inner faces flat and extensively fine pick dressed
(Stone 60's inner face is naturally very flat). Sides less uniformly dressed.
**Exterior faces comparatively rough** — pick-dress finished, but with the
20–30 cm coarse ridging and the transverse tooling clearly visible beneath.
This is the only place in the monument where the coarse ridge-and-flute relief
appears.

**Great Trilithon (55, 56, 156).** Reverses the pattern: interior faces
**vertically convex**, exterior faces **perfectly flat and finished to a very
high quality** — the best surface on the monument — and both sides well
dressed, unlike the other trilithons' rough exteriors. The 55/56 gap is a
narrow, exceptionally regular rectangular portal on the solstitial axis, with
matching portals at Circle 30/1 and 15/16. Note a trap: a separate sentence in
the report describes stone *sides* running the opposite way (outer sides
convex, internal sides perfectly straight). Faces and sides are different
claims; do not merge them. Below-ground bases of 55, 56 and 59 retain fresh
**coarse pecking** — buried surfaces were left at a coarse stage.

**Lintels.** Circle lintels are extensively shaped, curved in plan to match
the circumference, visible faces fine pick dressed. Quality grades round the
ring: 130, 101, 102 on the NE are the most regular; 105 and 107 less so;
Lintel 122 at the rear is very irregular and poorly shaped. Trilithon lintels
are "exceedingly well worked and finished". Undersides, rebates and joints are
very coarse.

**Heel Stone (96).** Entirely unworked — a natural boulder, full crust. Its
only artificial marks are a 19th-century Ordnance Survey datum and a 2008
vandal chip. Dimensions (c.4.7 m above ground, 1.2 m buried, 2.4 m minimum
thickness, 7.6 m girth, ~35 t, leaning ~27°) are **Debated**, see correction 5.

**Station Stones.** Stone 91 is not worked. Stone 93 is largely unworked, with
only limited areas of fine pick dressing on its N and S sides.

**Slaughter Stone (95).** The outlier among the outliers: dressed to Circle
standard — coarse longitudinal tooling on its exterior NE face, fine
longitudinal tooling on its NW side, all finished with fine pick dressing.

**Bluestones**, for contrast: the Horseshoe stones mirror the trilithon
inward-fine/outward-rough gradient (Stone 68 exceedingly finely pick dressed;
67, 69, 70, 72 left at the earlier tooling stage). Only 3 of the 30 surviving
Bluestone Circle stones are dressed at all.

Colour of the finished work: freshly pick-dressed sarsen was **bright
grey-white**, markedly lighter than the orange-brown/grey crust it replaced.
Four and a half thousand years have re-greyed it to today's dull grey.

Dressing effort, for anyone tempted to render the site under construction: a
professional mason produced six cubic inches of sarsen dust per hour with a
stone maul (Stone 1924), and Zaminski peck-dressed about 0.09 m² of flat
sarsen per day using 4.5 kg and 2.2 kg mauls (Harding 2025). **Attested.**

## Lichen

The best-quantified source on lichen at Stonehenge is not a lichenological
paper — it is the laser-scan report's short "effects of surface lichen"
section. Its numbers are the only ones we should treat as load-bearing.

**Structure and zonation (Attested).** Crustose species "adhere tightly to the
stones and occur from ground level upwards"; shrubby fruticose species "are
typically found above head height, as below this level they have been
dislodged by visitors". Dense fruticose cover hindered examination of **23%
(245 m²)** of the stone surface; back-calculating, total scanned stone surface
≈ 1065 m² (our arithmetic, **Speculative**). Fruticose growth is intermittent,
obscuring "small c.40 mm diameter areas", appearing in the mesh as "smooth
domed or lumpy areas". Crustose species are "comparatively flat" and did not
hinder identification of carvings; thickness variation < 0.2 mm against
carvings ~0.5 mm deep. **All graffiti and prehistoric carvings occur below the
level that fruticose lichens are found** — the two zones do not overlap.

The critical point for us: **the vertical zonation at Stonehenge is
anthropogenic, not climatic.** The fruticose zone begins where hands stop
reaching. English Heritage says the same in public: "these lichens only grow at
the top of the stones, and that's because they've died back where the stones
have been touched by people over the years." Reading "head height" as
1.7–2.0 m is our inference (**Speculative**), but the rule itself is Attested.

**Dominant species (Attested).** The fruticose cover is primarily *Ramalina
siliquosa*, sea ivory (Leong, Brolly & Nash 2025). The British Lichen Society
describes it as pale yellow-grey to greenish grey, glossy or warted and
wrinkled, brittle, with scimitar-shaped branches; popular accounts call it
"fuzzy grey-green", giving the stones "a hairy coat".

**The sarsen crustose assemblage (Attested for sarsen generally, not
stone-by-stone at Stonehenge):** *Lecanora gangaleoides*, *L. rupicola*,
*Lecidea cyathoides*, *Xanthoparmelia* (=*Parmelia*) *conspersa*, *P.
omphalodes*, *Rhizocarpon geographicum*, *Anaptychia runcinata* (=*A. fusca*),
*Ramalina siliquosa*, *Rinodina atrocinerea*, *Buellia saxorum*,
*Candelariella coralliza*, *Pertusaria pseudocorallina* (BLS Bulletin 38,
1976, which states Stonehenge and Avebury "carry a similar lichen flora").
*Buellia saxorum* is apparently confined in Britain to sarsen; *Candelariella
coralliza* is more abundant on sarsen than anywhere else in Britain.

**Species count.** ~80 is the honest headline. 79 recorded pre-2003 (Rose &
James 1994), 77 in the 2003 survey (Giavarini & James), James himself saying
"about 80 to 90". Both underlying reports are unpublished and offline, so every
figure is second-hand. **Debated.** About nine or ten species are maritime,
which Gilbert explained by salt carried inland on thermals — he explicitly
framed that as his own theory. **Debated.**

**Two things this pass refused to confirm, and one it inverted.**

- **No aspect-resolved lichen data exists for Stonehenge.** None. The
  documented spatial controls are height (human contact) and cleaned-graffiti
  patches — not compass aspect. Armstrong 2002 found *Rhizocarpon* more
  abundant on south-facing slate in Gwynedd, which is an upland-slate result
  and points the *opposite* way to the shader's current north-east bias.
  Applying either direction at Stonehenge is **Speculative**.
- **The orange *Xanthoria*/*Caloplaca* bird-perch community on lintel tops is
  not documented at Stonehenge and should not be rendered as if it were.** The
  strand brief assumed it; the researcher declined to confirm it, correctly.
  Sarsen is siliceous, which suits *Candelariella* (bright yellow) rather than
  calcicolous orange *Caloplaca*. **This directly contradicts the comment at
  `Henge.metal:746`, which names *Xanthoria* as "what is actually on them".
  It is not.**
- Growth rates: *Rhizocarpon* diametral growth is size-dependent, rising
  steeply below 10 mm, holding near 0.8 mm/yr, declining above 50 mm; mean
  0.64 mm/yr (SD 0.24) in southern Iceland 2001–2005, with **north Wales
  faster by ~66%** (≈1.0 mm/yr diametral). Other published rates: ~0.5 mm/yr
  New Hampshire; 0.1–0.2 mm/yr west Greenland; ~4 mm/century maritime
  sub-Antarctic. **Attested**, with the sign corrected. Either way, a 100 mm
  crustose rosette is a multi-century feature: treat the pattern as static.

**One usable spatial anecdote (Debated).** Peter James produced separate
species lists for each of the 82 stones, and bright-yellow *Candelariella*
"flourished wherever English Heritage had tried to remove paint graffiti".
On the east face of Stone 5 a "D" and "I" are reportedly still legible in
yellow lichen where 1960s paint was cleaned off. **Cleaned patches become
bright-yellow colonisation loci that hold the shape of the cleaning.**

**Nothing is known about lichen on re-erected surfaces.** No source says the
formerly buried portions are bare or differently colonised. The nearest datum
is that the 1958 Phillips' Core through Stone 58 has dead lichen at both ends,
so both faces were lichen-bearing then. Any rule making re-erected surfaces
bare is invented. **Speculative.**

### Colours, as approximate linear RGB — renderer interpretation only

**These are Speculative in full.** No source publishes reflectance for any of
these organisms. They are our reading of verbal colour descriptions (BLS,
NatureSpot, Wikipedia) into linear values that sit sensibly against a
weathered pale-grey substrate. They are a starting point to be tuned by eye,
not measurements, and no app-facing prose may cite them as fact.

| Element | Linear RGB (approx.) | Notes |
|---|---|---|
| *Ramalina siliquosa*, dry | 0.34, 0.36, 0.26 | Pale yellow-grey to greenish grey; desaturated, not a green wash |
| *Ramalina siliquosa*, wet | 0.20, 0.24, 0.16 | Rehydrates darker and greener after rain |
| Grey crustose mat (*Lecanora*, *Pertusaria*) | 0.30, 0.30, 0.28 | Near-neutral, very slightly warm |
| *Lecanora gangaleoides* apothecia | 0.02, 0.02, 0.02 | Black discs to 2 mm, ringed by a wide pale-grey margin ≈ 0.45 neutral |
| *Rhizocarpon geographicum* areoles | 0.30, 0.33, 0.07 | Yellow-green areoles 0.2–1.8 mm on a black prothallus ≈ 0.015; patches to ~15 cm |
| *Candelariella coralliza* | 0.55, 0.40, 0.05 | Bright yellow granular; use only on cleaned/abraded loci |
| *Xanthoparmelia conspersa* | 0.22, 0.22, 0.12 | Yellow-grey to bluish-grey foliose rosettes, lobes to 3 mm |
| Dark foliose (*P. omphalodes*, *Anaptychia*) | 0.07, 0.06, 0.05 | Brown-grey, near-black at distance |
| Fresh dressed sarsen (wet 10YR 8/1) | 0.59 neutral | From ASTM D1535 value→luminance; dry is paler still |
| Weathered exterior sarsen | 0.42–0.50 neutral | Dull grey; current constant 0.52/0.49/0.44 sits at the top of this |
| Natural iron-stained crust (10YR 7/4) | 0.34, 0.26, 0.16 | Undressed faces: Heel Stone, Station Stones, backs of 14–16 |

## What the renderer should change

Mapped to knobs that exist today. Each item marked **[A]** where the *shape*
of the change is Attested-backed, **[I]** where it is artistic interpretation.
Numbers in world metres, matching the shader's convention that `fbm(p * f)`
has a characteristic wavelength of about `1/f` metres.

### 1. Fix two comments that are factually wrong **[A]**

`Henge.metal:783` attributes solution hollows to dissolution of "the
silcrete's carbonate cement". Sarsen is 0.01 wt% CaO; the cement is quartz.
Rewrite to granular disintegration, loss of less-cemented patches and
inclusion casts. `Henge.metal:746` names *Xanthoria* and *Rhizocarpon* as
"what is actually on them"; *Xanthoria* is undocumented here and the dominant
organism is *Ramalina siliquosa*. Two-line fixes, and both are the kind of
claim invariant 3 covers.

### 2. Dressing is a per-face property, and it belongs in `HengeGeometry` **[A]**

This is the largest single upgrade available and it is not a shader change.
The laser scan gives a **per-stone, per-face finish grade**, and stone ids in
`Scene.swift` already carry canonical numbers (`stone-1`…`stone-30`,
`stone-51`…`stone-60`, `stone-95`, `stone-96`), so the table keys directly.

Add to `HengeGeometry` a `Dressing` lookup returning, per stone, a finish
grade for the interior face, the exterior face and the sides — on the report's
own ladder (raw crust → coarse ridged → coarse channelled → fine tooled →
fine pick → ground). Then carry it to the shader in `DrawUniforms` as a new
`float4 dressing`: `xy` = the outward radial direction in world XZ (so the
fragment shader can classify a face by `dot(n.xz, outward)`), `z` = interior
grade, `w` = exterior grade. Per the Metal conventions in AGENTS.md, this
means updating `ShaderTypes.swift`, `Henge.metal` *and*
`testUniformLayoutsAreTheExpectedSize` together.

The oracle-friendly test: assert the table's grades against the report's own
stone lists (14/15/16 exteriors unworked, 55/56 exteriors highest grade,
96 and 91 raw throughout). That is a fixture from a published source, not code
checked against itself.

Minimum viable version if the uniform change is too much for one order: three
grades only — **raw** (96, 91, 93, exteriors of 14–16), **dressed** (all Circle
and trilithon faces), **fine** (Great Trilithon exteriors, interior faces of
trilithons 1/2/4/5). Even that removes the current "all eighty stones are the
same rock" reading.

### 3. Per-face asymmetry in roughness and displacement **[A] for direction, [I] for magnitudes**

- Undressed faces keep the full natural boulder relief the mesh already
  generates, plus the crust colour (linear ≈ 0.34/0.26/0.16) and no
  brightening.
- Dressed Circle faces keep their **macro-relief** — the report is explicit
  that pick dressing did not substantially flatten them — but gain the
  brighter grey-white base and a fine dimpled micro-normal. This is a
  colour-and-micro-texture change, *not* a flattening. Getting this backwards
  (smoothing the circle uprights) is the most likely mistake.
- Trilithon exteriors gain the coarse ridging: vertically elongated noise at
  wavelength **0.20–0.30 m** with amplitude **0.05–0.075 m**. That is real
  geometry at mesh scale, not a normal map — the same anisotropy trick the
  rain-streak field already uses, e.g. `fbm(float3(p.x * 4.0, p.y * 0.4,
  p.z * 4.0))`, applied as displacement on faces whose grade is "coarse
  ridged".
- Fine tooling grooves: 0.05–0.10 m wide, 0.20–0.30 m long, **5–20 mm deep**,
  transverse on trilithon uprights and longitudinal on Circle sides. Normal
  map plus a shallow displacement; `f ≈ 10–20` across the groove direction.
- Fine pick dimples: sub-centimetre, under 1 mm deep, so `f ≈ 100–300`. Below
  the 1.5 m/tile rock texture's usable detail — this must be procedural
  normal detail, not the albedo map.
- Ground/polished patches: lower ~2 m of the interior NW faces of **Stones 53
  and 10** only. Drop roughness to ~0.45 there against the 0.85–0.92 base.
  Cheap, exactly two stones, and Attested.
- Buried/re-exposed bases (55, 56, 59) are **coarse pecked**, not fine.

### 4. Solution hollows: the current `fbm(p * 4.5)` is roughly the right scale **[A] for gating, [I] for depth**

At `f = 4.5` the characteristic wavelength is ~0.22 m, which lands inside the
documented decimetre range for pan basins. Keep it. Three fixes:

- **Depth.** Pans have depth:diameter < 0.1, so a 0.2 m hollow is 1–2 cm
  deep. The current implementation expresses pits only as a normal
  perturbation (`crust * pits * 0.55`) and a 32% albedo darkening, which is
  the right *idea* but unbounded in apparent depth. Tie the normal
  perturbation to an explicit depth of 0.01–0.03 m so the reading is
  physically anchored.
- **Gating.** Already correctly multiplied by `clamp(n.y, 0, 1)` — pans form
  only on flat surfaces, and pooled water is precisely why. This is Attested
  and should be commented as such.
- **A second population.** Pebble casts and natural cup hollows are *not*
  gravity-controlled: cm to ~0.15 m, on any face, on undressed stones
  especially. A separate low-density term with no `n.y` gate, `f ≈ 8–12`,
  sparse threshold.
- Add root/burrow tubes on undressed stones only: 3–15 mm, both orientations.
  Very small, but they are what makes an undressed sarsen read "gnarled"
  rather than merely bumpy.

### 5. Lichen: change the tint, the zonation and the relief model **[A] for zonation, [I] for colour]**

Current: `lichenTint = (0.74, 0.79, 0.48)` applied as
`albedo * lichenTint * 1.45`, i.e. an effective multiplier of about
(1.07, 1.15, 0.70) — it brightens and pushes hard toward yellow-green. That
reads as *Rhizocarpon* on granite. The dominant organism here is *Ramalina
siliquosa*, pale yellow-grey to greenish grey.

- **Tint.** Move toward a desaturated grey-green: roughly **(0.88, 0.90,
  0.74)** with the gain reduced from 1.45 to ~1.05, or equivalently target an
  absolute fruticose albedo near linear (0.34, 0.36, 0.26). **[I]**, but
  grounded in the BLS description rather than in a different rock's flora.
- **Zonation.** Replace the north-east `sheltered` term as the *primary*
  control with the documented height rule: fruticose **only above ~1.7–2.0 m**
  (`weather.x` already gives the foot, so `height` is already in hand), and
  crustose from ground level upward. The aspect bias is Speculative and there
  is no Stonehenge data behind it in either direction — keep it, if at all, as
  a weak secondary modulation, and say so in the comment. **[A]**
- **Coverage.** Dense fruticose cover is 23% of total stone area with
  effectively none below head height; on a 4.1 m circle upright that implies
  roughly 35–40% coverage *within* the upper zone (our arithmetic,
  **Speculative**, from an Attested 23%). The current `patch` threshold
  `smoothstep(0.28, 0.66, fbm(p * 1.7))` should be retuned against that target
  rather than by eye, and the patch scale wants to be near **40 mm** — so
  `f ≈ 25`, an order of magnitude finer than 1.7. As it stands the shader
  paints lichen in metre-scale continents; the source says discrete 4 cm
  blobs. **[A]**
- **Relief.** Split the two structural classes. Crustose is a **film under
  0.2 mm** — albedo only, zero normal perturbation. Fruticose is domed clumps
  of ~40 mm across standing low-single-digit mm proud — that is where the
  `crust * lichen * 0.35` normal term belongs, gated to the upper zone.
  Currently one term does both, which is why lichen reads as a decal
  everywhere. **[A]**
- **Roughness.** `mix(roughness, 0.96, …)` for lichen is right. Keep.
- **Carvings, if ever added:** they occur only below the fruticose zone, so
  they never need to be composited under it.

### 6. The damp course **[I], and it should be labelled so**

`weather.z` is 0.55 m. **No published capillary-rise figure for sarsen was
found.** The petrology argues for a modest rise — 7.2–9.2% porosity in a
moderately connected network is not a strong wick — so **0.25–0.40 m** is a
better guess than 0.55, but it remains a guess and the comment should say so
rather than implying it is measured. The documented basal feature at
Stonehenge is not a damp course at all: it is the **lichen-free scuff zone**
up to head height. Consider expressing the foot as (a) a modest damp tint plus
(b) a hard absence of fruticose lichen below ~1.8 m.

### 7. `.asItWas` and `.asItStands` should not share a surface **[A]**

`Monument.State` already distinguishes the completed monument c.2200 BC from
today's ruin, but both currently render with `weather.y = 1`. The report is
explicit that fine pick dressing exposed a **bright grey-white** interior and
that today's dull grey is 4,500 years of subsequent weathering. So:

- `.asItWas`: base albedo near linear 0.58–0.62, near-neutral; **lichen
  amount 0**; full tooling relief crisp; crust colour only on the faces the
  builders left raw (exteriors of 14–16, the Heel Stone, Station Stones).
- `.asItStands`: today's dull grey (current 0.52/0.49/0.44 is defensible),
  full lichen model, tooling softened but never erased.

The visitor-caused lichen zonation is a *modern* artefact, so it must not
appear in `.asItWas` at all. This is the sharpest test of whether the
weathering model is physical or decorative.

### 8. Micro-appearance **[I]**

The rock is >99% quartz with a mean grain of 187 μm and 7–9% porosity: matte
and granular at sub-millimetre scale, essentially no coherent specular, but at
close range individual quartz grains can glint. If a sparkle term is ever
added, that is its justification — a very high-frequency, very low-coverage
specular, not a broad sheen. Base roughness 0.85–0.92 is right; the 0.14
specular floor is right; wet-is-glossier at the foot is physically right.

## Sources

Primary and peer-reviewed, all consulted directly in this pass unless noted:

- Abbott, M. & Anderson-Whymark, H., *Stonehenge Laser Scan: Archaeological
  Analysis Report*, English Heritage Research Report Series 32-2012 (2012).
  The single most important source here; full PDF read and quoted verbatim.
- Nash, D. J., Ciborowski, T. J. R., Ullyott, J. S., Parker Pearson, M.,
  Darvill, T., Greaney, S., Maniatis, G. & Whitaker, K. A., "Origins of the
  sarsen megaliths at Stonehenge", *Science Advances* 6: eabc0133 (2020).
- Nash, D. J. et al., "Petrological and geochemical characterisation of the
  sarsen stones at Stonehenge", *PLOS ONE* 16(8): e0254760 (2021).
- Richards, J. & Whitby, M., "The Engineering of Stonehenge", *Proceedings of
  the British Academy* 92 ("Science and Stonehenge", ed. Cunliffe), 231–256
  (1997).
- Harding, P., "Demystifying sarsen: breaking the unbreakable", *The
  Antiquaries Journal* 105, 359–379 (2025), doi:10.1017/S0003581525100309.
- Ullyott, J. S. & Nash, D. J., "Micromorphology and geochemistry of
  groundwater silcretes in the eastern South Downs, UK", *Sedimentology* 53,
  387–412 (2006); Ullyott, Nash, Whiteman & Mortimore, *Earth Surface
  Processes and Landforms* 29, 1509–1539 (2004).
- Worsley, P., "Geology of the Clatford Bottom catchment and its sarsen stones
  on the Marlborough Downs", *Mercian Geologist* 19(4), 242–254 (2019) —
  carrying Clark et al. 1967 and Small et al. 1970.
- Parker Pearson, M., "The sarsen stones of Stonehenge", *Proceedings of the
  Geologists' Association* 127(3), 363–369 (2016). **Correct attribution**;
  not read directly (publisher 403).
- Leong, G., Brolly, M. & Nash, D. J., "Novel lichen simulation and laser scan
  modelling to reveal lichen-covered carvings at Stonehenge", *Results in
  Engineering* 27: 106377 (2025), doi:10.1016/j.rineng.2025.106377. Abstract
  only; full text paywalled.
- Leong, G. & Brolly, M., "What lies beneath? Revealing lichen covered
  surfaces at Stonehenge", SEAHA/UCL conference poster; and Leong, G.,
  *Revealing lichen-covered rock art at Stonehenge*, PhD thesis, University of
  Brighton (2024) — abstract only.
- "Sarsen lichens at risk", *British Lichen Society Bulletin* 38, May 1976
  (photo credited J. R. Laundon). The sarsen lichen assemblage.
- Bradwell, T. & Armstrong, R. A., "Growth rates of *Rhizocarpon geographicum*
  lichens: a review with new data from Iceland" (2007), NERC Open Research
  Archive.
- Armstrong, R. A., "The effect of rock surface aspect on growth, size
  structure and competition in the lichen *Rhizocarpon geographicum*",
  *Environmental and Experimental Botany* 48, 187–194 (2002). Abstract only.
- Timms, B. V. & Rankin, C., "The geomorphology of gnammas (weathering pits)
  of northwestern Eyre Peninsula, South Australia: typology, influence of
  haloclasty and origins", *Transactions of the Royal Society of South
  Australia* 140(1) (2016), doi:10.1080/03721426.2015.1115459. **Correct
  attribution**; granite analogue, use with the Debated tier attached.
- Field, D., Anderson-Whymark, H. et al., "Analytical Surveys of Stonehenge
  and its Environs, 2009–2013: Part 2 — the Stones", *Proceedings of the
  Prehistoric Society* 81, 125–148 (2015). The peer-reviewed companion to
  RR 32-2012; pagination from catalogue records, not the paper itself.
- Atkinson, R. J. C., *Stonehenge* (1979 edn), p. 126 — quoted verbatim inside
  RR 32-2012 for the inner-fine/outer-rough gradient.

Tertiary and unrefereed, used only where marked Debated or Speculative:
British Lichen Society and NatureSpot species accounts; English Heritage's
"The Stones of Stonehenge", "Building Stonehenge" and "Nature at Stonehenge"
pages; Britannica; Simon Banton's stonesofstonehenge.org.uk; Peter Marren's
obituary of Peter James (*The Independent*, 30 March 2014); Katy Whitaker's
artefactual.co.uk posts; sarsen.org. The Rose & James (1994) and Giavarini &
James lichen surveys are unpublished and offline — which is why every species
count in circulation is second-hand.

**Not used, and deliberately so:** any claim that sarsen shows polygonal
surface cracking; any orange *Caloplaca*/*Xanthoria* nutrient-enriched
community on the lintel tops; any aspect rule for lichen at Stonehenge; any
statement that re-erected surfaces are lichen-free. Each was searched for and
each came back empty. Absence of evidence has been recorded as absence of
evidence rather than quietly filled in.
