import Foundation

/// The Milky Way as a picture of the sky, and where on that picture a
/// direction falls.
///
/// The band is not drawn from the catalogue — 8,870 stars cannot make it;
/// it is the light of the billion faint ones — so it rides in as NASA's
/// map of the Gaia sky (Deep Star Maps 2020, SVS entry 4851). What lives
/// here is the arithmetic that keeps the picture honest: which pixel a view
/// ray lands on, and the rotation that carries a frame of date back to the
/// J2000 frame the map is drawn in, so the band precesses with the stars it
/// is made of rather than being pasted to the dome.
public enum MilkyWay {

    /// Where an equatorial J2000 unit vector falls on the map.
    ///
    /// The map is plate carrée in ICRF/J2000 right ascension and declination,
    /// centred on 0h with right ascension increasing to the *left* — the
    /// convention for a map meant to be seen from inside the sphere, and the
    /// one the SVS page states. u runs 0…1 across, v 0 at the north pole to
    /// 1 at the south. The galactic centre (17h46m, −29°) therefore lands
    /// lower right of centre, which is where the picture shows the bulge.
    public static func textureCoordinate(direction d: SIMD3<Double>) -> SIMD2<Double> {
        let rightAscension = atan2(d.y, d.x)
        let declination = asin(min(1, max(-1, d.z)))
        var u = 0.5 - rightAscension / (2 * .pi)
        u -= floor(u)
        return SIMD2(u, 0.5 - declination / .pi)
    }

    /// Rows of the rotation from the equatorial frame of date back to J2000.
    ///
    /// Built without new mathematics: the three J2000 axes are precessed to
    /// the frame of date by the same `StarField.equatorialOfDate` every star
    /// goes through. Their images are the columns of J2000 → date, and so
    /// the rows of date → J2000 — dotting a vector of date with each row
    /// gives its J2000 components. `StarFieldTests` pins that precession to
    /// Thuban's pole of 2800 BC; `MilkyWayTests` pins this inverse to the
    /// same star from the other side.
    public static func j2000Rows(at tt: JulianDay)
        -> (x: SIMD3<Double>, y: SIMD3<Double>, z: SIMD3<Double>) {
        func dated(_ rightAscension: Double, _ declination: Double) -> SIMD3<Double> {
            let moved = StarField.equatorialOfDate(
                rightAscension: Angle(degrees: rightAscension),
                declination: Angle(degrees: declination), at: tt)
            return StarField.unitVector(rightAscension: moved.rightAscension,
                                        declination: moved.declination)
        }
        return (dated(0, 0), dated(90, 0), dated(0, 90))
    }

    /// The magnitude the band comes out with. Its surface brightness is
    /// nothing like a star's; this is the magnitude of the *stars that
    /// appear alongside it* — the fourth, once the sun is past nautical
    /// dark. An artistic reading of a real progression, labelled as one, and
    /// run through the same twilight fade as every star so the two can never
    /// disagree about when night is.
    public static let twilightMagnitude = 4.0

    /// How visible the band is against the twilight, 0…1.
    public static func visibility(sunAltitude: Angle) -> Double {
        StarField.visibility(sunAltitude: sunAltitude, magnitude: twilightMagnitude)
    }
}
