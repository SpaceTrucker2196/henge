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

    public init(id: String, position: SIMD3<Double>, height: Double, width: Double,
                thickness: Double, bearing: Angle = .zero, lean: Angle = .zero,
                seed: UInt64? = nil) {
        self.id = id
        self.position = position
        self.height = height
        self.width = width
        self.thickness = thickness
        self.bearing = bearing
        self.lean = lean
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

    /// The eight corners of the stone's bounding box in world space, base
    /// first then top. The analytic shadow is cast from these.
    public var corners: [SIMD3<Double>] {
        let halfWidth = width / 2
        let halfThickness = thickness / 2
        let cosB = bearing.cosine, sinB = bearing.sine

        // Lean tips the stone toward its bearing.
        let topOffset = SIMD3<Double>(
            sin(lean.radians) * sinB * height,
            cos(lean.radians) * height,
            -sin(lean.radians) * cosB * height
        )

        var result: [SIMD3<Double>] = []
        for level in 0...1 {
            for dw in [-halfWidth, halfWidth] {
                for dt in [-halfThickness, halfThickness] {
                    // Wide face runs perpendicular to the bearing.
                    let offset = SIMD3<Double>(
                        dw * cosB + dt * sinB,
                        0,
                        dw * sinB - dt * cosB
                    )
                    let base = position + offset
                    result.append(level == 0 ? base : base + topOffset)
                }
            }
        }
        return result
    }

    /// Centre of the stone's top face — the point whose shadow is the tip.
    public var apex: SIMD3<Double> {
        SIMD3(
            position.x + sin(lean.radians) * bearing.sine * height,
            position.y + cos(lean.radians) * height,
            position.z - sin(lean.radians) * bearing.cosine * height
        )
    }
}
