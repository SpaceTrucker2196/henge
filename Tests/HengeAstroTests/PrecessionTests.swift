import XCTest
@testable import HengeAstro

/// The sky the builders actually stood under.
final class PrecessionTests: XCTestCase {

    /// The pole goes round once in about 25,800 years.
    func testTheCycleIsAboutTwentySixThousandYears() {
        let perCentury = Precession.generalPrecession(
            at: JulianDay(CalendarDate(year: 2100, month: 1, day: 1))).degrees
        XCTAssertEqual(360 / perCentury * 100, 25_770, accuracy: 400)
    }

    /// Tonight the pole star is Polaris, and it is very close indeed — under a
    /// degree, which is why it works as one.
    func testPolarisHoldsThePoleToday() throws {
        let now = JulianDay(CalendarDate(year: 2026, month: 1, day: 1))
        let result = try XCTUnwrap(Precession.poleStar(at: now))
        XCTAssertEqual(result.star.name, "Polaris")
        XCTAssertLessThan(result.separation.degrees, 1.0)
    }

    /// **The demo.** When the sarsens went up the sky turned about Thuban, not
    /// Polaris — and Polaris was nowhere near the pole.
    func testThubanHeldThePoleWhenTheSarsensWereRaised() throws {
        let then = JulianDay(CalendarDate(year: -2500, month: 6, day: 21))
        let result = try XCTUnwrap(Precession.poleStar(at: then))

        XCTAssertEqual(result.star.name, "Thuban",
                       "the builders' sky turned about α Draconis")
        XCTAssertLessThan(result.separation.degrees, 4.0)

        // And Polaris was far from it — no use to anyone as a pole star.
        let polaris = try XCTUnwrap(Star.poleStarCandidates.first { $0.name == "Polaris" })
        XCTAssertGreaterThan(Precession.separationFromPole(polaris, at: then).degrees, 20,
                             "Polaris was not a pole star in 2500 BC")
    }

    /// Thuban was closest to the pole around 2800 BC. Searched, not asserted.
    func testThubanWasNearestAroundTwentyEightHundredBC() {
        let thuban = Star.poleStarCandidates.first { $0.name == "Thuban" }!
        var best = (year: 0, separation: 90.0)

        for year in stride(from: -4000, through: -1500, by: 25) {
            let separation = Precession.separationFromPole(
                thuban, at: JulianDay(CalendarDate(year: year, month: 1, day: 1))).degrees
            if separation < best.separation { best = (year, separation) }
        }

        XCTAssertEqual(best.year, -2800, accuracy: 250)
        XCTAssertLessThan(best.separation, 0.5, "it came within half a degree")
    }

    /// Vega takes the pole in about twelve thousand years — the far side of the
    /// same circle, and the reason "the pole star" is a temporary office.
    func testVegaTakesThePoleInTheDistantFuture() throws {
        let then = JulianDay(CalendarDate(year: 13_700, month: 1, day: 1))
        let result = try XCTUnwrap(Precession.poleStar(at: then))
        XCTAssertEqual(result.star.name, "Vega")
    }

    /// The pole's own path: it stays one obliquity from the ecliptic pole and
    /// circles it. Both halves of that are worth pinning, because the whole
    /// deep-time claim rests on them.
    func testThePoleCirclesTheEclipticPoleAtOneObliquity() {
        for year in [-2500, 0, 2026, 5000] {
            let tt = JulianDay(CalendarDate(year: year, month: 1, day: 1))
            let pole = Precession.northCelestialPole(at: tt)
            let obliquity = EarthOrientation.meanObliquity(at: tt)
            XCTAssertEqual(90 - pole.latitude.degrees, obliquity.degrees, accuracy: 1e-9,
                           "year \(year)")
        }

        // And it moves: five millennia is most of a quarter turn.
        let ancient = Precession.northCelestialPole(
            at: JulianDay(CalendarDate(year: -2500, month: 1, day: 1))).longitude
        let modern = Precession.northCelestialPole(
            at: JulianDay(CalendarDate(year: 2026, month: 1, day: 1))).longitude
        XCTAssertEqual(ancient.separation(to: modern).degrees, 63, accuracy: 6)
    }
}
