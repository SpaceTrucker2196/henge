import Foundation
import simd
import HengeAstro

/// Salisbury Plain, as surveyed.
///
/// This exists for two reasons, and the second is the important one.
///
/// The first is that the monument should stand on the ground it actually
/// stands on: a slight rise, with the dry valley of Stonehenge Bottom falling
/// away to the north-east.
///
/// The second is that **the skyline is part of the astronomy**. The sun does
/// not rise over a sea-level horizon here; it rises over a low ridge, and that
/// delays it. At this latitude 0.7° of skyline moves the sunrise bearing by
/// more than a degree and a half — which is most of the distance between the
/// midsummer sun landing on the monument's axis and missing it. Until this
/// existed that number was passed in by hand, in defiance of MISSION.md
/// invariant 1. Now it is measured from the terrain.
///
/// Data: SRTM 1-arc-second (NASA/USGS), public domain. Baked by
/// `scripts/bake_terrain.py`; provenance in `SECURITY.md`.
public struct TerrainModel: Sendable {

    public let width: Int
    public let height: Int
    /// Metres between samples.
    public let spacing: Double
    /// Height above sea level at the monument itself, in metres.
    public let centreHeight: Double

    private let samples: [Int16]

    public enum LoadError: Error, CustomStringConvertible {
        case resourceMissing
        case badMagic
        case truncated

        public var description: String {
            switch self {
            case .resourceMissing: "salisbury-plain.heightfield is not in the bundle."
            case .badMagic: "Not a HGT1 heightfield."
            case .truncated: "Heightfield is shorter than its header claims."
            }
        }
    }

