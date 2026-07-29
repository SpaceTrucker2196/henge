# henge — token / cost ledger

Append-only. Rows are produced by `~/.claude/billing/ledger.py --append`
after each substantive commit. Never hand-author, estimate, or rewrite rows.
If the script can't produce a row, stop and surface it. Energy estimate for
the whole ledger: `ledger.py --energy-total`.

| commit | date | model(s) | input | output | cache_read | cache_write | cost_usd | summary |
|--------|------|----------|------:|-------:|-----------:|------------:|---------:|---------|
<!-- ledger rows appended here -->
| 138718c | 2026-07-28T18:17:47Z | claude-fable-5 | 303 | 300405 | 24096002 | 619947 | 51.5182 | Light shafts: volumetric haze pass with shadow-cascade beams at sunrise/sunset |
| 7c0f65b | 2026-07-28T18:21:44Z | claude-fable-5 | 56 | 30094 | 7337860 | 32904 | 9.5012 | Top-strip almanac, phase glyphs, lunar-marker research note |
| 6366532 | 2026-07-28T18:29:48Z | claude-fable-5 | 90 | 92558 | 13031967 | 142306 | 20.5069 | Geometry overlay mode + gold Hoyle markers on the Aubrey ring |
| 5c07a2e | 2026-07-28T18:39:44Z | claude-fable-5 | 116 | 113580 | 19506289 | 118711 | 27.5607 | Stone individuality: per-seed mesh shapes, multifractal, variance-preserving ble |
| 520872f | 2026-07-28T18:55:53Z | claude-fable-5 | 104 | 99375 | 20049541 | 187613 | 28.7716 | Review fixes: haze/cascade contract, marker disc phase, rebuild throttle, on-scr |
| 6279eec | 2026-07-28T18:56:52Z | claude-fable-5 | 10 | 3242 | 2053360 | 6206 | 2.3397 | Session instrumentation: metrics + progress |
| b44152e | 2026-07-28T20:29:29Z | claude-fable-5 | 59 | 24443 | 13145388 | 83423 | 16.0366 | Sarsen geology research re-run (clean), roadmap update; weathering work ended pe |
| 8d16b7d | 2026-07-28T20:45:52Z | claude-fable-5 | 100 | 71097 | 23773964 | 111382 | 29.5575 | Torchlit ceremony mode with adversarial review fixes |
| a924825 | 2026-07-29T03:20:37Z | claude-fable-5 | 180 | 188631 | 43267151 | 3356050 | 119.8215 | Hipparcos star catalogue + almanac strip tightening |
| 469ade9 | 2026-07-29T03:45:58Z | claude-fable-5 | 206 | 172946 | 61457360 | 206686 | 74.2404 | Weather dressing: clouds/rain/frost with 7 review findings fixed |
| 4aa2414 | 2026-07-29T03:54:21Z | claude-fable-5 | 98 | 35439 | 32091832 | 58708 | 35.0389 | Design system vocabulary: tokens for spacing/radius/ink/motion |
| 9789aa9 | 2026-07-29T03:57:00Z | claude-fable-5 | 18 | 6292 | 6052905 | 8937 | 6.5464 | Session close: progress note |
| f8ac053 | 2026-07-29T04:04:42Z | claude-fable-5 | 16 | 9580 | 5422476 | 4375 | 5.9891 | Rail hit targets: 44pt floor + capsule content shape |
| f11c878 | 2026-07-29T04:13:56Z | claude-fable-5 | 60 | 79317 | 20899725 | 65268 | 26.1715 | Star labels + moon label, magnitude/type visual differentiation |
| 5624251 | 2026-07-29T04:15:38Z | claude-fable-5 | 14 | 15962 | 4984350 | 8445 | 5.9515 | Bottom control stack as a slide-away drawer with handle |
| eb65dda | 2026-07-29T04:28:02Z | claude-fable-5 | 76 | 76105 | 27671990 | 66912 | 32.8162 | Night sky: moon photograph + normal fix, Prussian night, twinkle, starlit ground |
| a3abaf0 | 2026-07-29T04:32:08Z | claude-fable-5 | 26 | 22327 | 9726241 | 19376 | 11.2304 | Play button hit floor + drawers on all three panels |
| 3d7a089 | 2026-07-29T04:38:57Z | claude-fable-5 | 38 | 36030 | 14521817 | 33117 | 16.9860 | Panels block touch fall-through to the scene |
| f32b6bd | 2026-07-29T04:42:08Z | claude-fable-5 | 10 | 4495 | 3890285 | 3162 | 4.1784 | Star twinkle: fast irregular shimmer via beating rates |
| 230e255 | 2026-07-29T04:52:34Z | claude-fable-5 | 64 | 70923 | 25311526 | 68816 | 30.2346 | Planets from VSOP87D + doubled star/moon display size |
| bb091c8 | 2026-07-29T04:58:16Z | claude-fable-5 | 20 | 8920 | 8067769 | 12548 | 8.7649 | Full IAU star-name register in the label layer |
| cd2dd3b | 2026-07-29T05:12:11Z | claude-fable-5 | 60 | 23982 | 24875014 | 47018 | 27.0151 | Compact layout fixes, verified via simulator screenshots |
| a28d0ba | 2026-07-29T05:19:48Z | claude-fable-5 | 30 | 10587 | 12705437 | 22517 | 13.6854 | App icon installed for both targets, verified on springboard |
| 4e3c62e | 2026-07-29T05:26:04Z | claude-fable-5 | 58 | 29952 | 25173688 | 54372 | 27.7593 | Mistletoe & Oak visual pass, simulator-verified |
| 2748735 | 2026-07-29T05:29:59Z | claude-fable-5 | 24 | 15907 | 10619230 | 25308 | 11.9210 | Drawer handles offset clear of panel text |
