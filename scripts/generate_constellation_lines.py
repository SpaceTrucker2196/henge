#!/usr/bin/env python3
"""Author the constellation figures and generate ConstellationLines.swift.

The figures are this app's own drawings. Star membership of the classical
constellations is ancient common knowledge (Ptolemy's Almagest carries the
same lists); which pairs to join is authored here, by hand, for this app —
no external stick-figure dataset is consulted, which is what keeps the
layer licence-free. Stars are referenced by IAU proper name, resolved
through the register in StarCatalog.swift, or by approximate J2000
position for unnamed figure stars; every reference must resolve against
the vendored Hipparcos subset or the script refuses to emit.

Usage: python3 scripts/generate_constellation_lines.py
"""
import csv, math, pathlib, re, sys

REPO = str(pathlib.Path(__file__).resolve().parent.parent)

# catalogue: hip -> (ra, dec, mag)
cat = {}
with open(f"{REPO}/Sources/HengeGeometry/Resources/hipparcos-bright.csv") as f:
    for row in csv.reader(f):
        cat[int(row[0])] = (float(row[1]), float(row[2]), float(row[3]))

# name register out of the generated Swift
names = {}
src = open(f"{REPO}/Sources/HengeGeometry/StarCatalog.swift").read()
for hip, name in re.findall(r'(\d+): "([^"]+)"', src):
    names[name] = int(hip)

def by_pos(ra, dec, maxmag=5.2, radius=1.6):
    best, bestd = None, radius
    for hip, (r, d, m) in cat.items():
        if m > maxmag: continue
        dd = math.hypot((r - ra) * math.cos(math.radians(dec)), d - dec)
        if dd < bestd: best, bestd = hip, dd
    return best

def sep(a, b):
    (r1, d1, _), (r2, d2, _) = cat[a], cat[b]
    r1, d1, r2, d2 = map(math.radians, (r1, d1, r2, d2))
    c = math.sin(d1)*math.sin(d2) + math.cos(d1)*math.cos(d2)*math.cos(r1-r2)
    return math.degrees(math.acos(max(-1, min(1, c))))

# Figures: chains (consecutive stars joined) and extra single segments.
# A star is an IAU name string, or ("~", ra_deg, dec_deg) for unnamed ones.
F = {}
def fig(name, chains, extras=()):
    F[name] = (chains, extras)

# ── the zodiac ──────────────────────────────────────────────────────────
fig("Aries", [["Hamal", "Sheratan", "Mesarthim"]])
fig("Taurus", [["Prima Hyadum", "Secunda Hyadum", "Ain", "Elnath"],
               ["Prima Hyadum", ("~",67.2,15.9), "Aldebaran", "Tianguan"]])
fig("Gemini", [["Castor", "Wasat", "Alhena"],
               ["Pollux", "Wasat"],
               ["Wasat", "Mebsuta", "Tejat", "Propus"]])
fig("Cancer", [["Tarf", "Asellus Australis", "Asellus Borealis"],
               ["Asellus Australis", "Acubens"]])
fig("Leo", [["Regulus", ("~",151.8,16.8), "Algieba", "Adhafera", "Rasalas",
             ("~",146.5,23.8)],
            ["Regulus", "Chertan", "Denebola", "Zosma", ("~",151.8,16.8)],
            ["Zosma", "Chertan"]])
fig("Virgo", [["Spica", "Porrima", "Zaniah", "Zavijava"],
              ["Porrima", ("~",193.9,3.4), "Vindemiatrix"],
              ["Spica", "Heze", ("~",193.9,3.4)]])
fig("Libra", [["Zubenelgenubi", "Zubeneschamali", "Zubenelhakrabi",
               "Zubenelgenubi"]])
fig("Scorpius", [["Dschubba", "Antares", "Paikauhale", "Larawag",
                  ("~",252.5,-38.0), ("~",253.1,-42.4), ("~",258.0,-43.2),
                  "Sargas", ("~",266.9,-40.1), ("~",265.6,-39.0), "Shaula"],
                 ["Lesath", "Shaula"],
                 ["Acrab", "Dschubba", "Fang"]])
