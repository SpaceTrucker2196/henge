import Foundation
import simd
import HengeAstro

/// Where each stone stands, from a surveyed plan rather than a ring radius.
///
/// **Provenance (invariant 5):** Tim Daw, *stonehenge-block-3d*,
/// `data/locked_poses.json`, CC BY-SA 4.0. Daw digitised the stone outlines
/// from the M J Rees & Co survey of 1989/90 (Historic England Archive, sheet
/// MP/STO0861) — the measured post-restoration plan every English Heritage
/// publication since Cleal et al. 1995 has reused and none has released as
/// data. His README puts the residual against Rees at a few tenths of a metre
/// on the sarsens and is clear that it is not a ground survey. Each stone
/// carries his `accuracy_class`, and this type keeps it: a `seed_only` or
/// `plan_digitised` row is a placeholder he has said is a placeholder, and
/// the scene marks it so rather than quietly promoting it.
///
/// The file is vendored as a CSV by `scripts/import_daw_poses.py`, pinned to
/// a commit, and the licence decision is recorded in `docs/decisions/`.
/// `SECURITY.md` carries the registry row.
public struct StonePose: Sendable, Hashable {

    public enum Role: String, Sendable {
        case sarsenUpright = "sarsen_upright"
        case sarsenLintel = "sarsen_lintel"
        case trilithonUpright = "trilithon_upright"
        case trilithonLintel = "trilithon_lintel"
        case bluestone
        case bluestoneLintel = "bluestone_lintel"
        case stationStone = "station_stone"
        case altar
        case slaughterStone = "slaughter_stone"
        case heelStone = "heelstone"
    }

    public enum Status: String, Sendable {
        case standing
        /// A lintel still in place.
        case present
        case fallen
        case fallenFragment = "fallen_fragment"
        case stumpOrLow = "stump_or_low"
        case recumbent
        /// A socket with no stone in it — the position is real, the stone is
        /// gone, so it places a reconstruction and nothing in the ruin.
        case emptySocket = "empty_socket_placeholder"

        /// Something is there to draw as it lies today.
        public var survives: Bool { self != .emptySocket }
        /// Upright, with the footprint being the standing section.
        public var isUpright: Bool { self == .standing || self == .present }
    }

    /// Petrie's number, as a string because fragments are `55a`, `9b`.
    public let petrie: String
    public let role: Role
    public let status: Status
    public let grid: OSGB.Point
    /// Anticlockwise from grid east along the stone's width axis — Daw's
    /// convention, converted by `StonePoseTable.bearing(of:)`.
    public let yawDegrees: Double
    public let width: Double
    public let thickness: Double
    public let height: Double
    public let accuracyClass: String
    public let heightSource: String?

    /// Daw's own grade of the position. His placeholders (`seed_only`,
    /// `plan_digitised`) are the ones he says are not read off the plan.
    public var positionIsSurveyed: Bool {
        accuracyClass != "seed_only" && accuracyClass != "plan_digitised"
    }
}

/// The whole plan, in the engine's frame.
public struct StonePoseTable: Sendable {

    public let poses: [StonePose]
    /// The sarsen circle's centre on the grid — the world origin.
    public let centre: OSGB.Point
    /// Radius of the best-fit circle through the locked, standing uprights.
    public let sarsenRingRadius: Double
    /// Grid north to true north at the site; added to every bearing.
    public let convergence: Angle

    public static let citation = Citation(
        "Tim Daw, stonehenge-block-3d, locked_poses (CC BY-SA 4.0)",
        "digitised from the M J Rees & Co 1989/90 survey, Historic England Archive MP/STO0861")

    /// The vendored plan, or nil if the resource is missing — in which case
    /// every generator falls back to its ring formula and every stone is a
    /// reconstruction. A test holds that this is never nil in the package.
    public static let daw: StonePoseTable? = {
        guard let url = bundledURL(), let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return try? StonePoseTable(csv: text)
    }()

    /// Subdirectory first, flat second — the same pair the star catalogue
    /// uses, for the same reason: `.copy("Resources")` keeps the nesting in
    /// the macOS app bundle where the flat lookup cannot see it.
    static func bundledURL(subdirectoryOnly: Bool = false) -> URL? {
        let nested = Bundle.module.url(forResource: "daw-locked-poses",
                                       withExtension: "csv",
                                       subdirectory: "Resources/stones")
        if subdirectoryOnly { return nested }
        return nested
            ?? Bundle.module.url(forResource: "daw-locked-poses", withExtension: "csv",
                                 subdirectory: "stones")
            ?? Bundle.module.url(forResource: "daw-locked-poses", withExtension: "csv")
    }

    public init(csv text: String, site: GeographicSite = .stonehenge) throws {
        var poses: [StonePose] = []
        var header: [String] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let cells = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            if header.isEmpty { header = cells; continue }
            var row: [String: String] = [:]
            for (key, value) in zip(header, cells) where !value.isEmpty { row[key] = value }
            guard let petrie = row["petrie"],
                  let role = row["role"].flatMap(StonePose.Role.init(rawValue:)),
                  let status = row["status"].flatMap(StonePose.Status.init(rawValue:)),
                  let e = row["e_m"].flatMap(Double.init), let n = row["n_m"].flatMap(Double.init),
                  let yaw = row["yaw_deg"].flatMap(Double.init),
                  let width = row["width_m"].flatMap(Double.init),
                  let thickness = row["thickness_m"].flatMap(Double.init),
                  let height = row["height_m"].flatMap(Double.init),
                  let accuracy = row["accuracy_class"]
            else { throw PoseError.malformedRow(line) }
            poses.append(StonePose(petrie: petrie, role: role, status: status,
                                   grid: OSGB.Point(easting: e, northing: n),
                                   yawDegrees: yaw, width: width, thickness: thickness,
                                   height: height, accuracyClass: accuracy,
                                   heightSource: row["height_source"]))
        }
        guard !poses.isEmpty else { throw PoseError.empty }

