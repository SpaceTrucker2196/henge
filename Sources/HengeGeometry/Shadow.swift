import Foundation
import simd
import HengeAstro

/// Where the stones throw their shadows — solved on paper, not on the GPU.
///
/// This module exists so the renderer can be *checked*. MISSION.md invariant 2
/// says visual plausibility is never a substitute for agreement, and agreement
/// needs something to agree with: these functions are that something. They use
/// no Metal and no floating-point trickery, so the same numbers come out on
/// every machine and can be verified by hand with a protractor.
public enum ShadowSolver {

    /// Project a point onto the ground plane (y = 0) along the sun's rays.
    ///
    /// `sunDirection` points *toward* the sun. Returns nil when the sun is at
    /// or below the horizon, because the shadow is then unbounded — a fact the
    /// renderer must also respect rather than drawing a shadow to infinity.
    public static func groundShadow(of point: SIMD3<Double>,
                                    sunDirection: SIMD3<Double>) -> SIMD3<Double>? {
        guard sunDirection.y > 1e-9 else { return nil }
        guard point.y > 0 else { return point }
        let t = point.y / sunDirection.y
        return point - sunDirection * t
    }

    /// Convenience: cast from a horizontal coordinate rather than a vector.
    public static func groundShadow(of point: SIMD3<Double>,
                                    sun: HorizontalCoordinate) -> SIMD3<Double>? {
        let v = sun.unitVector
        return groundShadow(of: point, sunDirection: SIMD3(v.x, v.y, v.z))
    }

    /// The shadow of a stone's apex — the tip that sweeps the ground like the
    /// gnomon of a sundial, and the thing the calendar is actually read from.
    public static func shadowTip(of stone: Stone,
                                 sun: HorizontalCoordinate) -> SIMD3<Double>? {
        groundShadow(of: stone.apex, sun: sun)
    }

    /// The full ground shadow of a stone: its eight corners projected, then
    /// reduced to the outline. Convex, because a box is.
    public static func shadowOutline(of stone: Stone,
                                     sun: HorizontalCoordinate) -> [SIMD2<Double>] {
        let v = sun.unitVector
        let direction = SIMD3(v.x, v.y, v.z)
        guard direction.y > 1e-9 else { return [] }

        let projected = stone.corners.compactMap { corner -> SIMD2<Double>? in
            guard let p = groundShadow(of: corner, sunDirection: direction) else { return nil }
            return SIMD2(p.x, p.z)
        }
        return convexHull(projected)
    }

    /// Length of a vertical pole's shadow. Kept as its own function because it
    /// is the case a reader can check in their head: at 45° elevation the
    /// shadow equals the height.
    public static func shadowLength(height: Double, sunAltitude: Angle) -> Double? {
        guard sunAltitude.radians > 1e-9 else { return nil }
        return height / sunAltitude.tangent
    }

    /// The bearing a shadow points along: directly away from the sun.
    public static func shadowBearing(sunAzimuth: Angle) -> Angle {
        (sunAzimuth + Angle(degrees: 180)).normalized
    }

    /// Andrew's monotone chain. Counter-clockwise, no repeated endpoint.
    static func convexHull(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
        guard points.count > 2 else { return points }
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }

        func cross(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }

        var lower: [SIMD2<Double>] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }

        var upper: [SIMD2<Double>] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }

        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }
}
