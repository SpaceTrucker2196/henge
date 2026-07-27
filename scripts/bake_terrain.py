#!/usr/bin/env python3
"""Bake Salisbury Plain into a heightfield the app can carry.

Reads SRTM 1-arc-second tiles and writes a square, metric heightfield centred
on the monument. Two things need it: the terrain the user stands on, and — more
importantly — the true skyline, because the altitude of the horizon in a given
direction moves the sunrise bearing by more than a degree at this latitude.
Until now that skyline was a number passed in by hand.

    ./scripts/bake_terrain.py --tiles ~/dem --out Sources/HengeGeometry/Resources

Source data: SRTM 1-arc-second (NASA/USGS), public domain, fetched as Skadi
`.hgt` tiles. Format is raw big-endian int16 metres, 3601x3601 per one-degree
tile, no header — which is why this needs no GDAL and no third-party package.

Output format `HGT1`, little-endian:

    magic     4 bytes  "HGT1"
    width     uint32   samples
    height    uint32   samples
    spacing   float32  metres between samples
    centre    float32  ground height at the monument, metres
    samples   int16[]  metres above sea level, row-major, north row first

Row 0 is the northernmost, matching the app's +Z-is-south world axes.
"""

import argparse
import array
import math
import os
import struct
import sys

# The monument. Same constants as GeographicSite.stonehenge — if they ever
# disagree the terrain would be baked around the wrong point, so the test
# suite checks the baked centre height against the site's own elevation.
SITE_LATITUDE = 51.1789
SITE_LONGITUDE = -1.8262

# Metres per degree of latitude. Good to a few parts in a thousand over the
# span of one plain, which is far finer than a 30 m sample.
METRES_PER_DEGREE_LATITUDE = 111_320.0

TILE_SAMPLES = 3601  # 1 arc-second


class Tile:
    """One SRTM one-degree tile, indexed by latitude and longitude."""

    def __init__(self, path, lat_south, lon_west):
        data = array.array("h")
        with open(path, "rb") as handle:
            data.frombytes(handle.read())
        if sys.byteorder == "little":
            data.byteswap()  # .hgt is big-endian
        expected = TILE_SAMPLES * TILE_SAMPLES
        if len(data) != expected:
            raise SystemExit(f"{path}: expected {expected} samples, found {len(data)}")
        self.data = data
        self.lat_south = lat_south
        self.lon_west = lon_west

    def contains(self, lat, lon):
        return (self.lat_south <= lat < self.lat_south + 1
                and self.lon_west <= lon < self.lon_west + 1)

    def sample(self, lat, lon):
        """Bilinear, in metres. Voids (-32768) fall back to their neighbours."""
        row = (self.lat_south + 1 - lat) * (TILE_SAMPLES - 1)
        col = (lon - self.lon_west) * (TILE_SAMPLES - 1)

        r0 = max(0, min(TILE_SAMPLES - 2, int(math.floor(row))))
        c0 = max(0, min(TILE_SAMPLES - 2, int(math.floor(col))))
        fr, fc = row - r0, col - c0

        corners = []
        for dr in (0, 1):
            for dc in (0, 1):
                value = self.data[(r0 + dr) * TILE_SAMPLES + (c0 + dc)]
                corners.append(None if value == -32768 else float(value))

        valid = [v for v in corners if v is not None]
        if not valid:
            return 0.0
        corners = [v if v is not None else sum(valid) / len(valid) for v in corners]

        top = corners[0] * (1 - fc) + corners[1] * fc
        bottom = corners[2] * (1 - fc) + corners[3] * fc
        return top * (1 - fr) + bottom * fr


def load_tiles(directory):
    tiles = []
    for name in sorted(os.listdir(directory)):
        if not name.endswith(".hgt"):
            continue
        stem = name[:-4]                       # e.g. N51W002
        lat = int(stem[1:3]) * (1 if stem[0].upper() == "N" else -1)
        lon = int(stem[4:7]) * (1 if stem[3].upper() == "E" else -1)
        tiles.append(Tile(os.path.join(directory, name), lat, lon))
        print(f"  loaded {name}  (lat {lat}..{lat+1}, lon {lon}..{lon+1})")
    if not tiles:
        raise SystemExit(f"no .hgt tiles in {directory}")
    return tiles


