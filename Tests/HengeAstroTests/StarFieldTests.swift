import XCTest
@testable import HengeAstro

/// The star machinery against facts a reader can check without this code:
/// navigation classics for the frame, published proper motion for the moving
/// stars, and the one datum the whole deep-time mode leans on — Thuban held
/// the pole when the sarsens went up.
final class StarFieldTests: XCTestCase {

    private let stonehenge = GeographicSite.stonehenge

    // ── the frame ───────────────────────────────────────────────────────────

    func testThePoleStandsAtTheLatitude() {
        // Any sidereal time — the pole does not turn.
        for lst in [0.0, 90.0, 213.7] {
            let rows = StarField.worldRows(siderealTime: Angle(degrees: lst),
                                           site: stonehenge)
            let pole = SIMD3<Double>(0, 0, 1)
            let up = rows.up.x * pole.x + rows.up.y * pole.y + rows.up.z * pole.z
            // Navigation's oldest fact: the pole's altitude is the latitude.
            XCTAssertEqual(asin(up) * 180 / .pi, stonehenge.latitude.degrees,
                           accuracy: 1e-9)
        }
    }

    func testAnEquatorStarCrossesTheMeridianDueSouth() {
        // A star on the celestial equator, on the meridian: altitude is
        // 90° − latitude, bearing due south. The star is on the meridian
        // when its RA equals the local sidereal angle.
        let lst = Angle(degrees: 100)
        let alpha = (lst + stonehenge.longitude).normalized
        let rows = StarField.worldRows(siderealTime: lst, site: stonehenge)
        let star = StarField.unitVector(rightAscension: alpha,
                                        declination: .zero)
        let east = simdDot(rows.east, star)
        let up = simdDot(rows.up, star)
        let south = simdDot(rows.south, star)
        XCTAssertEqual(east, 0, accuracy: 1e-9)
        XCTAssertEqual(asin(up) * 180 / .pi, 90 - stonehenge.latitude.degrees,
                       accuracy: 1e-9)
        XCTAssertGreaterThan(south, 0, "meridian transit is due south from here")
    }

    func testAStarNinetyDegreesPastTheMeridianStandsDueEast() {
        let lst = Angle(degrees: 40)
        let alpha = (lst + stonehenge.longitude + Angle(degrees: 90)).normalized
        let rows = StarField.worldRows(siderealTime: lst, site: stonehenge)
        let star = StarField.unitVector(rightAscension: alpha, declination: .zero)
        XCTAssertEqual(simdDot(rows.east, star), 1, accuracy: 1e-9)
        XCTAssertEqual(simdDot(rows.up, star), 0, accuracy: 1e-9,
                       "a rising equator star crosses the east point exactly")
    }

    // ── proper motion ───────────────────────────────────────────────────────

    func testArcturusCoversItsPublishedGroundInDeepTime() {
        // Hipparcos: μα★ = −1093.45, μδ = −1999.40 mas/yr — a total rate of
        // √(1093.45² + 1999.40²) ≈ 2278.8 mas/yr, the fastest of the bright
        // stars. Over the 4,491 years from the catalogue epoch back to
        // −2500 that is 2278.8 × 4491 / 3.6e6 ≈ 2.84° — arithmetic a reader
        // can redo on paper.
        let j2000Ra = Angle(degrees: 213.91811)
        let j2000Dec = Angle(degrees: 19.18727)
        let ancient = JulianDay(2_448_349.0625 - 4491 * 365.25)
        let moved = StarField.properMotionApplied(rightAscension: j2000Ra,
                                                  declination: j2000Dec,
                                                  pmRACosDec: -1093.45,
                                                  pmDeclination: -1999.40,
                                                  at: ancient)
        let separation = angularSeparation(a: (j2000Ra, j2000Dec),
                                           b: (moved.rightAscension, moved.declination))
        XCTAssertEqual(separation, 2.84, accuracy: 0.05,
                       "Arcturus moved \(separation)° against a published-rate "
                       + "expectation of 2.84°")
    }

    func testAMotionlessStarDoesNotMove() {
        let moved = StarField.properMotionApplied(rightAscension: Angle(degrees: 50),
                                                  declination: Angle(degrees: -20),
                                                  pmRACosDec: 0, pmDeclination: 0,
                                                  at: JulianDay(1_000_000))
        XCTAssertEqual(moved.rightAscension.degrees, 50, accuracy: 1e-12)
        XCTAssertEqual(moved.declination.degrees, -20, accuracy: 1e-12)
    }

