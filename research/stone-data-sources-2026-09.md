# Stonehenge per-stone data: source register

**river.io · Henge · 23 September 2026**

What exists publicly, per Petrie-numbered stone, for heights, cross-sections, footprints, positions, volumes and weights. Compiled for Henge issues #3 and #4 and for the reply to Simon Banton.

Every entry says how it was checked. **Read** means the source itself was opened and the relevant page or file inspected. **Reported** means a secondary source describes it and the primary was not opened. **Blocked** means the primary could not be opened from here.

---

## Verdict

1. **Exactly three published numeric per-stone tables exist, and all three are free.** Historic England RR 32/2012 Appendix 1 (surface area, volume, above-ground weight). Cleal et al. 1995 Appendix 5 (heights). Petrie 1880 pages 10 to 12 (heights and top levels, in inches, 1877).
2. **No published table gives per-stone width, thickness or at-ground footprint.** Not in 1880, not in 2012, not since. Nobody has compiled one. Brian John asked for the bluestone version publicly in 2011 and never received it.
3. **The measured post-restoration stone plan is unpublished.** It is the M J Rees & Co survey of 1989/90, Historic England Archive sheet MP/STO0861, Swindon. Cleal 1995, Field & Pearson 2010 and Field et al. 2015 all reuse it. Tim Daw digitised it.
4. **The 2011 laser scan was never released, but it has been shared on request.** Deliverables were XYZ and ZFS point clouds, OBJ meshes at 1 mm and 0.5 mm, and TruView files, archived at Historic England Swindon. Trevor Cox at Salford built a 157-stone acoustic model in 2019 from "the Stonehenge laser scan data from Historic England," and Cox et al. 2020 ran statistics on 81 bluestones from a Historic England CAD model. A per-stone CAD model exists and has been handed out to researchers.
5. **The only openly licensed per-stone geometry is Tim Daw's**, published 23 September 2026, CC BY-SA 4.0, 93 stones, digitised from the Rees sheet and graded by accuracy class.

---

## Tier A: published numeric tables, per stone, free

| # | Source | Per-stone fields | Coverage | Measured or derived | Access | Checked |
|---|---|---|---|---|---|---|
| A1 | **Historic England Research Report 32/2012**, Abbott & Anderson-Whymark, *Stonehenge Laser Scan: Archaeological Analysis*, Appendix 1, printed pp 59 and 60 | Surface area (m²), volume (m³), estimated above-ground weight (tons) | Table 1: 50 sarsen rows incl. lintels, stumps, fragments. Table 2: 24 bluestone rows. No Altar Stone. Flags: `*` fallen fragmentary, `†` standing fragmentary, `‡` fallen complete | Measured off the 2011 scan mesh, above ground only. Weight derived from volume at SG 2.4 sarsen, 3.0 dolerite, 2.4 rhyolite | Free PDF, historicengland.org.uk/research/results/reports/32-2012 | **Read.** PDF downloaded, table extracted |
| A2 | **Cleal, Walker & Montague 1995**, *Stonehenge in its Landscape*, EH Archaeological Report 10, Appendix 5 | Height above ground | Standing stones, compiled from the 1919 Chief Architect's Report and Atkinson's records | Measured, tape, 1919 and 1950s to 60s | Free 141 MB PDF on the Archaeology Data Service, eh_monographs_2014 mono 1089007 | **Reported.** Values checked via Banton's transcription for 8 stones; ADS PDF not opened |
| A3 | **Petrie 1880**, *Stonehenge: Plans, Description, and Theories*, section "2. Details of the Stones," pp 10 to 12, plus Plate I | Height above ground (inches), level of top above the OS benchmark on the Heel Stone (inches, to 0.1), difference from group mean, remarks. Plate I draws each stone's "Plan" (horizontal section) and "Emergence" (face line at ground level) | All stones visible in 1877, numbered 1 to 160 in the system still in use. Many fallen bluestones have no height entry | Measured, theodolite and chain, 1874 to 77. **Pre-restoration**: stones 6, 7, 22, 56 and others were leaning or fallen | Public domain. Full view on Google Books id rUUIAQAAMAAJ and HathiTrust wu.89069066629 | **Read.** Table format and sample rows confirmed on page 11 (e.g. stone 51 height 201 in, top level 252.4 in) |
| A4 | **Nash et al. 2020**, *Science Advances* 6(31) eabc0133, data file S1 | Portable XRF chemistry | All 52 sarsens by stone number | Measured | Open access, CC BY-NC 4.0 | **Reported.** Not geometry; listed because it is the only other per-stone open dataset |

---