def sample_at(tiles, lat, lon):
    for tile in tiles:
        if tile.contains(lat, lon):
            return tile.sample(lat, lon)
    return None


def bake(tiles, width, spacing):
    """Sample a metric grid centred on the monument."""
    half = (width - 1) / 2.0
    samples = array.array("h", [0]) * (width * width)
    missing = 0

    for row in range(width):
        # Row 0 is the northernmost, so north decreases as row increases.
        north = (half - row) * spacing
        lat = SITE_LATITUDE + north / METRES_PER_DEGREE_LATITUDE
        metres_per_degree_longitude = METRES_PER_DEGREE_LATITUDE * math.cos(math.radians(lat))

        for col in range(width):
            east = (col - half) * spacing
            lon = SITE_LONGITUDE + east / metres_per_degree_longitude

            value = sample_at(tiles, lat, lon)
            if value is None:
                missing += 1
                value = 0.0
            samples[row * width + col] = int(round(value))

    return samples, missing


def horizon_profile(samples, width, spacing, centre_height, eye_height=1.7, steps=720):
    """Skyline altitude by bearing — the reason this exists.

    Marches outward from the monument along each bearing and keeps the greatest
    angular elevation. Reported here as a sanity check; the app computes the
    same thing from the same data at runtime, so nothing is baked in.
    """
    half = (width - 1) / 2.0
    eye = centre_height + eye_height
    profile = []

    for step in range(steps):
        azimuth = step * 360.0 / steps
        # +X east, +Z south; azimuth from north through east.
        dx = math.sin(math.radians(azimuth))
        dz = -math.cos(math.radians(azimuth))

        best = -90.0
        distance = spacing
        limit = half * spacing
        while distance < limit:
            col = half + (dx * distance) / spacing
            row = half + (dz * distance) / spacing
            if not (0 <= col < width - 1 and 0 <= row < width - 1):
                break
            c0, r0 = int(col), int(row)
            height = samples[r0 * width + c0]
            angle = math.degrees(math.atan2(height - eye, distance))
            best = max(best, angle)
            distance += spacing
        profile.append((azimuth, best))
    return profile


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tiles", required=True, help="directory of SRTM .hgt tiles")
    parser.add_argument("--out", required=True, help="output directory")
    parser.add_argument("--width", type=int, default=768, help="samples per side")
    parser.add_argument("--spacing", type=float, default=40.0, help="metres between samples")
    args = parser.parse_args()

    print("Loading tiles:")
    tiles = load_tiles(args.tiles)

    radius_km = (args.width - 1) / 2 * args.spacing / 1000
    print(f"Baking {args.width}x{args.width} at {args.spacing:g} m "
          f"(±{radius_km:.1f} km)")

    samples, missing = bake(tiles, args.width, args.spacing)
    if missing:
        print(f"  WARNING: {missing} samples fell outside the supplied tiles")

    centre = float(samples[(args.width // 2) * args.width + args.width // 2])
    print(f"  ground at the monument: {centre:.0f} m")
    print(f"  range: {min(samples)} m to {max(samples)} m")

    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, "salisbury-plain.heightfield")
    with open(path, "wb") as handle:
        handle.write(b"HGT1")
        handle.write(struct.pack("<IIff", args.width, args.width, args.spacing, centre))
        out = array.array("h", samples)
        if sys.byteorder == "big":
            out.byteswap()
        handle.write(out.tobytes())
    print(f"  wrote {path} ({os.path.getsize(path):,} bytes)")

    print("\nSkyline, for comparison with the app's own computation:")
    profile = dict((round(a), h) for a, h in
                   horizon_profile(samples, args.width, args.spacing, centre))
    for bearing in (0, 45, 50, 90, 135, 180, 225, 230, 270, 315):
        nearest = min(profile, key=lambda a: abs(a - bearing))
        print(f"  {bearing:3d}°  {profile[nearest]:+.3f}°")


if __name__ == "__main__":
    main()
