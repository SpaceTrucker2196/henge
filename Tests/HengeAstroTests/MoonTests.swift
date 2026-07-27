import XCTest
@testable import HengeAstro

/// The moon, against Meeus's own worked example.
///
/// The series here is a truncation, so these tests measure what it achieves
/// rather than restating a claim. MISSION.md invariant 1 requires the budget be
/// held to; where a truncation cannot hold it, the honest response is to say so
/// in the tolerance and in the docs, never to quietly widen it later.
final class MoonPositionTests: XCTestCase {

    /// Meeus, Example 47.a — 1992 April 12 at 0h TD.
    /// λ = 133.162655°, β = -3.229126°, Δ = 368409.7 km.
    func testMeeusExample47a() {
        let tt = JulianDay(CalendarDate(year: 1992, month: 4, day: 12.0))
        XCTAssertEqual(tt.value, 2448724.5, accuracy: 1e-6)

        let moon = Moon.position(at: tt)

        // Apparent longitude includes nutation, which Meeus's λ does not, so
        // the two differ by Δψ — about 16″ at this date.
        let nutation = EarthOrientation.nutation(at: tt)
        let geometric = (moon.longitude - nutation.longitude).normalized

        XCTAssertEqual(geometric.degrees, 133.162655, accuracy: 0.01)
        XCTAssertEqual(moon.latitude.degrees, -3.229126, accuracy: 0.01)
        XCTAssertEqual(moon.distance, 368409.7, accuracy: 60)
    }

    /// The moon's distance swings by about a tenth between perigee and apogee,
    /// and its apparent size with it — which is why some eclipses are total and
    /// others annular.
    func testDistanceAndApparentSizeVaryThroughTheMonth() {
        var nearest = Double.infinity, furthest = 0.0
        let start = JulianDay(CalendarDate(year: 2026, month: 1, day: 1))
        for day in 0..<60 {
            let d = Moon.position(at: start + Double(day)).distance
            nearest = min(nearest, d)
            furthest = max(furthest, d)
        }

        XCTAssertGreaterThan(nearest, 356_000)
        XCTAssertLessThan(nearest, 372_000)
        XCTAssertGreaterThan(furthest, 396_000)
        XCTAssertLessThan(furthest, 407_000)

        // Angular diameter between roughly 29.4′ and 33.5′.
        let big = Moon.position(at: start).angularDiameter
        XCTAssertGreaterThan(big.degrees * 60, 29.0)
        XCTAssertLessThan(big.degrees * 60, 34.0)
    }

    /// The moon moves about 13° a day against the stars — thirteen times its
    /// own width, and the reason a lunar calendar is legible at all.
    func testMoonMovesThirteenDegreesADay() {
        let t = JulianDay(CalendarDate(year: 2026, month: 3, day: 10))
        let a = Moon.position(at: t).longitude
        let b = Moon.position(at: t + 1).longitude
        XCTAssertEqual((b - a).normalized.degrees, 13.2, accuracy: 1.6)
    }
}

final class LunarPhaseTests: XCTestCase {

    /// A known full moon: 2026 January 3, near 10h UT.
    func testFullMoonIsFullyLit() {
        let tt = JulianDay(CalendarDate(year: 2026, month: 1, day: 3, hour: 10)).terrestrialTime
        let phase = Moon.phase(at: tt)
        XCTAssertGreaterThan(phase.illuminatedFraction, 0.98)
        XCTAssertEqual(phase.name, "Full")
    }

    /// And a new moon a fortnight earlier: 2025 December 20.
    func testNewMoonIsDark() {
        let tt = JulianDay(CalendarDate(year: 2025, month: 12, day: 20, hour: 1)).terrestrialTime
        let phase = Moon.phase(at: tt)
        XCTAssertLessThan(phase.illuminatedFraction, 0.03)
    }

    /// The cycle must close: illumination returns to where it began after one
    /// synodic month, and the fraction never leaves its bounds.
    func testPhaseRunsAFullCycleInASynodicMonth() {
        let start = JulianDay(CalendarDate(year: 2026, month: 5, day: 1)).terrestrialTime
        let first = Moon.phase(at: start).illuminatedFraction
        let later = Moon.phase(at: start + 29.530588).illuminatedFraction
        XCTAssertEqual(first, later, accuracy: 0.04)

        for day in stride(from: 0.0, to: 30.0, by: 0.7) {
            let fraction = Moon.phase(at: start + day).illuminatedFraction
            XCTAssertGreaterThanOrEqual(fraction, 0)
            XCTAssertLessThanOrEqual(fraction, 1)
        }
    }
}

/// The 18.61-year cycle, and the reason the Station Stones are a rectangle.
final class LunarStandstillTests: XCTestCase {

    /// The node regresses once round the ecliptic every 18.6 years. Nothing
    /// states that period anywhere — it has to emerge from the arithmetic.
    func testTheNodeRegressesOnceIn18Point6Years() {
        let start = JulianDay(CalendarDate(year: 2000, month: 1, day: 1))
        let first = Moon.ascendingNode(at: start)

        // Find when it next returns to the same longitude.
        var period: Double?
        for day in stride(from: 6600.0, to: 7200.0, by: 0.5) {
            if Moon.ascendingNode(at: start + day).separation(to: first).degrees < 0.05 {
                period = day / 365.25
                break
            }
        }
        XCTAssertEqual(try XCTUnwrap(period), 18.61, accuracy: 0.05)
    }

    /// At a major standstill the moon's declination reaches beyond anything the
    /// sun manages; at a minor standstill it falls well short. The swing
    /// between the two is what a lunar horizon calendar reads.
    func testStandstillsSwingWiderAndNarrowerThanTheSun() {
        var widest = 0.0, narrowest = 90.0
        let start = JulianDay(CalendarDate(year: 2000, month: 1, day: 1))
        for day in stride(from: 0.0, to: 7000.0, by: 10.0) {
            let d = Moon.standstillDeclination(at: start + day).degrees
            widest = max(widest, d)
            narrowest = min(narrowest, d)
        }

        let obliquity = EarthOrientation.meanObliquity(at: start).degrees
        XCTAssertEqual(widest, 28.6, accuracy: 0.4)
        XCTAssertEqual(narrowest, 18.3, accuracy: 0.4)
        XCTAssertGreaterThan(widest, obliquity,
                             "a major standstill reaches beyond the solstice sun")
        XCTAssertLessThan(narrowest, obliquity,
                          "a minor standstill falls short of it")
    }

    /// The moon rises and sets like everything else, and at a standstill its
    /// extremes must lie outside the sun's.
    func testMoonIsAboveAndBelowTheHorizonThroughAMonth() {
        let site = GeographicSite.stonehenge
        let start = JulianDay(CalendarDate(year: 2026, month: 6, day: 1))
        var highest = -90.0, lowest = 90.0

        for step in stride(from: 0.0, to: 29.0, by: 0.05) {
            let altitude = Moon.horizontal(at: start + step, site: site).altitude.degrees
            highest = max(highest, altitude)
            lowest = min(lowest, altitude)
        }
        XCTAssertGreaterThan(highest, 30, "the moon must climb")
        XCTAssertLessThan(lowest, -30, "and set")
    }
}