fig("Sagittarius", [["Alnasl", "Kaus Media", "Kaus Australis", "Ascella",
                     ("~",286.7,-27.7), "Nunki", ("~",281.4,-27.0),
                     "Kaus Borealis", "Kaus Media"],
                    ["Ascella", ("~",281.4,-27.0)]])
fig("Capricornus", [["Algedi", "Dabih", ("~",311.5,-25.3), ("~",312.9,-26.9),
                     ("~",321.7,-22.4), "Nashira", "Deneb Algedi",
                     ("~",316.5,-17.2), "Algedi"]])
fig("Aquarius", [["Sadalsuud", "Sadalmelik", "Sadachbia", ("~",338.8,-0.1)],
                 ["Sadalmelik", ("~",335.4,-7.8)],
                 [("~",335.4,-7.8), ("~",343.2,-7.6), "Skat"],
                 ["Sadalsuud", "Albali"]])
fig("Pisces", [[("~",349.3,3.3), "Fumalsamakah", ("~",355.5,1.8),
                ("~",353.5,6.4), ("~",349.3,3.3)],
               ["Alrescha", ("~",22.6,6.1), ("~",15.7,7.9), ("~",12.2,7.6),
                ("~",359.8,6.9), ("~",353.5,6.4)],
               ["Alrescha", "Torcular", "Alpherg"]])

# ── the north and the flagships ─────────────────────────────────────────
fig("Ursa Major", [["Alkaid", "Mizar", "Alioth", "Megrez", "Dubhe", "Merak",
                    "Phecda", "Megrez"]])
fig("Ursa Minor", [["Polaris", "Yildun", ("~",251.5,82.0), ("~",236.0,77.8),
                    "Kochab", "Pherkad", ("~",244.4,75.8), ("~",236.0,77.8)]])
fig("Draco", [["Giausar", ("~",188.4,69.8), "Thuban", "Edasich", "Athebyne",
               "Aldhibah", "Altais", ("~",297.0,70.3)],
              ["Aldhibah", "Grumium"],
              ["Rastaban", "Eltanin", ("~",263.0,55.2), "Grumium",
               "Rastaban"]])
fig("Cassiopeia", [["Caph", "Schedar", ("~",14.2,60.7), "Ruchbah", "Segin"]])
fig("Cepheus", [["Alderamin", "Alfirk", "Errai", ("~",342.4,66.2),
                 ("~",332.7,58.2), "Alderamin"]])
fig("Orion", [["Meissa", "Betelgeuse", "Alnitak", "Saiph", "Rigel", "Mintaka",
               "Bellatrix", "Meissa"],
              ["Alnitak", "Alnilam", "Mintaka"],
              ["Betelgeuse", "Bellatrix"]])
fig("Canis Major", [["Sirius", "Mirzam"],
                    ["Sirius", ("~",106.0,-23.8), "Wezen", "Adhara"],
                    ["Wezen", "Aludra"]])
fig("Canis Minor", [["Procyon", "Gomeisa"]])
fig("Auriga", [["Capella", "Menkalinan", "Mahasim", "Elnath", "Hassaleh",
                "Almaaz", "Capella"]])
fig("Perseus", [["Mirfak", ("~",47.0,53.5), ("~",42.7,55.9)],
                ["Mirfak", ("~",55.7,47.8), ("~",59.5,40.0),
                 ("~",58.5,31.9)],
                ["Mirfak", "Misam", "Algol", ("~",46.2,38.8)]])
fig("Cygnus", [["Deneb", "Sadr", "Albireo"],
               ["Aljanah", "Sadr", "Fawaris"]])
fig("Lyra", [["Vega", ("~",283.8,36.9), "Sheliak", "Sulafat",
              ("~",283.6,32.7), ("~",283.8,36.9)]])
fig("Aquila", [["Tarazed", "Altair", "Alshain"],
               [("~",286.4,13.9), ("~",291.4,3.1), ("~",286.4,-4.9)],
               ["Altair", ("~",291.4,3.1)]])
fig("Pegasus", [["Markab", "Scheat", "Alpheratz", "Algenib", "Markab"],
                ["Markab", "Homam", "Biham", "Enif"],
                ["Scheat", "Matar", ("~",326.6,25.4)]])