    public init(data: Data) throws {
        guard data.count >= 20 else { throw LoadError.truncated }
        guard data[data.startIndex..<data.startIndex + 4].elementsEqual("HGT1".utf8) else {
            throw LoadError.badMagic
        }

        func value<T>(_ offset: Int, _ type: T.Type) -> T {
            data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: type) }
        }
        let w = Int(UInt32(littleEndian: value(4, UInt32.self)))
        let h = Int(UInt32(littleEndian: value(8, UInt32.self)))
        let spacing = Double(Float(bitPattern: UInt32(littleEndian: value(12, UInt32.self))))
        let centre = Double(Float(bitPattern: UInt32(littleEndian: value(16, UInt32.self))))

        let expected = 20 + w * h * MemoryLayout<Int16>.size
        guard w > 0, h > 0, data.count >= expected else { throw LoadError.truncated }

        var grid = [Int16](repeating: 0, count: w * h)
        grid.withUnsafeMutableBytes { destination in
            data.copyBytes(to: destination,
                           from: data.startIndex + 20 ..< data.startIndex + expected)
        }

        self.width = w
        self.height = h
        self.spacing = spacing
        self.centreHeight = centre
        self.samples = grid
    }

    /// The baked plain, from the package bundle.
    public static func salisburyPlain() throws -> TerrainModel {
        guard let url = Bundle.module.url(forResource: "salisbury-plain",
                                          withExtension: "heightfield",
                                          subdirectory: "Resources")
                ?? Bundle.module.url(forResource: "salisbury-plain",
                                     withExtension: "heightfield") else {
            throw LoadError.resourceMissing
        }
        return try TerrainModel(data: Data(contentsOf: url))
    }

    // ── sampling ────────────────────────────────────────────────────────────

    /// Metres above sea level at a point in world coordinates
    /// (+X east, +Z south, origin at the monument). Bilinear.
    public func elevation(east: Double, south: Double) -> Double {
        let halfW = Double(width - 1) / 2
        let halfH = Double(height - 1) / 2
        let column = halfW + east / spacing
        // Row 0 is the northernmost, so south increases with row.
        let row = halfH + south / spacing

        let c0 = Int(column.rounded(.down)), r0 = Int(row.rounded(.down))
        guard c0 >= 0, r0 >= 0, c0 < width - 1, r0 < height - 1 else {
            return edgeClamped(column: column, row: row)
        }

        let fc = column - Double(c0), fr = row - Double(r0)
        let topLeft = Double(samples[r0 * width + c0])
        let topRight = Double(samples[r0 * width + c0 + 1])
        let bottomLeft = Double(samples[(r0 + 1) * width + c0])
        let bottomRight = Double(samples[(r0 + 1) * width + c0 + 1])

        let top = topLeft * (1 - fc) + topRight * fc
        let bottom = bottomLeft * (1 - fc) + bottomRight * fc
        return top * (1 - fr) + bottom * fr
    }

    private func edgeClamped(column: Double, row: Double) -> Double {
        let c = Int(min(max(column, 0), Double(width - 1)))
        let r = Int(min(max(row, 0), Double(height - 1)))
        return Double(samples[r * width + c])
    }

    /// Ground height in the app's world space, where the monument sits at y = 0.
    public func groundHeight(east: Double, south: Double) -> Double {
        elevation(east: east, south: south) - centreHeight
    }

    /// Half-width of the covered area, in metres.
    public var extent: Double { Double(width - 1) / 2 * spacing }

    // ── the skyline ─────────────────────────────────────────────────────────

    /// Angular altitude of the skyline in a given direction, seen from the
    /// monument at eye height.
    ///
    /// Marched rather than tabulated, so it stays a computation over cited
    /// survey data rather than a constant somebody typed (invariant 1).
    public func horizonAltitude(azimuth: Angle, eyeHeight: Double = 1.7) -> Angle {
        let eye = eyeHeight
        let direction = WorldAxes.direction(azimuth: azimuth)

        var best = -Double.pi / 2
        var distance = spacing
        let limit = extent
        while distance < limit {
            let east = direction.x * distance
            let south = direction.z * distance
            let rise = groundHeight(east: east, south: south) - eye
            best = max(best, atan2(rise, distance))
            // Step coarsely far out: at 10 km a 40 m step subtends 0.2°, and
            // the ridges that matter are wider than that.
            distance += distance > 4000 ? spacing * 3 : spacing
        }
        return Angle(radians: max(best, 0))
    }

    /// The whole skyline, sampled evenly. Useful for drawing it and for tests.
    public func horizonProfile(samples count: Int = 360,
                               eyeHeight: Double = 1.7) -> [Angle] {
        (0..<count).map { index in
            horizonAltitude(azimuth: Angle(degrees: Double(index) * 360 / Double(count)),
                            eyeHeight: eyeHeight)
        }
    }
}

/// Rise and set bearings over the real skyline.
///
/// The problem is mildly circular: the horizon altitude depends on which way
/// you are looking, and which way you are looking is what we are solving for.
/// Two or three passes settle it — the sun's bearing moves by a degree or so
/// per iteration and the skyline changes slowly with bearing.
public enum Skyline {

    public static func sunriseAzimuth(_ season: Season, year: Int,
                                      site: GeographicSite = .stonehenge,
                                      terrain: TerrainModel,
                                      eyeHeight: Double = 1.7) -> Angle? {
        var horizon = Angle.zero
        var azimuth: Angle?

        for _ in 0..<4 {
            guard let next = RiseSet.seasonalSunriseAzimuth(season, year: year, site: site,
                                                            horizonAltitude: horizon) else {
                return nil
            }
            azimuth = next
            horizon = terrain.horizonAltitude(azimuth: next, eyeHeight: eyeHeight)
        }
        return azimuth
    }

    public static func sunsetAzimuth(_ season: Season, year: Int,
                                     site: GeographicSite = .stonehenge,
                                     terrain: TerrainModel,
                                     eyeHeight: Double = 1.7) -> Angle? {
        var horizon = Angle.zero
        var azimuth: Angle?

        for _ in 0..<4 {
            guard let next = RiseSet.seasonalSunsetAzimuth(season, year: year, site: site,
                                                           horizonAltitude: horizon) else {
                return nil
            }
            azimuth = next
            horizon = terrain.horizonAltitude(azimuth: next, eyeHeight: eyeHeight)
        }
        return azimuth
    }
}