## Tier B: open geometry, digitised or derived

| # | Source | Per-stone fields | Coverage | Provenance | Licence | Checked |
|---|---|---|---|---|---|---|
| B1 | **TimDaw37/stonehenge-block-3d**, `data/locked_poses.js`, released 23 Sep 2026 | `e_m`, `n_m` (OSGB, mm precision), `yaw_deg`, `width_m`, `thickness_m`, `length_m`, `height_m`, `z_base_m`, `footprint_along_m`, `footprint_across_m`, `accuracy_class`, `height_source`, `source_file` | 93 stones | Positions digitised from Rees 1989 sheet MP/STO0861. Heights partly `cleal_app5_banton`, partly `placeholder`. Accuracy classes: `plan_locked`, `locked`, `plan_locked_auto`, `locked_medium_conf`, `seed_only`, `plan_digitised`, `thickness_normed`. Author: "a platform for forks, not a finished reconstruction claim" | **CC BY-SA 4.0.** NOTICE.md credits Three.js, astronomy-engine and EA LiDAR but does not cite Rees or Historic England | **Read.** File fetched, keys and stone 1 record inspected |
| B2 | **TimDaw37/stonehenge-plan**, live at timdaw37.github.io/stonehenge-plan | Stone number, centroid in OSGB and WGS84 | Same set as B1 | Hatch centroids from the Rees 1989 sheet. "Not a GNSS ground survey." Residual vs Rees "a few tenths of a metre on the sarsens." Google Earth imagery sits about 1.5 m east of this plan at Station Stone 93 | **No licence declared.** Data embedded in `index.html`, no data file | **Reported.** README read by agent; index.html not opened |
| B3 | **OpenStreetMap**, individual stones tagged `natural=stone` | Polygon outline per stone | Unknown count. Petrie numbers in tags not confirmed | Hand-traced from Esri or Bing imagery, expect 0.5 to 1.5 m planimetric error. Retagged from `natural=bare_rock` in changeset 151568412, 20 May 2024 | ODbL | **Blocked.** Overpass not reachable from here. Query to run: `nwr["natural"="stone"](51.1775,-1.829,51.1805,-1.8235); out tags center;` |
| B4 | **Environment Agency National LiDAR Programme** | 1 m DTM and DSM, classified point cloud (.laz), intensity | Whole site | 2016 to 2023 flights, ±15 cm RMSE vertical. 1 m DSM resolves large sarsens as blobs, not footprints. No 25 or 50 cm tile over Stonehenge confirmed; 2017 25 cm composite is retired | Open Government Licence v3 | **Reported.** Dataset pages read by agent |
| B5 | **stonesofstonehenge.org.uk** (Simon Banton) | Height, estimated above-ground weight, rock type | 88 stone pages | Height from A2, weight from A1, rock type from Ixer and Bevins. A transcription, not a source | Site copyright, no licence | **Read.** Notes page and 8 stone pages fetched; weights match A1 exactly |

---

## Tier C: measured geometry that exists but is closed

| # | Source | What exists | Where | Access route | Checked |
|---|---|---|---|---|---|
| C1 | **M J Rees & Co survey, 1989/90** | Measured stone-outline plan, post-restoration, checked by survey-grade GPS | Historic England Archive, Swindon, sheet MP/STO0861 | Archive enquiry. Reused in every EH publication since; never published as data | **Reported.** Cited in Field et al. 2015 and Daw's README |
| C2 | **2011 Greenhatch laser scan** | Landscape at 10 to 50 mm (Leica C10), circle at 1 mm (Z+F 5006h), stone faces at 0.5 mm (Z+F 5010). Deliverables: XYZ and ZFS point clouds, OBJ meshes, TruView, five orthos per 1 mm dataset. Coordinate system not stated | Historic England Archive, Swindon | On request. Bryan et al. 2013 said "potential release in 2014"; it did not happen. Cox 2019 and Cox et al. 2020 received it | **Read** (Cox blog, Greenhatch case study). Bryan 2013 **reported**, CC BY |
| C3 | **Historic England CAD model, 157 stones** | Per-stone solid model derived from C2, used for the visitor-centre VR and for Cox's acoustic model | Historic England | On request, with a research case | **Read** (Cox blog: "157 different stones") |
| C4 | **Historic England 2025 photogrammetry** | Stones 3, 4, 5, 23, 53 at 0.1 mm | *Journal of Cultural Heritage* 2025 | "Available from Historic England, restrictions apply" | **Reported** |
| C5 | **IVAR Studios / National Geographic** | Photogrammetry of "120+ stones," ground and drone | IVAR | Delivered as AR only; archival model not released | **Reported** |
| C6 | **Adam Stanford / Aerial-Cam**, Sketchfab "Stonehenge-260825" | Drone photogrammetry, capture 26 Aug 2025 | Sketchfab | View-only in listing; licence and georeferencing unknown | **Reported.** Sketchfab blocked from here |

