#!/usr/bin/env python3
"""Bake Salisbury Plain into a heightfield the app can carry.

Reads SRTM 1-arc-second tiles and writes a square, metric heightfield centred
on the monument. Two things need it: the terrain the user stands on, and — more
importantly — the true skyline, because the altitude of the horizon in a given
direction moves the sunrise bearing by more than a degree at this latitude.
Until now that skyline was a number passed in by hand.

    ./scripts/bake_terrain.py --tiles ~/dem --out Sources/HengeGeometry/Resources

Source data, in order of preference:

  * Environment Agency LIDAR Composite DTM 2022, 1 m, Open Government Licence
    v3 (attribution: "© Environment Agency copyright and/or database right
    2022. All rights reserved."). A *bare-earth* terrain model: buildings and
    tree canopy are classified out. Fetched from Defra's WCS as an uncompressed
    float32 GeoTIFF on the British National Grid, already scaled to the bake
    spacing, so the download is a few megabytes rather than the plain at 1 m.

        ./scripts/bake_terrain.py --fetch-lidar --lidar ~/dem/plain-dtm.tif \
            --out Sources/HengeGeometry/Resources

  * SRTM 1-arc-second (NASA/USGS), public domain, as Skadi `.hgt` tiles — the
    original source, kept as the fallback for any LiDAR void. SRTM is a radar
    *surface* model: on the Larkhill ridge it reported the tree tops as ground
    and put the north-east skyline at 0.71° where a photographic panorama from
    the circle shows 0.35°. That is half a solar diameter in the one number the
    alignment claim turns on, which is why the LiDAR came in (SECURITY.md).

        ./scripts/bake_terrain.py --tiles ~/dem --out Sources/HengeGeometry/Resources

Both readers are hand-rolled — raw int16 for SRTM, a minimal TIFF walker for
the LiDAR — so this needs no GDAL and no third-party package. The WGS84 to
OSGB36 conversion is the Ordnance Survey's own published procedure (Helmert
then Transverse Mercator), good to a few metres, which is a tenth of a sample.

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


# ── Environment Agency LiDAR on the British National Grid ────────────────────

# The WCS endpoint and coverage, written down so the bake is reproducible.
LIDAR_WCS = ("https://environment.data.gov.uk/spatialdata/"
             "lidar-composite-digital-terrain-model-dtm-1m-2022/wcs")
LIDAR_COVERAGE = ("13787b9a-26a4-4775-8523-806d13af58fc"
                  "__Lidar_Composite_Elevation_DTM_1m")


def wgs84_to_osgb36(lat, lon):
    """Latitude/longitude (WGS84) to OSGB36 easting/northing, in metres.

    Ordnance Survey, *A guide to coordinate systems in Great Britain*: geodetic
    to cartesian on GRS80, a seven-parameter Helmert shift onto the Airy 1830
    datum, back to geodetic, then the National Grid's Transverse Mercator.
    Good to about 5 m, against a 40 m sample.
    """
    # 1. WGS84 geodetic -> cartesian.
    a, b = 6378137.0, 6356752.3141
    e2 = 1 - (b * b) / (a * a)
    phi, lam = math.radians(lat), math.radians(lon)
    nu = a / math.sqrt(1 - e2 * math.sin(phi) ** 2)
    x = nu * math.cos(phi) * math.cos(lam)
    y = nu * math.cos(phi) * math.sin(lam)
    z = (1 - e2) * nu * math.sin(phi)

    # 2. Helmert, WGS84 -> OSGB36 (OS published parameters).
    tx, ty, tz = -446.448, 125.157, -542.060
    s = 20.4894e-6
    rx, ry, rz = (math.radians(v / 3600) for v in (-0.1502, -0.2470, -0.8421))
    x2 = tx + (1 + s) * x - rz * y + ry * z
    y2 = ty + rz * x + (1 + s) * y - rx * z
    z2 = tz - ry * x + rx * y + (1 + s) * z

    # 3. Cartesian -> geodetic on Airy 1830.
    a, b = 6377563.396, 6356256.909
    e2 = 1 - (b * b) / (a * a)
    p = math.hypot(x2, y2)
    phi = math.atan2(z2, p * (1 - e2))
    for _ in range(10):
        nu = a / math.sqrt(1 - e2 * math.sin(phi) ** 2)
        phi = math.atan2(z2 + e2 * nu * math.sin(phi), p)
    lam = math.atan2(y2, x2)

    # 4. Transverse Mercator, National Grid constants.
    F0 = 0.9996012717
    phi0, lam0 = math.radians(49), math.radians(-2)
    N0, E0 = -100000.0, 400000.0
    n = (a - b) / (a + b)
    sinp, cosp, tanp = math.sin(phi), math.cos(phi), math.tan(phi)
    nu = a * F0 / math.sqrt(1 - e2 * sinp ** 2)
    rho = a * F0 * (1 - e2) / (1 - e2 * sinp ** 2) ** 1.5
    eta2 = nu / rho - 1
    M = b * F0 * ((1 + n + 1.25 * n ** 2 + 1.25 * n ** 3) * (phi - phi0)
                  - (3 * n + 3 * n ** 2 + 2.625 * n ** 3) * math.sin(phi - phi0) * math.cos(phi + phi0)
                  + (1.875 * n ** 2 + 1.875 * n ** 3) * math.sin(2 * (phi - phi0)) * math.cos(2 * (phi + phi0))
                  - (35 / 24) * n ** 3 * math.sin(3 * (phi - phi0)) * math.cos(3 * (phi + phi0)))
    I = M + N0
    II = nu / 2 * sinp * cosp
    III = nu / 24 * sinp * cosp ** 3 * (5 - tanp ** 2 + 9 * eta2)
    IIIA = nu / 720 * sinp * cosp ** 5 * (61 - 58 * tanp ** 2 + tanp ** 4)
    IV = nu * cosp
    V = nu / 6 * cosp ** 3 * (nu / rho - tanp ** 2)
    VI = nu / 120 * cosp ** 5 * (5 - 18 * tanp ** 2 + tanp ** 4 + 14 * eta2 - 58 * tanp ** 2 * eta2)
    dl = lam - lam0
    northing = I + II * dl ** 2 + III * dl ** 4 + IIIA * dl ** 6
    easting = E0 + IV * dl + V * dl ** 3 + VI * dl ** 5
    return easting, northing


def read_geotiff_float32(path):
    """A minimal TIFF walker for what the WCS actually sends: one float32
    band, uncompressed, tiled or stripped, either byte order. Returns
    (width, height, samples, nodata, transform) where transform is the
    (origin_e, origin_n, pixel_size) of the top-left corner if the file
    carries it, else None."""
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:2] not in (b"II", b"MM"):
        raise SystemExit(f"{path}: not a TIFF")
    e = "<" if data[:2] == b"II" else ">"
    ifd = struct.unpack(e + "I", data[4:8])[0]
    count = struct.unpack(e + "H", data[ifd:ifd + 2])[0]
    sizes = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8, 16: 8}
    codes = {1: "B", 2: "s", 3: "H", 4: "I", 5: "II", 6: "b", 7: "B", 8: "h",
             9: "i", 10: "ii", 11: "f", 12: "d", 16: "Q"}
    tags = {}
    for i in range(count):
        tag, kind, n, raw = struct.unpack(e + "HHI4s", data[ifd + 2 + i * 12:ifd + 14 + i * 12])
        size = n * sizes[kind]
        payload = raw[:size] if size <= 4 else data[struct.unpack(e + "I", raw)[0]:][:size]
        tags[tag] = payload if kind == 2 else struct.unpack(e + codes[kind] * n, payload)

    width, height = tags[256][0], tags[257][0]
    if tags.get(259, (1,))[0] != 1 or tags.get(258) != (32,) or tags.get(339, (3,))[0] != 3:
        raise SystemExit(f"{path}: need uncompressed float32; ask the WCS for image/tiff")

    samples = array.array("f", [0.0]) * (width * height)
    if 324 in tags:                                   # tiled
        tw, th = tags[322][0], tags[323][0]
        across = (width + tw - 1) // tw
        for index, (offset, length) in enumerate(zip(tags[324], tags[325])):
            tile = array.array("f")
            tile.frombytes(data[offset:offset + length])
            if (e == "<") != (sys.byteorder == "little"):
                tile.byteswap()
            tx, ty = (index % across) * tw, (index // across) * th
            for r in range(min(th, height - ty)):
                row = tile[r * tw:r * tw + min(tw, width - tx)]
                samples[(ty + r) * width + tx:(ty + r) * width + tx + len(row)] = row
    else:                                             # stripped
        flat = array.array("f")
        for offset, length in zip(tags[273], tags[279]):
            flat.frombytes(data[offset:offset + length])
        if (e == "<") != (sys.byteorder == "little"):
            flat.byteswap()
        samples = flat

    nodata = None
    if 42113 in tags:
        nodata = float(tags[42113].split(b"\0")[0])
    transform = None
    if 33550 in tags and 33922 in tags:
        transform = (tags[33922][3], tags[33922][4], tags[33550][0])
    elif 34264 in tags:
        m = tags[34264]
        transform = (m[3], m[7], m[0])
    return width, height, samples, nodata, transform


class LidarGrid:
    """The EA composite DTM over the plain, on the National Grid, sampled by
    latitude and longitude so it slots in where an SRTM tile would."""

    def __init__(self, path, bbox=None):
        self.width, self.height, self.data, self.nodata, transform = read_geotiff_float32(path)
        if transform is None:
            if bbox is None:
                raise SystemExit(f"{path}: no georeferencing tags and no --lidar-bbox")
            e0, n0, e1, n1 = bbox
            transform = (e0, n1, (e1 - e0) / self.width)
        self.origin_e, self.origin_n, self.pixel = transform
        self.voids = 0
        print(f"  loaded {os.path.basename(path)}  {self.width}x{self.height} at "
              f"{self.pixel:g} m, top-left E {self.origin_e:.0f} N {self.origin_n:.0f}")

    def _value(self, row, col):
        v = self.data[row * self.width + col]
        if self.nodata is not None and (v == self.nodata or v < -1000):
            return None
        return v

    def sample(self, lat, lon):
        """Bilinear, in metres; None outside the grid or in a void."""
        easting, northing = wgs84_to_osgb36(lat, lon)
        col = (easting - self.origin_e) / self.pixel - 0.5
        row = (self.origin_n - northing) / self.pixel - 0.5
        if not (0 <= col < self.width - 1 and 0 <= row < self.height - 1):
            return None
        c0, r0 = int(col), int(row)
        fc, fr = col - c0, row - r0
        corners = [self._value(r0 + dr, c0 + dc) for dr in (0, 1) for dc in (0, 1)]
        valid = [v for v in corners if v is not None]
        if not valid:
            self.voids += 1
            return None
        corners = [v if v is not None else sum(valid) / len(valid) for v in corners]
        top = corners[0] * (1 - fc) + corners[1] * fc
        bottom = corners[2] * (1 - fc) + corners[3] * fc
        return top * (1 - fr) + bottom * fr

    # Every point asked of it is inside the plain by construction.
    def contains(self, lat, lon):
        return True


def lidar_bbox(width, spacing, margin=800.0):
    """The National Grid box the bake needs, with a margin for the grid's
    0.14° rotation against true north at this longitude."""
    e, n = wgs84_to_osgb36(SITE_LATITUDE, SITE_LONGITUDE)
    half = (width - 1) / 2 * spacing + margin
    return (round(e - half), round(n - half), round(e + half), round(n + half))


def fetch_lidar(path, bbox, spacing):
    """One WCS GetCoverage, scaled server-side to the bake spacing."""
    import urllib.request
    e0, n0, e1, n1 = bbox
    url = (f"{LIDAR_WCS}?service=WCS&version=2.0.1&request=GetCoverage"
           f"&coverageId={LIDAR_COVERAGE}&format=image/tiff"
           f"&subset=E({e0},{e1})&subset=N({n0},{n1})"
           f"&SCALEFACTOR={1.0 / spacing:g}")
    print(f"  GET {url}")
    with urllib.request.urlopen(url, timeout=300) as response:
        body = response.read()
    if body[:2] not in (b"II", b"MM"):
        raise SystemExit(f"WCS did not return a TIFF: {body[:200]!r}")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(body)
    print(f"  wrote {path} ({len(body):,} bytes)")


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


def sample_at(sources, lat, lon):
    """First source with an answer wins: LiDAR, then SRTM for its voids."""
    for source in sources:
        if source.contains(lat, lon):
            value = source.sample(lat, lon)
            if value is not None:
                return value
    return None


def bake(sources, width, spacing):
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

            value = sample_at(sources, lat, lon)
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
    parser.add_argument("--lidar", help="EA LiDAR DTM GeoTIFF (EPSG:27700, float32)")
    parser.add_argument("--fetch-lidar", action="store_true",
                        help="download --lidar from Defra's WCS first")
    parser.add_argument("--tiles", help="directory of SRTM .hgt tiles (fallback for voids)")
    parser.add_argument("--out", required=True, help="output directory")
    parser.add_argument("--width", type=int, default=768, help="samples per side")
    parser.add_argument("--spacing", type=float, default=40.0, help="metres between samples")
    args = parser.parse_args()

    if not args.lidar and not args.tiles:
        parser.error("need --lidar and/or --tiles")

    sources = []
    if args.lidar:
        bbox = lidar_bbox(args.width, args.spacing)
        if args.fetch_lidar:
            print("Fetching LiDAR:")
            fetch_lidar(args.lidar, bbox, args.spacing)
        print("Loading LiDAR:")
        sources.append(LidarGrid(args.lidar, bbox))
    if args.tiles:
        print("Loading tiles:")
        sources.extend(load_tiles(args.tiles))

    radius_km = (args.width - 1) / 2 * args.spacing / 1000
    print(f"Baking {args.width}x{args.width} at {args.spacing:g} m "
          f"(±{radius_km:.1f} km)")

    samples, missing = bake(sources, args.width, args.spacing)
    if missing:
        print(f"  WARNING: {missing} samples had no source and were set to 0 m")
    for source in sources:
        if isinstance(source, LidarGrid) and source.voids:
            print(f"  {source.voids} LiDAR voids fell through to the next source")

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