fig("Andromeda", [["Alpheratz", ("~",9.8,30.9), "Mirach", "Almach"]])
fig("Boötes", [["Arcturus", "Izar", ("~",228.9,33.3), "Nekkar", "Seginus",
                ("~",217.9,30.4), "Arcturus", "Muphrid"]])
fig("Corona Borealis", [[("~",233.2,31.4), "Nusakan", "Alphecca",
                         ("~",235.7,26.3), ("~",237.4,26.1),
                         ("~",239.4,26.9)]])

# ── resolve ─────────────────────────────────────────────────────────────
problems = []
resolved = {}
for cname, (chains, extras) in F.items():
    segs = []
    def hip_of(star):
        if isinstance(star, tuple):
            h = by_pos(star[1], star[2])
            if h is None:
                problems.append(f"{cname}: no star near {star[1]},{star[2]}")
            return h
        h = names.get(star)
        if h is None:
            problems.append(f"{cname}: name not in register: {star}")
        elif h not in cat:
            problems.append(f"{cname}: {star} (HIP {h}) not in catalogue")
            return None
        return h
    for chain in list(chains) + [list(e) for e in extras]:
        hips = [hip_of(s) for s in chain]
        for a, b in zip(hips, hips[1:]):
            if a and b and a != b:
                segs.append((a, b))
    resolved[cname] = segs

for cname, segs in resolved.items():
    for a, b in segs:
        d = sep(a, b)
        if d > 25:
            problems.append(f"{cname}: segment HIP {a}-{b} spans {d:.1f}°")
        ma, mb = cat[a][2], cat[b][2]
        if max(ma, mb) > 5.4:
            problems.append(f"{cname}: HIP {a if ma>mb else b} is mag {max(ma,mb):.1f}")

if problems:
    print("PROBLEMS:")
    for p in problems: print(" ", p)
    sys.exit(1)

total = sum(len(s) for s in resolved.values())
print(f"OK: {len(resolved)} figures, {total} segments")

OUT = f"{REPO}/Sources/HengeGeometry/ConstellationLines.swift"
lines = []
lines.append("import Foundation")
lines.append("")
lines.append("/// The constellation figures, drawn for this app.")
lines.append("///")
lines.append("/// **Provenance (invariant 5):** the *drawings are ours.* Which stars")
lines.append("/// belong to which constellation is ancient common knowledge — Ptolemy's")
lines.append("/// Almagest carries the same membership — and the choice of which pairs")
lines.append("/// to join was authored by hand for this app, against the vendored")
lines.append("/// Hipparcos subset, with no external stick-figure dataset consulted.")
lines.append("/// That authorship is what keeps the layer licence-free where every")
lines.append("/// published figure set was not. Twenty-nine figures: the zodiac twelve")
lines.append("/// and the flagships of the northern sky, Draco among them because")
lines.append("/// Thuban held the builders' pole.")
lines.append("///")
lines.append("/// Generated by `scripts/generate_constellation_lines.py` — edit the")
lines.append("/// figures there, where every star reference is checked against the")
lines.append("/// catalogue, rather than editing HIP numbers here.")
lines.append("public struct ConstellationFigure: Sendable {")
lines.append("")
lines.append("    public let name: String")
lines.append("    /// Pairs of HIP identifiers; each pair is one drawn line.")
lines.append("    public let segments: [(Int, Int)]")
lines.append("")
lines.append("    public static let all: [ConstellationFigure] = [")
for cname, segs in sorted(resolved.items()):
    lines.append(f'        ConstellationFigure(name: "{cname}", segments: [')
    for i in range(0, len(segs), 4):
        row = ", ".join(f"({a}, {b})" for a, b in segs[i:i+4])
        lines.append(f"            {row},")
    lines[-1] = lines[-1].rstrip(",")
    lines.append("        ]),")
lines[-1] = lines[-1].rstrip(",") + ","
lines[-1] = lines[-1][:-1]
lines.append("    ]")
lines.append("}")
open(OUT, "w").write("\n".join(lines) + "\n")
print(f"wrote {OUT}")
