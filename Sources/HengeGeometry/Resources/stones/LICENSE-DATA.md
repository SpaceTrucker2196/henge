# Licence for the data in this folder

`daw-locked-poses.csv` is a derived work of Tim Daw's `data/locked_poses.json`
in [stonehenge-block-3d](https://github.com/TimDaw37/stonehenge-block-3d),
which he offers under **Creative Commons Attribution-ShareAlike 4.0
International (CC BY-SA 4.0)**, © 2026 Tim Daw. Daw digitised the stone
positions from the M J Rees & Co survey of the monument (1989/90), Historic
England Archive sheet MP/STO0861.

What changed on the way in: the JSON array became a CSV with a fixed column
order, and lock metadata, colour classes and notes were dropped. No value was
altered. `scripts/import_daw_poses.py` reproduces the file from the pinned
commit recorded in its header.

**This CSV is itself offered under CC BY-SA 4.0**, as the share-alike term
requires. The rest of this repository is not; the licence attaches to the data
file alone. Reuse it with the attribution above and the same licence.

Full legal code: <https://creativecommons.org/licenses/by-sa/4.0/legalcode>
