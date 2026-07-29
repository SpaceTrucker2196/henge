import Foundation

/// The five planets an unaided eye can find — the wanderers the stars'
/// steadiness exists to contrast with.
///
/// Positions come from the truncated VSOP87D series in `VSOP87Tables.swift`
/// (provenance there and in SECURITY.md): heliocentric spherical variables
/// against the ecliptic and equinox of date, differenced with the Earth's
/// own to give geocentric places. Light-time and aberration are neglected —
/// together they move a naked-eye planet by under an arcminute, a fraction
/// of the dot the renderer draws — and stated here rather than hidden.
public enum Planet: String, Sendable, CaseIterable, Identifiable {
    case mercury = "Mercury"
    case venus = "Venus"
    case mars = "Mars"
    case jupiter = "Jupiter"
    case saturn = "Saturn"

    public var id: String { rawValue }
    public var name: String { rawValue }

    var table: VSOPBody {
        switch self {
        case .mercury: vsop87Mercury
        case .venus: vsop87Venus
        case .mars: vsop87Mars
        case .jupiter: vsop87Jupiter
        case .saturn: vsop87Saturn
        }
    }

    /// A dot's worth of colour, an artistic reading of how each planet
    /// actually looks to the eye: Venus white, Mars the famous ember,
    /// Jupiter cream, Saturn old gold, Mercury a dusty warm grey.
    public var colour: SIMD3<Float> {
        switch self {
        case .mercury: SIMD3(0.85, 0.80, 0.72)
        case .venus: SIMD3(1.00, 0.97, 0.90)
        case .mars: SIMD3(1.00, 0.55, 0.35)
        case .jupiter: SIMD3(0.96, 0.91, 0.78)
        case .saturn: SIMD3(0.95, 0.87, 0.62)
        }
    }
}

public enum PlanetEphemeris {

    /// Evaluate one VSOP87 spherical variable at a moment.
    ///
    /// `T` is millennia of TT from J2000 — VSOP87's own clock — and each
    /// power's series is a plain sum of cosines.
    static func evaluate(_ series: [[VSOPTerm]], at t: Double) -> Double {
        var total = 0.0
        var power = 1.0
        for group in series {
            var sum = 0.0
            for term in group {
                sum += term.a * cos(term.b + term.c * t)
            }
            total += sum * power
            power *= t
        }
        return total
    }

    /// Heliocentric ecliptic-of-date longitude, latitude and radius.
    static func heliocentric(_ body: VSOPBody, at tt: JulianDay)
        -> (longitude: Double, latitude: Double, radius: Double) {
        let t = (tt.value - 2_451_545.0) / 365_250.0
        return (evaluate(body.longitude, at: t),
                evaluate(body.latitude, at: t),
                evaluate(body.radius, at: t))
    }

    /// A planet's apparent place and brightness.
    public struct Apparent: Sendable {
        public let rightAscension: Angle
        public let declination: Angle
        /// Distance from the Earth, astronomical units.
        public let distance: Double
        /// Visual magnitude.
        public let magnitude: Double
    }

    /// The apparent geocentric place, against the equator and equinox of
    /// date — the same frame the stars are handed to the renderer in.
    public static func apparent(_ planet: Planet, at tt: JulianDay) -> Apparent {
        let p = heliocentric(planet.table, at: tt)
        let e = heliocentric(vsop87Earth, at: tt)

        // Heliocentric rectangular, ecliptic of date.
        func rect(_ s: (longitude: Double, latitude: Double, radius: Double))
            -> (x: Double, y: Double, z: Double) {
            (s.radius * cos(s.latitude) * cos(s.longitude),
             s.radius * cos(s.latitude) * sin(s.longitude),
             s.radius * sin(s.latitude))
        }
        let pr = rect(p), er = rect(e)
        let gx = pr.x - er.x, gy = pr.y - er.y, gz = pr.z - er.z
        let distance = (gx * gx + gy * gy + gz * gz).squareRoot()

        let longitude = atan2(gy, gx)
        let latitude = asin(gz / distance)

        // Ecliptic → equatorial, obliquity of date.
        let obliquity = EarthOrientation.meanObliquity(at: tt)
        let ra = atan2(sin(longitude) * obliquity.cosine
                           - tan(latitude) * obliquity.sine,
                       cos(longitude))
        let dec = asin(min(1, max(-1, sin(latitude) * obliquity.cosine
                                      + cos(latitude) * obliquity.sine * sin(longitude))))

        // Phase angle from the triangle sun–planet–earth.
        let cosPhase = (p.radius * p.radius + distance * distance
                        - e.radius * e.radius) / (2 * p.radius * distance)
        let phase = acos(min(1, max(-1, cosPhase))) * 180 / .pi

        return Apparent(rightAscension: Angle(radians: ra).normalized,
                        declination: Angle(radians: dec),
                        distance: distance,
                        magnitude: magnitude(planet, sunDistance: p.radius,
                                             earthDistance: distance,
                                             phaseDegrees: phase))
    }

    /// Visual magnitude, by the Astronomical Almanac's 1984-era formulae as
    /// given in Meeus ch. 41. Saturn's ring term is omitted — it needs the
    /// ring-plane geometry and moves the answer by up to a magnitude; the
    /// dot errs dim, which for a calendar is the honest side to err on.
    static func magnitude(_ planet: Planet, sunDistance r: Double,
                          earthDistance d: Double, phaseDegrees i: Double) -> Double {
        let base = 5 * log10(r * d)
        switch planet {
        case .mercury:
            return -0.42 + base + 0.0380 * i - 0.000273 * i * i
                + 0.000002 * i * i * i
        case .venus:
            return -4.40 + base + 0.0009 * i + 0.000239 * i * i
                - 0.00000065 * i * i * i
        case .mars:
            return -1.52 + base + 0.016 * i
        case .jupiter:
            return -9.40 + base + 0.005 * i
        case .saturn:
            return -8.88 + base
        }
    }

    /// Every naked-eye planet's apparent place at a moment — the renderer's
    /// and the label layer's one call.
    public static func all(at tt: JulianDay) -> [(planet: Planet, place: Apparent)] {
        Planet.allCases.map { ($0, apparent($0, at: tt)) }
    }
}
