import XCTest
@testable import HengeAstro

/// The moonrise solver against the sky's own habits: the crossing is a
/// crossing, the Moon rises later each day, and once a month it skips a
/// civil day entirely.
final class MoonriseTests: XCTestCase {

    private let stonehenge = GeographicSite.stonehenge

    func testTheSolvedMomentIsAnUpwardHorizonCrossing() throws {
        let rise = try XCTUnwrap(Moon.riseTime(
            on: CalendarDate(year: 2026, month: 1, day: 10.0),
            site: stonehenge))
        // At the solved moment the upper limb touches the skyline: apparent
        // topocentric altitude equals minus the true semi-diameter.
        let altitude = Moon.horizontal(at: rise, site: stonehenge).altitude
        let semiDiameter = Moon.semiDiameter(at: rise.terrestrialTime)
        XCTAssertEqual(altitude.degrees, -semiDiameter.degrees, accuracy: 0.05)
        // And twenty minutes on, the Moon stands higher — a rise, not a set.
        let later = Moon.horizontal(at: rise + 20.0 / 1440,
                                    site: stonehenge).altitude
        XCTAssertGreaterThan(later.degrees, altitude.degrees)
    }

    func testTheMoonRisesLaterEachDay() throws {
        // The retardation: roughly fifty minutes later per day, varying with
        // the ecliptic's angle to the horizon. Two well-separated January
        // days, both away from the skip.
        let first = try XCTUnwrap(Moon.riseTime(
            on: CalendarDate(year: 2026, month: 1, day: 10.0),
            site: stonehenge))
        let second = try XCTUnwrap(Moon.riseTime(
            on: CalendarDate(year: 2026, month: 1, day: 11.0),
            site: stonehenge))
        let retardation = (second.value - first.value - 1) * 1440
        XCTAssertGreaterThan(retardation, 10, "the Moon must rise later")
        XCTAssertLessThan(retardation, 90, "but not this much later")
    }

    func testOneCivilDayAMonthHasNoMoonrise() {
        // The Moon comes up about fifty minutes later each day, so once per
        // lunation the rise slides past midnight and a civil day goes
        // without one. A 31-day month at this latitude holds exactly one
        // such day, and the solver must return nil for it rather than
        // invent a crossing.
        var skipped: [Int] = []
        for day in 1...31 {
            if Moon.riseTime(on: CalendarDate(year: 2026, month: 1,
                                              day: Double(day)),
                             site: stonehenge) == nil {
                skipped.append(day)
            }
        }
        XCTAssertEqual(skipped.count, 1,
                       "January 2026 should skip exactly one moonrise, "
                       + "not days \(skipped)")
    }
}
