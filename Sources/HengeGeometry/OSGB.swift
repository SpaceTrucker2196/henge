import Foundation
import HengeAstro

/// The British National Grid, as far as this app needs it.
///
/// The surveyed stone plan (`StonePoseTable`) is in OSGB eastings and
/// northings. The engine works in metres east and south of the sarsen circle's
/// centre with +Z pointing true south, so two things are needed here and
/// nothing else: a way to check that the grid coordinates describe the same
/// spot on the ground as `GeographicSite.stonehenge`, and the small angle
/// between grid north and true north at that spot, because the bearings the
/// astronomy is measured against are true and the plan's are grid.
///
/// Ordnance Survey, *A guide to coordinate systems in Great Britain*, gives
/// both. The forward transform is the same one `scripts/bake_terrain.py`
/// uses to fetch the terrain, ported so the two cannot drift apart unnoticed.
public enum OSGB {

    /// Eastings and northings on the National Grid, in metres.
    public struct Point: Sendable, Hashable {
        public let easting: Double
        public let northing: Double
        public init(easting: Double, northing: Double) {
            self.easting = easting
            self.northing = northing
        }
    }

    /// WGS84 latitude and longitude to OSGB36 National Grid.
    ///
    /// Geodetic to cartesian on GRS80, a seven-parameter Helmert shift onto
    /// the Airy 1830 datum, back to geodetic, then the Transverse Mercator.
    /// Good to a few metres nationally; the published Helmert parameters
    /// are what limits it, and a few metres is all the check needs.
    public static func nationalGrid(latitude: Angle, longitude: Angle) -> Point {
        // 1. WGS84 geodetic → cartesian.
        var a = 6378137.0, b = 6356752.3141
        var e2 = 1 - (b * b) / (a * a)
        var phi = latitude.radians, lam = longitude.radians
        var nu = a / (1 - e2 * sin(phi) * sin(phi)).squareRoot()
        let x = nu * cos(phi) * cos(lam)
        let y = nu * cos(phi) * sin(lam)
        let z = (1 - e2) * nu * sin(phi)

        // 2. Helmert, WGS84 → OSGB36 (OS published parameters).
        let tx = -446.448, ty = 125.157, tz = -542.060
        let s = 20.4894e-6
        let rx = Angle(degrees: -0.1502 / 3600).radians
        let ry = Angle(degrees: -0.2470 / 3600).radians
        let rz = Angle(degrees: -0.8421 / 3600).radians
        let x2 = tx + (1 + s) * x - rz * y + ry * z
        let y2 = ty + rz * x + (1 + s) * y - rx * z
        let z2 = tz - ry * x + rx * y + (1 + s) * z

        // 3. Cartesian → geodetic on Airy 1830.
        a = 6377563.396; b = 6356256.909
        e2 = 1 - (b * b) / (a * a)
        let p = (x2 * x2 + y2 * y2).squareRoot()
        phi = atan2(z2, p * (1 - e2))
        for _ in 0..<10 {
            nu = a / (1 - e2 * sin(phi) * sin(phi)).squareRoot()
            phi = atan2(z2 + e2 * nu * sin(phi), p)
        }
        lam = atan2(y2, x2)

        // 4. Transverse Mercator, National Grid constants.
        let F0 = 0.9996012717
        let phi0 = Angle(degrees: 49).radians, lam0 = Angle(degrees: -2).radians
        let N0 = -100000.0, E0 = 400000.0
        let n = (a - b) / (a + b)
        let sinp = sin(phi), cosp = cos(phi), tanp = tan(phi)
        nu = a * F0 / (1 - e2 * sinp * sinp).squareRoot()
        let rho = a * F0 * (1 - e2) / pow(1 - e2 * sinp * sinp, 1.5)
        let eta2 = nu / rho - 1
        let M = b * F0 * ((1 + n + 1.25 * n * n + 1.25 * n * n * n) * (phi - phi0)
                          - (3 * n + 3 * n * n + 2.625 * n * n * n) * sin(phi - phi0) * cos(phi + phi0)
                          + (1.875 * n * n + 1.875 * n * n * n) * sin(2 * (phi - phi0)) * cos(2 * (phi + phi0))
                          - (35.0 / 24.0) * n * n * n * sin(3 * (phi - phi0)) * cos(3 * (phi + phi0)))
        let I = M + N0
        let II = nu / 2 * sinp * cosp
        let III = nu / 24 * sinp * pow(cosp, 3) * (5 - tanp * tanp + 9 * eta2)
        let IIIA = nu / 720 * sinp * pow(cosp, 5) * (61 - 58 * tanp * tanp + pow(tanp, 4))
        let IV = nu * cosp
        let V = nu / 6 * pow(cosp, 3) * (nu / rho - tanp * tanp)
        let VI = nu / 120 * pow(cosp, 5)
            * (5 - 18 * tanp * tanp + pow(tanp, 4) + 14 * eta2 - 58 * tanp * tanp * eta2)
        let dl = lam - lam0
        let northing = I + II * dl * dl + III * pow(dl, 4) + IIIA * pow(dl, 6)
        let easting = E0 + IV * dl + V * pow(dl, 3) + VI * pow(dl, 5)
        return Point(easting: easting, northing: northing)
    }

    /// The angle from grid north to true north at a place, positive when grid
    /// north lies east of true north.
    ///
    /// On a Transverse Mercator the meridians converge on the pole, so east of
    /// the central meridian (2° W for the National Grid) true north leans a
    /// little west of the grid's straight-up. A true azimuth is the grid
    /// azimuth plus this angle. At Stonehenge it is about 0.14° — small, but
    /// the axis is argued about at a tenth of a degree, so it is applied
    /// rather than ignored.
    public static func gridConvergence(at site: GeographicSite) -> Angle {
        let centralMeridian = Angle(degrees: -2)
        return Angle(radians: (site.longitude - centralMeridian).radians * site.latitude.sine)
    }
}
