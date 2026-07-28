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
