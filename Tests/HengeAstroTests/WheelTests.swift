import XCTest
@testable import HengeAstro

final class WheelTests: XCTestCase {

    /// Each station is where it claims to be: the sun is at that longitude.
    func testEveryStationLandsOnItsSolarLongitude() {
        for station in WheelStation.allCases {
            let instant = Wheel.instant(of: station, year: 2026)
            let longitude = Sun.position(at: instant).apparentLongitude
            let error = (station.solarLongitude - longitude).signedNormalized.degrees
            XCTAssertEqual(error, 0, accuracy: 1e-4, station.name)
        }
    }

    /// The four solar stations must agree with `Seasons`, which solves the same
    /// problem by a different route. Two implementations, one answer.
    func testTheSolarStationsAgreeWithSeasons() {
        for station in WheelStation.allCases {
            guard let season = station.season else { continue }
            let byWheel = Wheel.universalInstant(of: station, year: 2026).value
            let bySeasons = Seasons.universalInstant(of: season, year: 2026).value
            XCTAssertEqual(byWheel, bySeasons, accuracy: 1e-6, station.name)
        }
    }

    /// Known instants, to catch a wholesale drift the self-consistency checks
    /// would miss. June solstice 2026 falls on 21 June, 08:24 UT.
    func testAgainstPublishedSolsticeAndEquinox() {
        let june = Wheel.universalInstant(of: .juneSolstice, year: 2026).calendarDate
        XCTAssertEqual(june.month, 6)
        XCTAssertEqual(june.day, 21.35, accuracy: 0.02)   // 08:24 UT

        let december = Wheel.universalInstant(of: .decemberSolstice, year: 2026).calendarDate
        XCTAssertEqual(december.month, 12)
        XCTAssertEqual(december.day, 21.85, accuracy: 0.02)   // 20:20 UT
    }

    /// The wheel is a wheel: eight stations, evenly spaced in longitude, and
    /// therefore *unevenly* spaced in time — the Earth moves faster at
    /// perihelion, so the winter half of the year is the short one.
    func testTheWinterHalfIsShorterThanTheSummerHalf() {
        let march = Wheel.universalInstant(of: .marchEquinox, year: 2026).value
        let september = Wheel.universalInstant(of: .septemberEquinox, year: 2026).value
        let nextMarch = Wheel.universalInstant(of: .marchEquinox, year: 2027).value

        let summerHalf = september - march
        let winterHalf = nextMarch - september
        XCTAssertGreaterThan(summerHalf - winterHalf, 6,
                             "perihelion in January makes the winter half about a week shorter")
    }

    /// **The honesty test.** The customary cross-quarter dates are not the
    /// astronomical ones, and the app reports the gap rather than smoothing it.
    func testTheTraditionalCrossQuarterDatesLagTheSun() {
        for station in WheelStation.allCases where station.isCrossQuarter {
            let offset = Wheel.traditionalOffset(of: station, year: 2026)
            let days = try! XCTUnwrap(offset)
            XCTAssertGreaterThan(days, 2, "\(station.name): the sun arrives later than the feast")
            XCTAssertLessThan(days, 8, station.name)
        }

        // And the solar stations have no fixed date to be offset from.
        for station in WheelStation.allCases where !station.isCrossQuarter {
            XCTAssertNil(Wheel.traditionalOffset(of: station, year: 2026), station.name)
            XCTAssertNil(station.traditionalDate, station.name)
        }
    }

    /// `stations(inYear:)` returns all eight in the sun's order.
    func testTheYearReturnsEightStationsInOrder() {
        let stations = Wheel.stations(inYear: 2026)
        XCTAssertEqual(stations.count, 8)
        XCTAssertEqual(Set(stations.map(\.station)), Set(WheelStation.allCases))
        for (earlier, later) in zip(stations, stations.dropFirst()) {
            XCTAssertLessThan(earlier.instant.value, later.instant.value)
        }
    }

    /// The next station is always ahead, always within a season, and rolls over
    /// the year boundary — the case that catches naive same-year searches.
    func testNextStationRollsOverTheYearEnd() {
        let newYearsEve = JulianDay(CalendarDate(year: 2026, month: 12, day: 28))
        let next = Wheel.nextStation(after: newYearsEve)
        XCTAssertEqual(next.station, .imbolc)
        XCTAssertEqual(next.instant.calendarDate.year, 2027)

        // General property: never behind, never more than a quarter ahead.
        for month in 1...12 {
            let moment = JulianDay(CalendarDate(year: 2026, month: month, day: 15))
            let ahead = Wheel.nextStation(after: moment).instant.value - moment.value
            XCTAssertGreaterThan(ahead, 0, "month \(month)")
            XCTAssertLessThan(ahead, 47, "month \(month): stations are ~46 days apart")
        }
    }

    /// Deep time: the wheel still works in the builders' era, where the June
    /// solstice falls in what the proleptic Julian calendar calls July. If this
    /// ever reads 21 June, someone has hardcoded a date.
    func testTheWheelHoldsInTwentyFiveHundredBC() {
        let solstice = Wheel.universalInstant(of: .juneSolstice, year: -2500).calendarDate
        XCTAssertEqual(solstice.month, 7, "the solstice had drifted into July by then")

        let stations = Wheel.stations(inYear: -2500)
        XCTAssertEqual(stations.count, 8)
        for (earlier, later) in zip(stations, stations.dropFirst()) {
            let gap = later.instant.value - earlier.instant.value
            XCTAssertGreaterThan(gap, 43)
            XCTAssertLessThan(gap, 48)
        }
    }
}