    // ── precession ──────────────────────────────────────────────────────────

    func testThubanHeldThePoleWhenTheSarsensWentUp() {
        // The load-bearing fact of the deep-time sky, from the precession
        // literature rather than from this codebase: around 2800 BC Thuban
        // stood within about a tenth of a degree of the celestial pole. The
        // in-repo series is fitted to the modern era and run 4,800 years out
        // of range, which costs about half a degree here (measured: 89.43°).
        // The claim this pins is "Thuban is the pole star of that sky" —
        // thirty times nearer the pole than any rival — not a modern
        // ephemeris, and the tolerance says so.
        let year2800BC = JulianDay(2_451_545.0 - 4799 * 365.25)
        let dated = StarField.equatorialOfDate(rightAscension: Angle(degrees: 211.0976),
                                               declination: Angle(degrees: 64.3758),
                                               at: year2800BC)
        XCTAssertGreaterThan(dated.declination.degrees, 89.3,
                             "Thuban's declination of date in 2800 BC is "
                             + "\(dated.declination.degrees)° — it should all "
                             + "but sit on the pole")
    }

    func testPrecessionVanishesAtJ2000() {
        let dated = StarField.equatorialOfDate(rightAscension: Angle(degrees: 279.2347),
                                               declination: Angle(degrees: 38.7837),
                                               at: JulianDay(2_451_545.0))
        XCTAssertEqual(dated.rightAscension.degrees, 279.2347, accuracy: 0.01)
        XCTAssertEqual(dated.declination.degrees, 38.7837, accuracy: 0.01)
    }

    // ── the moon's disc ─────────────────────────────────────────────────────

    func testTheMoonHidesOnlyTheStarsItStandsOn() {
        // A quarter-degree moon (radius ~0.0044 rad) high in the east.
        let moon = SIMD3<Double>(0.7, 0.5, -0.5) / (0.7 * 0.7 + 0.5 * 0.5 + 0.25).squareRoot()
        let radius = 0.0044

        XCTAssertTrue(StarField.hiddenByMoon(starDirection: moon,
                                             moonDirection: moon,
                                             moonAngularRadius: radius),
                      "a star dead behind the disc is hidden")
        // A star one degree away is four radii clear of the disc and its glow.
        let clear = rotatedSlightly(moon, byDegrees: 1.0)
        XCTAssertFalse(StarField.hiddenByMoon(starDirection: clear,
                                              moonDirection: moon,
                                              moonAngularRadius: radius))
        // A set moon hides nothing at all.
        XCTAssertFalse(StarField.hiddenByMoon(starDirection: moon,
                                              moonDirection: SIMD3(0.7, -0.5, -0.5),
                                              moonAngularRadius: radius))
    }

    private func rotatedSlightly(_ v: SIMD3<Double>, byDegrees degrees: Double)
        -> SIMD3<Double> {
        // Rotate about the z axis — any axis not parallel to v will do.
        let r = degrees * .pi / 180
        let rotated = SIMD3(v.x * cos(r) - v.y * sin(r),
                            v.x * sin(r) + v.y * cos(r),
                            v.z)
        let length = (rotated.x * rotated.x + rotated.y * rotated.y
                      + rotated.z * rotated.z).squareRoot()
        return rotated / length
    }

    // ── visibility ──────────────────────────────────────────────────────────

    func testBrightStarsComeOutFirst() {
        let dusk = Angle(degrees: -5)
        XCTAssertGreaterThan(StarField.visibility(sunAltitude: dusk, magnitude: -1.4),
                             StarField.visibility(sunAltitude: dusk, magnitude: 3.0),
                             "Sirius must beat a third-magnitude star to the dusk")
        XCTAssertEqual(StarField.visibility(sunAltitude: Angle(degrees: 10),
                                            magnitude: -1.4), 0,
                       "no star survives a ten-degree sun")
        XCTAssertEqual(StarField.visibility(sunAltitude: Angle(degrees: -20),
                                            magnitude: 6.0), 1,
                       "astronomical darkness shows the whole catalogue")
    }

    // ── helpers ─────────────────────────────────────────────────────────────

    private func simdDot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    private func angularSeparation(a: (Angle, Angle), b: (Angle, Angle)) -> Double {
        let cosSep = a.1.sine * b.1.sine
            + a.1.cosine * b.1.cosine * (a.0 - b.0).cosine
        return acos(min(1, max(-1, cosSep))) * 180 / .pi
    }
}