---

## Tier D: published, relevant, but no per-stone table

| # | Source | What it adds | Access | Checked |
|---|---|---|---|---|
| D1 | **Field et al. 2015**, *PPS* 81, "Analytical surveys of Stonehenge, Part 2: the stones" | Fig. 2 stone plan from the Rees survey; selected weights from A1 in text; 448 stone-working areas | Paywalled; author copy free on academia.edu 88343805 | **Reported**, read by agent |
| D2 | **Darvill 2022**, *Antiquity* 96, "Keeping time at Stonehenge" | Fig. 4 plots spacing and width of every sarsen circle stone, from the 2011 scan. No numeric table, no supplement | Open access CC BY | **Reported** |
| D3 | **Bryan, Abbott & Dodson 2013**, ISPRS Archives XL-5/W2 | The authoritative list of what the 2011 scan produced and where it went | Open access CC BY | **Reported**, read by agent |
| D4 | **Cox, Fazenda & Greaney 2020**, *J. Archaeol. Sci.* 122 | Confirms the HE CAD model; k-means on volume, surface area and height of 81 bluestones. Values not published | CC BY-NC-ND. Released data is acoustic only | **Reported** |
| D5 | **Thom, Thom & Thom 1974**, *JHA* 5 | 1973 ground survey with Atkinson; fitted geometry | Free scans are image-only, no text layer | **Blocked** |
| D6 | **Stone 1924**, *The Stones of Stonehenge* | Per-stone measurements in prose | Public domain; no free scan located | **Blocked** |

---

## Negative results

These were looked for and are not there.

- No per-stone width or thickness table in any published source, 1880 to 2026.
- No per-stone at-ground footprint table or open polygon set with Petrie numbers.
- No compiled bluestone dimension list. Brian John's 2011 request went unanswered; his 2015 posts give group counts only.
- No Stonehenge stone geometry deposited with the Archaeology Data Service. The Cleal companion databases are attribute tables without coordinates.
- No new laser scan or photogrammetry of the whole monument published with data since 2011.
- No Zenodo, figshare or Journal of Open Archaeology Data release.
- No 2018 to 2026 provenancing paper (Bevins, Ixer, Pearce, Nash, Clarke, Parker Pearson) tabulates per-stone dimensions. The Altar Stone figure of 4.9 × 1.0 × 0.5 m is quoted from archive photographs, not measured.
- No stone-level features in any Ordnance Survey open product. OS NGD Structure Features has a "Standing Stone" polygon class but it is a premium product and its Stonehenge content is unconfirmed.

---

## What this means

**For Simon's question.** The at-ground cross-sections he asked for have never been measured and published. The honest routes are, in order: ask Historic England Archive for the CAD model, citing Cox 2019 as precedent; use Daw's footprints as a graded first approximation; cross-check both against `V/h` from A1 and A2. Petrie's Plate I is an independent 1877 at-ground plan, pre-restoration, which nobody appears to have digitised.

**For Henge.** Per-stone heights: A2, with A3 as an 1877 check. Per-stone cross-sectional area and equal-area circle: `V/h` from A1 and A2, 50 sarsens and 24 bluestones. Per-stone positions, yaw and footprint: B1, CC BY-SA, which needs a licensing decision for a paid closed app. Terrain: B4, OGL. Nothing here gives measured width and thickness; issue #3 should say so.

**For anyone.** The single most valuable thing that could be done with public sources is to digitise Petrie's Plate I stone plans and register them to Daw's Rees-derived centroids. That would give a public, pre-restoration, measured at-ground outline for every stone Petrie could see, from a public domain source.

---

## Method

Four parallel searches on 23 September 2026: primary archaeology (Petrie to Field 2015), open geodata and 3D models, community and GitHub datasets, academic papers 2018 to 2026. Highest-value claims then checked directly: RR 32/2012 downloaded and Appendix 1 extracted; Petrie 1880 opened on Google Books and the table format confirmed on page 11; Daw's `locked_poses.js` fetched and inspected; Cox's 2019 post read for the Historic England data-sharing precedent; Banton's site read for provenance and 8 heights.

Not reachable from here: Overpass API, HathiTrust page views, Sketchfab, archaeologydataservice.ac.uk record pages, GitHub search. Those items are marked Blocked or Reported above.
