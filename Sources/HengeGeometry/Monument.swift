import Foundation
import simd
import HengeAstro

/// Henge's world axes, stated once so nothing has to guess.
///
/// Right-handed, metres, origin at the centre of the sarsen circle on the
/// ground plane: **+X east, +Y up, +Z south**. North is −Z. Azimuth is measured
/// from north through east, matching `HorizontalCoordinate`.
public enum WorldAxes {

    /// Convert a compass bearing to a horizontal direction vector.
    public static func direction(azimuth: Angle) -> SIMD3<Double> {
        SIMD3(azimuth.sine, 0, -azimuth.cosine)
    }

    /// Bearing of a horizontal direction, from north through east.
    public static func azimuth(of direction: SIMD3<Double>) -> Angle {
        Angle(radians: atan2(direction.x, -direction.z)).normalized
    }
}

/// The monument's measured facts.
///
/// Every figure here is survey data, not invention — MISSION.md invariant 8.
/// Where a number is contested or reconstructed, it says so.
public enum Monument {

    /// The principal axis, pointing north-east toward midsummer sunrise. The
    /// reciprocal (≈229.9°) marks midwinter sunset.
    ///
    /// Established. Note this is the *built* axis: what the sun actually does
    /// on the solstice is computed by `HengeAstro`, and the two agree closely
    /// in 2500 BC and less exactly today, because the obliquity has changed.
    public static let axisAzimuth = Angle(degrees: 49.9)

    /// Sarsen circle: 30 uprights on a ring of this diameter.
    public static let sarsenCircleDiameter = 33.0
    public static let sarsenUprightCount = 30
    public static let sarsenUprightHeight = 4.1
    public static let sarsenUprightWidth = 2.1
    public static let sarsenUprightThickness = 1.1
    public static let sarsenLintelHeight = 0.8

    /// Aubrey holes: 56 pits on an 87 m circle.
    public static let aubreyHoleCount = 56
    public static let aubreyCircleDiameter = 87.0

    /// The Heel Stone stands about 77 m out along the Avenue, on the axis.
    public static let heelStoneDistance = 77.0
    public static let heelStoneHeight = 4.7

    /// The five trilithons of the horseshoe, graded toward the Great Trilithon
    /// at the south-west apex.
    public enum Trilithon: Int, Sendable, CaseIterable {
        case northWestOuter = 0, northWestInner, great, southEastInner, southEastOuter

        /// Height of the uprights in metres.
        public var uprightHeight: Double {
            switch self {
            case .northWestOuter, .southEastOuter: 6.0
            case .northWestInner, .southEastInner: 6.5
            case .great: 7.3
            }
        }

        public var uprightWidth: Double { self == .great ? 2.4 : 2.1 }
        public var uprightThickness: Double { 1.1 }
        public var lintelHeight: Double { 1.0 }
        /// Clear gap between the pair of uprights.
        public var gap: Double { 0.35 }

        /// Petrie's numbers for the pair and their lintel.
        ///
        /// Flinders Petrie surveyed the monument in 1874–77 and numbered the
        /// stones clockwise from the axis; the scheme is still what the
        /// literature uses. The trilithon uprights run 51–60 clockwise with
        /// lintels 152–160, so citing "stone 56" means something to a reader
        /// and "great-upright-left" does not.
        public var numbers: (first: Int, second: Int, lintel: Int) {
            switch self {
            case .southEastOuter: (51, 52, 152)
            case .southEastInner: (53, 54, 154)
            case .great: (55, 56, 156)
            case .northWestInner: (57, 58, 158)
            case .northWestOuter: (59, 60, 160)
            }
        }

        public var name: String {
            switch self {
            case .great: "Great Trilithon"
            case .northWestInner: "North-west inner trilithon"
            case .northWestOuter: "North-west outer trilithon"
            case .southEastInner: "South-east inner trilithon"
            case .southEastOuter: "South-east outer trilithon"
            }
        }
    }

    /// Which era of the monument is being shown.
    ///
    /// These are distinct labelled states, never blended — invariant 8.
    public enum State: Sendable, CaseIterable {
        /// The completed Stage-2 monument, c. 2200 BC.
        case asItWas
        /// The ruin as surveyed today.
        case asItStands
    }
}

