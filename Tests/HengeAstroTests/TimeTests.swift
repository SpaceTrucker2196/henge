import XCTest
@testable import HengeAstro

/// Reference values from Meeus, *Astronomical Algorithms* (2nd ed.), table 7.A
/// and the worked examples. Chosen over anything self-generated on purpose: a
/// test that checks the code against itself passes when both halves are wrong
/// (AGENTS.md, "never feed a parser its own output").
final class JulianDayTests: XCTestCase {

    func testGregorianDatesFromMeeusTable7A() {
        let cases: [(CalendarDate, Double)] = [
            (CalendarDate(year: 2000, month: 1, day: 1.5), 2451545.0),
            (CalendarDate(year: 1999, month: 1, day: 1.0), 2451179.5),
            (CalendarDate(year: 1987, month: 1, day: 27.0), 2446822.5),
            (CalendarDate(year: 1987, month: 6, day: 19.5), 2446966.0),
            (CalendarDate(year: 1988, month: 1, day: 27.0), 2447187.5),
            (CalendarDate(year: 1988, month: 6, day: 19.5), 2447332.0),
            (CalendarDate(year: 1900, month: 1, day: 1.0), 2415020.5),
            (CalendarDate(year: 1600, month: 1, day: 1.0), 2305447.5),
            (CalendarDate(year: 1600, month: 12, day: 31.0), 2305812.5),
            (CalendarDate(year: 1957, month: 10, day: 4.81), 2436116.31)
        ]
        for (date, expected) in cases {
            XCTAssertEqual(JulianDay(date).value, expected, accuracy: 1e-5,
                           "\(date.year)-\(date.month)-\(date.day)")
        }
    }

    /// Dates before the 1582 reform are Julian-calendar dates. Getting this
    /// wrong displaces the monument's own era by ten days and more — the whole
    /// point of Henge is that 2500 BC lands where it actually did.
    func testJulianCalendarDatesFromMeeusTable7A() {
        let cases: [(CalendarDate, Double)] = [
            (CalendarDate(year: 837, month: 4, day: 10.3), 2026871.8),
            (CalendarDate(year: -1000, month: 7, day: 12.5), 1356001.0),
            (CalendarDate(year: -1000, month: 2, day: 29.0), 1355866.5),
            (CalendarDate(year: -1001, month: 8, day: 17.9), 1355671.4),
            (CalendarDate(year: -4712, month: 1, day: 1.5), 0.0)
        ]
        for (date, expected) in cases {
            XCTAssertEqual(JulianDay(date).value, expected, accuracy: 1e-5,
                           "\(date.year)-\(date.month)-\(date.day)")
        }
    }

    func testCalendarRoundTripAcrossFiveMillennia() {
        let dates = [
            CalendarDate(year: -2500, month: 6, day: 21.25),
            CalendarDate(year: -1000, month: 2, day: 29.0),
            CalendarDate(year: 837, month: 4, day: 10.3),
            CalendarDate(year: 1582, month: 10, day: 15.0),
            CalendarDate(year: 2026, month: 6, day: 21.2),
            CalendarDate(year: 2999, month: 12, day: 31.5)
        ]
        for date in dates {
            let round = JulianDay(date).calendarDate
            XCTAssertEqual(round.year, date.year, "year for \(date.year)")
            XCTAssertEqual(round.month, date.month, "month for \(date.year)")
            XCTAssertEqual(round.day, date.day, accuracy: 1e-6, "day for \(date.year)")
        }
    }

    /// Meeus ch. 7: 1954 June 30.0 was a Wednesday.
    func testWeekday() {
        XCTAssertEqual(JulianDay(CalendarDate(year: 1954, month: 6, day: 30.0)).weekday, 3)
    }
}

final class DeltaTTests: XCTestCase {

    /// Espenak & Meeus give roughly these values; the polynomials are a fit to
    /// observation, so the tolerances reflect the fit's own spread rather than
    /// pretending to more precision than exists.
    func testKnownValues() {
        // 2000: about 64 seconds, well observed.
        XCTAssertEqual(DeltaT.seconds(decimalYear: 2000), 63.8, accuracy: 1.0)
        // 1900: about -3 seconds.
        XCTAssertEqual(DeltaT.seconds(decimalYear: 1900), -2.8, accuracy: 1.5)
        // 1600: about 120 seconds.
        XCTAssertEqual(DeltaT.seconds(decimalYear: 1600), 120, accuracy: 5)
    }

    /// Deep time is where ΔT stops being a footnote. At 2500 BC it runs to
    /// about 55,000 seconds — over fifteen hours. An engine that ignored it
    /// would put the solstice sunrise most of a day out.
    func testDeepTimeIsLarge() {
        let delta = DeltaT.seconds(decimalYear: -2500)
        XCTAssertGreaterThan(delta, 40_000)
        XCTAssertLessThan(delta, 80_000)
    }

    func testIsContinuousAcrossPolynomialSeams() {
        // Each polynomial covers its own span; a discontinuity at a seam would
        // make time jump for anyone scrubbing across it.
        for seam in [500.0, 1600, 1700, 1800, 1860, 1900, 1920, 1941, 1961, 1986, 2005, 2050] {
            let before = DeltaT.seconds(decimalYear: seam - 0.001)
            let after = DeltaT.seconds(decimalYear: seam + 0.001)
            XCTAssertEqual(before, after, accuracy: 2.0, "discontinuity at \(seam)")
        }
    }

    func testUniversalTimeRoundTrip() {
        for year in [-2500, 0, 1600, 1987, 2026] {
            let ut = JulianDay(CalendarDate(year: year, month: 6, day: 21.5))
            XCTAssertEqual(ut.terrestrialTime.universalTime.value, ut.value, accuracy: 1e-6,
                           "round trip for \(year)")
        }
    }
}

final class AngleTests: XCTestCase {

    func testNormalisation() {
        XCTAssertEqual(Angle(degrees: 370).normalized.degrees, 10, accuracy: 1e-9)
        XCTAssertEqual(Angle(degrees: -10).normalized.degrees, 350, accuracy: 1e-9)
        XCTAssertEqual(Angle(degrees: 359).signedNormalized.degrees, -1, accuracy: 1e-9)
        XCTAssertEqual(Angle(degrees: 181).signedNormalized.degrees, -179, accuracy: 1e-9)
    }

    func testSexagesimalConstruction() {
        let a = Angle(degrees: 23, arcminutes: 26, arcseconds: 21.448)
        XCTAssertEqual(a.degrees, 23.4392911, accuracy: 1e-6)
        let negative = Angle(degrees: -7, arcminutes: 47, arcseconds: 6.3)
        XCTAssertEqual(negative.degrees, -7.785083, accuracy: 1e-5)
    }

    func testSeparationTakesTheShortWayRound() {
        XCTAssertEqual(Angle(degrees: 350).separation(to: Angle(degrees: 10)).degrees,
                       20, accuracy: 1e-9)
        XCTAssertEqual(Angle(degrees: 10).separation(to: Angle(degrees: 350)).degrees,
                       20, accuracy: 1e-9)
    }
}