        // The origin is the sarsen circle's centre, and the circle is what
        // says where that is: a least-squares fit through the uprights Daw
        // locked to the plan and that still stand on their sockets. The
        // rounded site coordinate in `GeographicSite.stonehenge` lands a few
        // metres off it, which is inside the Helmert transform's own error.
        let ring = poses.filter {
            $0.role == .sarsenUpright && $0.status == .standing
                && ($0.accuracyClass == "locked" || $0.accuracyClass == "plan_locked")
        }
        guard ring.count >= 3 else { throw PoseError.tooFewRingStones }
        let fit = StonePoseTable.fitCircle(ring.map { SIMD2($0.grid.easting, $0.grid.northing) })
        self.poses = poses
        self.centre = OSGB.Point(easting: fit.centre.x, northing: fit.centre.y)
        self.sarsenRingRadius = fit.radius
        self.convergence = OSGB.gridConvergence(at: site)
    }

    public enum PoseError: Error {
        case malformedRow(String)
        case empty
        case tooFewRingStones
    }

    public func pose(_ petrie: String) -> StonePose? {
        poses.first { $0.petrie == petrie }
    }

    public func pose(_ petrie: Int) -> StonePose? {
        pose(String(petrie))
    }

    public func poses(role: StonePose.Role) -> [StonePose] {
        poses.filter { $0.role == role }
    }

    /// Ground position in world metres: +X true east, +Z true south, origin
    /// at the circle's centre. Grid offsets are turned through the
    /// convergence so that "north" here is the north the sun is measured
    /// against.
    public func position(of pose: StonePose) -> SIMD3<Double> {
        position(of: pose.grid)
    }

    public func position(of point: OSGB.Point) -> SIMD3<Double> {
        let e = point.easting - centre.easting
        let n = point.northing - centre.northing
        let c = convergence.cosine, s = convergence.sine
        let east = e * c + n * s
        let north = n * c - e * s
        return SIMD3(east, 0, -north)
    }

    /// The bearing the stone's broad face looks along, true.
    ///
    /// Daw's yaw is the width axis measured anticlockwise from grid east. A
    /// `Stone`'s bearing is the compass direction of its local +Z, which lies
    /// 90° clockwise of the width axis — so the width axis has grid bearing
    /// 90° − yaw and the face looks along 180° − yaw. A box is the same box
    /// turned through 180°, so which of the two faces is "front" does not
    /// matter to anything downstream.
    public func bearing(of pose: StonePose) -> Angle {
        (Angle(degrees: 180 - pose.yawDegrees) + convergence).normalized
    }

    /// Kåsa's algebraic circle fit: least squares on
    /// x² + y² + ax + by + c = 0, which is linear in (a, b, c). Exact for
    /// points on a circle and biased only for very short arcs, which thirteen
    /// uprights round most of a ring are not.
    static func fitCircle(_ points: [SIMD2<Double>]) -> (centre: SIMD2<Double>, radius: Double) {
        let mean = points.reduce(SIMD2<Double>.zero, +) / Double(points.count)
        var m = [[Double]](repeating: [Double](repeating: 0, count: 4), count: 3)
        for p in points {
            let q = p - mean
            let row = [q.x, q.y, 1.0]
            let rhs = -(q.x * q.x + q.y * q.y)
            for i in 0..<3 {
                for j in 0..<3 { m[i][j] += row[i] * row[j] }
                m[i][3] += row[i] * rhs
            }
        }
        for i in 0..<3 {
            let pivot = m[i][i]
            for j in (i + 1)..<3 {
                let f = m[j][i] / pivot
                for k in 0..<4 { m[j][k] -= f * m[i][k] }
            }
        }
        var sol = [0.0, 0.0, 0.0]
        for i in stride(from: 2, through: 0, by: -1) {
            var acc = m[i][3]
            for k in (i + 1)..<3 { acc -= m[i][k] * sol[k] }
            sol[i] = acc / m[i][i]
        }
        let cx = -sol[0] / 2, cy = -sol[1] / 2
        let radius = (cx * cx + cy * cy - sol[2]).squareRoot()
        return (mean + SIMD2(cx, cy), radius)
    }
}

// MARK: - Provenance

/// Where a stone's placement or size comes from. Carried on every `Stone` so
/// that the difference between a surveyed stone and a reconstructed one is a
/// value a test can count, not a comment a reader may not find.
public enum StoneSource: Sendable, Hashable {
    /// Read off a cited plan. The accuracy class is the source's own grade.
    case surveyed(Citation, accuracyClass: String)
    /// From the cited dataset, which itself calls this row a placeholder.
    case provisional(Citation, accuracyClass: String)
    /// This app's own ring formula or shared constant — labelled, never
    /// blended with the above (invariant 8).
    case reconstruction

    public var citation: Citation? {
        switch self {
        case .surveyed(let c, _), .provisional(let c, _): c
        case .reconstruction: nil
        }
    }

    public var isFromPlan: Bool { citation != nil }
}

public struct StoneProvenance: Sendable, Hashable {
    public let position: StoneSource
    public let dimensions: StoneSource

    public init(position: StoneSource, dimensions: StoneSource) {
        self.position = position
        self.dimensions = dimensions
    }

    public static let reconstruction = StoneProvenance(position: .reconstruction,
                                                      dimensions: .reconstruction)
}
