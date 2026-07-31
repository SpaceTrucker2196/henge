#!/usr/bin/env python3
"""Regenerate StarCatalog.properNames from the IAU Catalog of Star Names.

Usage:
    curl -sL https://www.pas.rochester.edu/~emamajek/WGSN/IAU-CSN.txt -o /tmp/IAU-CSN.txt
    python3 scripts/generate_star_names.py /tmp/IAU-CSN.txt

Parses the fixed-width IAU-CSN table, keeps every named star whose HIP
identifier appears in the bundled Hipparcos subset, and splices the
resulting dictionary into Sources/HengeGeometry/StarCatalog.swift in
place. The name is the ASCII form, taken from the fixed-width name
column *whole* — the first generation of this file split on whitespace
and shipped "Kaus Australis" as "Kaus", three times over.
"""
import csv, re, sys, pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent
SWIFT = REPO / "Sources/HengeGeometry/StarCatalog.swift"

def main(csn_path: str) -> None:
    hips = set()
    with open(REPO / "Sources/HengeGeometry/Resources/hipparcos-bright.csv") as f:
        for row in csv.reader(f):
            hips.add(int(row[0]))

    names: dict[int, str] = {}
    for line in open(csn_path, encoding="utf-8"):
        if line.startswith("#") or line.startswith("$") or not line.strip():
            continue
        name = line[:18].strip()
        # HIP sits before HD, RA, Dec and the ISO date at the line's tail.
        tail = re.search(
            r"(\d+|_)\s+(\d+|_)\s+([\d.]+|_+)\s+([-\d.]+|_+)\s+\d{4}-\d{2}-\d{2}",
            line)
        if not name or not tail or tail.group(1) == "_":
            continue
        hip = int(tail.group(1))
        if hip in hips:
            names[hip] = name

    if len(names) < 300:
        sys.exit(f"only {len(names)} names matched — refusing to shrink the register")
    ascii_only = [n for n in names.values() if not n.isascii()]
    if ascii_only:
        sys.exit(f"non-ascii names slipped through: {ascii_only}")

    # Emit sorted by name, three to a line, matching the shipped style.
    pairs = sorted(names.items(), key=lambda kv: kv[1])
    lines, row = [], []
    for hip, name in pairs:
        row.append(f'{hip}: "{name}"')
        if len(row) == 3:
            lines.append("        " + ", ".join(row) + ",")
            row = []
    if row:
        lines.append("        " + ", ".join(row) + ",")
    lines[-1] = lines[-1].rstrip(",")
    body = "\n".join(lines)

    src = SWIFT.read_text()
    pattern = re.compile(
        r"(public static let properNames: \[Int: String\] = \[\n).*?(\n    \])",
        re.S)
    new, count = pattern.subn(rf"\g<1>{body}\g<2>", src)
    if count != 1:
        sys.exit("could not locate the properNames literal to replace")
    SWIFT.write_text(new)
    multi = sum(1 for n in names.values() if " " in n)
    print(f"wrote {len(names)} names ({multi} multi-word) into {SWIFT.name}")

if __name__ == "__main__":
    main(sys.argv[1])
