import XCTest
@testable import HengeAstro

/// The planets against published values — Meeus's worked examples for the
/// numbers, and the oldest facts in observational astronomy for the shape
/// of the whole pipeline.
final class PlanetTests: XCTestCase {

    /// Meeus, example 32.a: Venus's heliocentric place at 1992 December 20,
    /// 0h TT (JDE 2448976.5): L = 26°.11428, B = −2°.62070, R = 0.724603.
    func testVenusHeliocentricAgainstMeeus() {
        let tt = JulianDay(2_448_976.5)
        let venus = PlanetEphemeris.heliocentric(vsop87Venus, at: tt)
        // The series returns an unwound angle — Venus has gone round many
        // times since J2000's epoch phase — so normalise before comparing.
        XCTAssertEqual(Angle(radians: venus.longitude).normalized.degrees,
                       26.11428, accuracy: 0.005,
                       "heliocentric longitude drifted past the truncation budget")
        XCTAssertEqual(venus.latitude * 180 / .pi, -2.62070, accuracy: 0.005)
        XCTAssertEqual(venus.radius, 0.724603, accuracy: 0.00005)
    }

    /// Meeus, example 33.a, same instant: Venus's apparent geocentric place
    /// is α = 21h04m41s.5, δ = −18°53′17″. This model omits light-time and
    /// aberration (about an arcminute together), so the tolerance says so.
    func testVenusApparentAgainstMeeus() {
        let place = PlanetEphemeris.apparent(.venus, at: JulianDay(2_448_976.5))
        let ra = (21.0 + 4.0 / 60 + 41.5 / 3600) * 15
        let dec = -(18.0 + 53.0 / 60 + 17.0 / 3600)
        XCTAssertEqual(place.rightAscension.degrees, ra, accuracy: 0.05,
                       "apparent right ascension off by more than the stated "
                       + "light-time/aberration neglect explains")
        XCTAssertEqual(place.declination.degrees, dec, accuracy: 0.05)
        XCTAssertEqual(place.distance, 0.9109, accuracy: 0.001,
                       "Meeus gives Δ = 0.91095 au")
    }

    /// The oldest facts there are: Mercury never strays more than about
    /// 28°.5 from the sun, Venus about 47°.8. Sampled daily across two
    /// decades, this exercises every stage of the geocentric pipeline —
    /// a sign error anywhere sends an inner planet to midnight.
    func testTheInnerPlanetsKeepToTheSunsSide() {
        var maxMercury = 0.0
        var maxVenus = 0.0
        for day in 0..<7305 {
            let tt = JulianDay(2_451_545.0 + Double(day))
            let sun = Sun.position(at: tt)
            for (planet, bound) in [(Planet.mercury, 28.9), (.venus, 48.3)] {
                let place = PlanetEphemeris.apparent(planet, at: tt)
                // Elongation on the sphere, not just in longitude.
                let sunEquatorial = sun.apparentLongitude
                _ = sunEquatorial
                let separation = angularSeparation(
                    a: (place.rightAscension, place.declination),
                    b: equatorialOfSun(at: tt))
                if planet == .mercury { maxMercury = max(maxMercury, separation) }
                else { maxVenus = max(maxVenus, separation) }
                XCTAssertLessThan(separation, bound,
                                  "\(planet.name) stood \(separation)° from the "
                                  + "sun — beyond its greatest possible elongation")
            }
        }
        // And the maxima must be *reached*, or the test is measuring a
        // planet glued to the sun by some other bug.
        XCTAssertGreaterThan(maxMercury, 17.9,
                             "Mercury's greatest elongation never exceeded "
                             + "\(maxMercury)° in twenty years — too tame to be real")
        XCTAssertGreaterThan(maxVenus, 45.0,
                             "Venus reached only \(maxVenus)°")
    }

    /// Magnitude sanity per planet over a sampled decade, against the
    /// almanac ranges everyone can look up. Saturn's stated span allows for
    /// the omitted ring term — the model errs dim.
    func testMagnitudesStayInTheirAlmanacRanges() {
        var spans: [Planet: (min: Double, max: Double)] = [:]
        for day in stride(from: 0, to: 3650, by: 5) {
            let tt = JulianDay(2_451_545.0 + Double(day))
            for (planet, place) in PlanetEphemeris.all(at: tt) {
                let old = spans[planet] ?? (10, -10)
                spans[planet] = (min(old.min, place.magnitude),
                                 max(old.max, place.magnitude))
            }
        }
        let limits: [Planet: (Double, Double)] = [
            .mercury: (-2.7, 7.5),
            .venus: (-5.0, -3.3),
            .mars: (-3.1, 2.1),
            .jupiter: (-3.0, -1.5),
            .saturn: (-0.8, 1.6)
        ]
        for (planet, span) in spans {
            let limit = limits[planet]!
            XCTAssertGreaterThan(span.min, limit.0,
                                 "\(planet.name) reached \(span.min) — brighter "
                                 + "than the almanac allows")
            XCTAssertLessThan(span.max, limit.1,
                              "\(planet.name) fell to \(span.max) — dimmer than "
                              + "the almanac allows")
        }
    }

    // ── helpers ─────────────────────────────────────────────────────────────

    /// The sun's apparent equatorial place, from the machinery the whole
    /// app already trusts.
    private func equatorialOfSun(at tt: JulianDay) -> (Angle, Angle) {
        let position = Sun.position(at: tt)
        let obliquity = EarthOrientation.meanObliquity(at: tt)
        let l = position.apparentLongitude
        let ra = Angle(radians: atan2(l.sine * obliquity.cosine, l.cosine)).normalized
        let dec = Angle(radians: asin(min(1, max(-1, obliquity.sine * l.sine))))
        return (ra, dec)
    }

    private func angularSeparation(a: (Angle, Angle), b: (Angle, Angle)) -> Double {
        let cosSep = a.1.sine * b.1.sine + a.1.cosine * b.1.cosine * (a.0 - b.0).cosine
        return acos(min(1, max(-1, cosSep))) * 180 / .pi
    }
}
