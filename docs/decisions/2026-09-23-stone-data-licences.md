# Per-stone data: what may be vendored, and under what terms

**Decided by the owner, 23 September 2026**, while planning issues #3, #4 and
#5. Recorded here because MISSION.md invariant 5 makes adding a data set a
deliberate act, and because the reasoning will not be obvious in a year.

## The rule

**Any source whose licence is non-commercial, or that requires permission for
commercial use, stays out of the repository.** Henge is sold on the App Store.
A licence that permits commercial use with attribution is fine; a licence that
attaches share-alike to a data file is acceptable, since it attaches to that
file and not to the app; a licence that forbids or gates commercial use is not
acceptable until the gate is opened in writing.

## The verdicts

| Source | What it gives | Licence, as checked | Verdict |
|---|---|---|---|
| Tim Daw, `stonehenge-block-3d`, `data/locked_poses.json` | Position, yaw, footprint, height and an accuracy grade for 93 stones, digitised from the Rees 1989/90 survey | CC BY-SA 4.0, in the repository's `LICENSE`: "share and adapt the material for any purpose, even commercially" | **In.** Vendored as `Sources/HengeGeometry/Resources/stones/daw-locked-poses.csv`. That one file is published under CC BY-SA 4.0 (see `LICENSE-DATA.md` beside it). Attribution in the app's info view and in `SECURITY.md`. |
| Cleal, Walker & Montague 1995, *Stonehenge in its Landscape*, Appendix 5, via the Archaeology Data Service | Height above ground per stone | ADS Terms of Use and Access: use and adaptation for historic-environment research "including as part of the commercial sector", with acknowledgement | **In**, with the ADS credit line. Not yet vendored; issue #3. |
| Petrie 1880, *Stonehenge: Plans, Description, and Theories*, pp 10–12 | Height and top level per stone in 1877 | Public domain | **In.** Not yet vendored; issue #3. |
| Historic England Research Report 32/2012, Appendix 1 | Surface area, volume and estimated weight per stone from the 2011 laser scan | The PDF is "© English Heritage" with no open licence stated. Historic England's re-use terms say commercial exploitation of its information needs written permission. | **Out**, until Historic England grants written permission. No CSV, no extraction script output, no derived per-stone table. The four cross-section figures quoted in issue #4 are a cited calculation in a comment and a test, not the dataset. A request is drafted in `docs/outreach/`. |

## What Daw's data is, and is not

- It is a **digitisation of a measured plan**, not a measurement. Daw's README
  puts the residual against Rees at "a few tenths of a metre on the sarsens"
  and says it is "not a GNSS ground survey".
- Each row carries Daw's own **`accuracy_class`**. `locked`, `plan_locked`,
  `plan_locked_auto`, `locked_medium_conf` and `thickness_normed` are read off
  the plan. `seed_only` and `plan_digitised` are placeholders he has said are
  placeholders; the app carries them as *provisional* and never as surveyed.
- Daw's `NOTICE.md` credits Three.js, astronomy-engine and the Environment
  Agency but does not cite Rees or Historic England. The app cites both.
- The heights in his file are mixed: some from Cleal's appendix, some
  placeholders. Issue #3 replaces them with Cleal and Petrie directly.

## The frame

The engine's origin is the sarsen circle's centre, fitted by least squares
through the thirteen uprights that Daw locked to the plan and that still stand
on their sockets (`StonePoseTable`). The rounded site coordinate in
`GeographicSite.stonehenge` lands about 6 m north of that centre, inside the
Helmert transform's own error and well inside the 40 m terrain sample, so the
terrain is not re-baked. Grid bearings are turned through the National Grid's
convergence at the site (about 0.14°) so that the plan's north is the north
the sun is measured against.

## Attribution text, verbatim

> Stone positions after Tim Daw, *stonehenge-block-3d* (CC BY-SA 4.0),
> digitised from the M J Rees & Co 1989/90 survey of Stonehenge, Historic
> England Archive MP/STO0861.
