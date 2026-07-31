import XCTest
@testable import HengeAstro

/// The year strip against facts from outside this codebase: the published
/// 2026 equinox, the synodic month's arithmetic, and the strip's own
/// bookkeeping.
final class YearAlmanacTests: XCTestCase {

    static let year2026 = YearAlmanac.solve(year: 2026)

    func testTheStripHoldsExactlyOneCivilYear() {
        let year = Self.year2026
        XCTAssertEqual(year.start.calendarDate.year, 2026)
        XCTAssertEqual(year.start.calendarDate.month, 1)
        XCTAssertEqual(year.end.calendarDate.year, 2027)
        XCTAssertEqual(year.fraction(of: year.start), 0, accuracy: 1e-12)
        XCTAssertEqual(year.fraction(of: year.end), 1, accuracy: 1e-12)
    }

    func testTheEightStationsAllFallInsideTheYearInOrder() {
        let year = Self.year2026
        XCTAssertEqual(year.stations.count, 8)
        for (station, instant) in year.stations {
            XCTAssertEqual(instant.calendarDate.year, 2026,
                           "\(station) solved outside its year")
        }
        let fractions = year.stations.map { year.fraction(of: $0.instant) }
        XCTAssertEqual(fractions, fractions.sorted())
    }

    func testTheMarchEquinoxMatchesThePublishedDate() throws {
        // USNO/Astronomical Almanac: the 2026 March equinox falls on
        // 20 March 2026, 14:46 UT — a fact printed in every almanac, not
        // read back from this code.
        let equinox = try XCTUnwrap(Self.year2026.stations
            .first { $0.station == .marchEquinox }).instant
        let date = equinox.calendarDate
        XCTAssertEqual(date.month, 3)
        XCTAssertEqual(date.day, 20.615, accuracy: 0.05)
    }

    func testTheMoonsKeepTheSynodicRhythm() {
        // A civil year holds twelve or thirteen of each syzygy, ascending,
        // spaced a synodic month apart — 29.53 days, give or take the
        // moon's real eccentricity (up to about seven hours either way).
        let year = Self.year2026
        for moons in [year.newMoons, year.fullMoons] {
            XCTAssertTrue((12...13).contains(moons.count),
                          "a year holds 12 or 13, not \(moons.count)")
            for (a, b) in zip(moons, moons.dropFirst()) {
                XCTAssertEqual(b.value - a.value, 29.53, accuracy: 0.8)
            }
            for moon in moons {
                XCTAssertEqual(moon.calendarDate.year, 2026)
            }
        }
        // New and full interleave: strictly alternating along the year.
        let merged = (year.newMoons.map { ($0.value, "new") }
                      + year.fullMoons.map { ($0.value, "full") })
            .sorted { $0.0 < $1.0 }
        for (a, b) in zip(merged, merged.dropFirst()) {
            XCTAssertNotEqual(a.1, b.1, "two \(a.1) moons in a row")
        }
    }
}
