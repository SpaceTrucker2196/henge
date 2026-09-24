#!/usr/bin/env python3
"""Vendor Tim Daw's per-stone poses as a CSV the engine can read.

Source: https://github.com/TimDaw37/stonehenge-block-3d, `data/locked_poses.json`,
CC BY-SA 4.0. Daw digitised the positions from the M J Rees & Co 1989/90 survey
of the monument (Historic England Archive, sheet MP/STO0861); the file grades
each stone with an `accuracy_class` and this script keeps that grade.

The commit is pinned so the bake is reproducible: rerunning the script writes
the same rows. To take a newer file, change PINNED_COMMIT here, rerun, and
record the change in SECURITY.md and docs/decisions/.

The CSV is the whole of what enters the repo. Nothing is renamed, rounded or
"corrected" on the way in — corrections belong upstream, with Daw — and the
share-alike licence travels with the file in LICENSE-DATA.md beside it.
"""

import csv
import io
import json
import sys
import urllib.request
from pathlib import Path

PINNED_COMMIT = "52e81ba412dfd6c912937b3b1212d962be67c21a"
SOURCE_URL = ("https://raw.githubusercontent.com/TimDaw37/stonehenge-block-3d/"
              f"{PINNED_COMMIT}/data/locked_poses.json")
OUT = Path(__file__).resolve().parent.parent / "Sources/HengeGeometry/Resources/stones/daw-locked-poses.csv"

FIELDS = ["petrie", "role", "status", "e_m", "n_m", "yaw_deg", "z_base_m",
          "width_m", "thickness_m", "length_m", "height_m",
          "footprint_along_m", "footprint_across_m", "accuracy_class",
          "height_source", "hole_e_m", "hole_n_m"]


def main():
    local = sys.argv[1] if len(sys.argv) > 1 else None
    if local:
        data = json.loads(Path(local).read_text())
    else:
        with urllib.request.urlopen(SOURCE_URL, timeout=60) as response:
            data = json.loads(response.read().decode("utf-8"))

    rows = data["array"]
    if data.get("frame") != "OSGB":
        raise SystemExit(f"expected an OSGB frame, got {data.get('frame')!r}")

    def cell(value):
        return "" if value is None else value

    out = io.StringIO()
    out.write("# Stone poses after Tim Daw, stonehenge-block-3d, data/locked_poses.json\n")
    out.write(f"# commit {PINNED_COMMIT}, generated_at {data.get('generated_at')}, frame OSGB (British National Grid, metres)\n")
    out.write("# Licence CC BY-SA 4.0 (c) 2026 Tim Daw. Digitised from the M J Rees & Co 1989/90 survey,\n")
    out.write("# Historic England Archive MP/STO0861. yaw_deg is anticlockwise from grid east along the width axis.\n")
    out.write("# accuracy_class is Daw's own grade; seed_only and plan_digitised are placeholders, not survey.\n")
    writer = csv.DictWriter(out, fieldnames=FIELDS, lineterminator="\n")
    writer.writeheader()
    for row in sorted(rows, key=lambda r: (len(r["id"].rstrip("abc")), r["id"])):
        writer.writerow({
            "petrie": row["id"],
            "role": row["role"],
            "status": row["status"],
            "e_m": row["e_m"],
            "n_m": row["n_m"],
            "yaw_deg": row["yaw_deg"],
            "z_base_m": cell(row.get("z_base_m")),
            "width_m": row["width_m"],
            "thickness_m": row["thickness_m"],
            "length_m": cell(row.get("length_m")),
            "height_m": row["height_m"],
            "footprint_along_m": cell(row.get("footprint_along_m")),
            "footprint_across_m": cell(row.get("footprint_across_m")),
            "accuracy_class": row["accuracy_class"],
            "height_source": cell(row.get("height_source")),
            "hole_e_m": cell(row.get("hole_e_m")),
            "hole_n_m": cell(row.get("hole_n_m")),
        })
    OUT.write_text(out.getvalue())
    print(f"wrote {len(rows)} rows to {OUT}")


if __name__ == "__main__":
    main()