/// A stone as pure geometry: a box, warped.
///
/// No two are alike because each is seeded from its own identifier, so the
/// circle reads as quarried rock rather than a repeated asset — and it is
/// reproducible, which matters because the shadow tests depend on a stone
/// being in exactly the same place every run.
/// What a stone is made of. Drives its material in the renderer, and matters
/// to the archaeology: sarsen came from the Marlborough Downs some 25 km north,
/// the bluestones from the Preseli Hills in Wales, 250 km away.
public enum StoneMaterial: Sendable, Hashable {
    case sarsen
    case bluestone
    /// Chalk fill — the Aubrey holes, rendered as pale discs in the turf.
    case chalk
}

public struct Stone: Sendable, Hashable {

    public let id: String
    /// Centre of the base, in world metres.
    public let position: SIMD3<Double>
    public let height: Double
    public let width: Double
    public let thickness: Double
    /// Rotation about the vertical axis: the bearing the wide face looks along.
    public let bearing: Angle
    /// Tilt from vertical — the Heel Stone leans, and so do several others.
    public let lean: Angle
    /// Seed for the displacement noise that gives this stone its surface.
    public let seed: UInt64
    public let material: StoneMaterial

    public init(id: String, position: SIMD3<Double>, height: Double, width: Double,
                thickness: Double, bearing: Angle = .zero, lean: Angle = .zero,
                material: StoneMaterial = .sarsen,
                seed: UInt64? = nil) {
        self.id = id
        self.position = position
        self.height = height
        self.width = width
        self.thickness = thickness
        self.bearing = bearing
        self.lean = lean
        self.material = material
        self.seed = seed ?? Stone.deterministicSeed(for: id)
    }

    /// Stable across runs and machines — `hashValue` is not.
    static func deterministicSeed(for id: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    /// Local space → world. **The** definition of where a stone's material is.
    ///
    /// Local axes: +X across the width, +Y up from the base, +Z through the
    /// thickness. Applied in order: lean about local X, then bearing about
    /// vertical, then translate.
    ///
    /// It lives here, once, because the mesh builder and the shadow solver must
    /// agree exactly. They did not, and the disagreement was a rotation written
    /// out twice with a sign difference — a matrix of determinant −1, which is a
    /// mirror rather than a turn. It flipped the winding of every triangle in
    /// every stone.
    public func toWorld(_ local: SIMD3<Double>) -> SIMD3<Double> {
        let cosL = cos(lean.radians), sinL = sin(lean.radians)
        let leaned = SIMD3<Double>(local.x,
                                   local.y * cosL - local.z * sinL,
                                   local.y * sinL + local.z * cosL)

        // Basis stated outright rather than written as a rotation matrix, so
        // that `bearing` means exactly what it says: **local +Z points along
        // the compass bearing**, and local +X lies 90° to its left. Writing it
        // as an angle rotation twice already produced one mirror and one
        // 10° misalignment that survived a passing test suite because nothing
        // pinned the direction a stone actually faces.
        //
        // Right-handed: X × Y = Z.
        let cosB = bearing.cosine, sinB = bearing.sine
        let across = SIMD3<Double>(-cosB, 0, -sinB)   // local +X
        let up = SIMD3<Double>(0, 1, 0)               // local +Y
        let facing = SIMD3<Double>(sinB, 0, -cosB)    // local +Z
        let turned = across * leaned.x + up * leaned.y + facing * leaned.z
        return turned + position
    }

    /// Rotate a direction without translating it — for normals.
    public func directionToWorld(_ local: SIMD3<Double>) -> SIMD3<Double> {
        toWorld(local) - position
    }

    /// The eight corners of the stone's bounding box in world space. The
    /// analytic shadow is cast from these.
    public var corners: [SIMD3<Double>] {
        let hw = width / 2, ht = thickness / 2
        var result: [SIMD3<Double>] = []
        for y in [0.0, height] {
            for x in [-hw, hw] {
                for z in [-ht, ht] {
                    result.append(toWorld(SIMD3(x, y, z)))
                }
            }
        }
        return result
    }

    /// Centre of the stone's top face — the point whose shadow is the tip.
    public var apex: SIMD3<Double> {
        toWorld(SIMD3(0, height, 0))
    }
}
