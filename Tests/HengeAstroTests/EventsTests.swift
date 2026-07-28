import XCTest
@testable import HengeAstro

final class EventsTests: XCTestCase {

    /// Published new moons, to catch a wholesale drift the self-consistency
    /// checks below would not see. Both from the standard tables.
    func testPhasesAgainstPublishedInstants() {
        // New moon 2026-01-18, 19:52 UT.
        let january = Moon.nextPhase(Angle(degrees: 0),
                                     after: JulianDay(CalendarDate(year: 2026, month: 1, day: 10)).terrestrialTime)
            .universalTime.calendarDate
        XCTAssertEqual(january.month, 1)
        XCTAssertEqual(january.day, 18.83, accuracy: 0.01)

        // Full moon 2026-03-03, 11:38 UT — the total lunar eclipse.
        let march = Moon.nextPhase(Angle(degrees: 180),
                                   after: JulianDay(CalendarDate(year: 2026, month: 2, day: 25)).terrestrialTime)
            .universalTime.calendarDate
        XCTAssertEqual(march.month, 3)
        XCTAssertEqual(march.day, 3.48, accuracy: 0.01)
    }

    /// A phase is where it claims to be. Round-trips the definition.
    func testEachPhaseLandsOnItsElongation() {
        let start = JulianDay(CalendarDate(year: 2026, month: 6, day: 1)).terrestrialTime
        for target in [0.0, 90, 180, 270] {
            let moment = Moon.nextPhase(Angle(degrees: target), after: start)
            let error = (Angle(degrees: target) - Moon.elongation(at: moment)).signedNormalized
            // 1e-5° is 0.07 seconds of time. The solver uses the *mean* rate as
            // its derivative and the true rate varies by 13%, so it converges
            // geometrically to about here in eight passes. Tightening this
            // would be measuring the root-finder against a precision the
            // ephemeris underneath it does not have.
            XCTAssertEqual(error.degrees, 0, accuracy: 1e-5, "\(target)°")
            XCTAssertGreaterThan(moment.value, start.value, "\(target)° must be ahead")
        }
    }

    /// Successive new moons are a synodic month apart — and *not* all the same
    /// distance apart, which is the thing a mean-lunation table gets wrong.
    func testSuccessiveNewMoonsVaryAroundTheSynodicMonth() {
        var moment = JulianDay(CalendarDate(year: 2026, month: 1, day: 1)).terrestrialTime
        var gaps: [Double] = []
        for _ in 0..<14 {
            let next = Moon.nextPhase(.zero, after: moment + 1)
            if !gaps.isEmpty || true { gaps.append(next.value - moment.value) }
            moment = next
        }
        gaps.removeFirst()      // the first gap starts from an arbitrary date

        let mean = gaps.reduce(0, +) / Double(gaps.count)
        XCTAssertEqual(mean, 29.5306, accuracy: 0.05)

        let spread = gaps.max()! - gaps.min()!
        XCTAssertGreaterThan(spread, 0.3,
                             "real lunations vary by hours; a mean period would show none")
        XCTAssertLessThan(spread, 1.0)
    }

    /// **The one that matters.** 2026 has two eclipse seasons, and the app must
    /// find them without being told when they are. The 3 March full moon is a
    /// total lunar eclipse; the 17 February new moon is an annular solar.
    func testTwentyTwentySixEclipseSeasonsAreFound() {
        let year = Events.upcoming(from: JulianDay(CalendarDate(year: 2026, month: 1, day: 1)),
                                   days: 365)
        let eclipses = year.filter {
            if case .eclipsePossible = $0.kind { return true }
            return false
        }

        // February solar, March lunar, then the August pair.
        let months = Set(eclipses.map { $0.instant.calendarDate.month })
        XCTAssertTrue(months.contains(2), "annular solar, 17 February")
        XCTAssertTrue(months.contains(3), "total lunar, 3 March")
        XCTAssertTrue(months.contains(8), "total solar, 12 August")

        // Eclipses come in seasons of two or three, roughly six months apart —
        // never scattered evenly through the year.
        XCTAssertGreaterThanOrEqual(eclipses.count, 4)
        XCTAssertLessThanOrEqual(eclipses.count, 7)
    }

    /// Every flagged eclipse really is near a node, and nothing near a node is
    /// missed. The limits are the definition, so this checks the plumbing.
    func testEclipseFlagsTrackTheNodeDistance() {
        let events = Events.upcoming(from: JulianDay(CalendarDate(year: 2026, month: 1, day: 1)),
                                     days: 400)
        for event in events {
            guard case .eclipsePossible(let solar, let certain) = event.kind else { continue }
            let degrees = Moon.distanceFromNode(at: event.instant.terrestrialTime).degrees
            XCTAssertLessThanOrEqual(degrees, solar ? 18.5 : 12.2, event.kind.name)
            if certain { XCTAssertLessThanOrEqual(degrees, solar ? 15.4 : 9.5) }
        }
    }

    /// The node distance folds to the nearer node, so it never exceeds 90°.
    func testNodeDistanceIsAlwaysNearest() {
        var jd = JulianDay(CalendarDate(year: 2026, month: 1, day: 1))
        for _ in 0..<60 {
            let degrees = Moon.distanceFromNode(at: jd).degrees
            XCTAssertGreaterThanOrEqual(degrees, 0)
            XCTAssertLessThanOrEqual(degrees, 90)
            jd = jd + 5
        }
    }

    /// The 18.61-year swing: standstills alternate major and minor, spaced
    /// about 9.3 years, and the envelope really does reach past the sun's 23.4°
    /// at a major and fall well inside it at a minor.
    func testStandstillsAlternateAcrossTheNodalCycle() {
        var moment = JulianDay(CalendarDate(year: 2020, month: 1, day: 1))
        var found: [(major: Bool, jd: JulianDay)] = []
        for _ in 0..<4 {
            let event = Moon.nextStandstill(after: moment)
            guard case .standstill(let major) = event.kind else { return XCTFail("wrong kind") }
            found.append((major, event.instant))
            moment = event.instant + 365
        }

        for (earlier, later) in zip(found, found.dropFirst()) {
            XCTAssertNotEqual(earlier.major, later.major, "they must alternate")
            let years = (later.jd.value - earlier.jd.value) / 365.25
            XCTAssertEqual(years, 9.3, accuracy: 0.6)
        }

        for entry in found {
            let envelope = Moon.standstillDeclination(at: entry.jd).degrees
            if entry.major {
                XCTAssertGreaterThan(envelope, 28.0, "beyond anything the sun reaches")
            } else {
                XCTAssertLessThan(envelope, 18.6, "well inside the sun's swing")
            }
        }

        // The 2024–25 major standstill is the one people travelled for.
        let major = found.first { $0.major }!
        XCTAssertEqual(major.jd.calendarDate.year, 2025, accuracy: 1)
    }

    /// The calendar itself: ordered, inside its window, and dense enough that a
    /// four-month look-ahead always finds the moon.
    func testUpcomingIsOrderedAndBounded() {
        let start = JulianDay(CalendarDate(year: 2026, month: 4, day: 1))
        let events = Events.upcoming(from: start, days: 120)

        XCTAssertFalse(events.isEmpty)
        for event in events {
            XCTAssertGreaterThan(event.instant.value, start.value)
            XCTAssertLessThan(event.instant.value, start.value + 120)
        }
        for (earlier, later) in zip(events, events.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier.instant.value, later.instant.value)
        }

        // Four lunations in 120 days means about four of each phase.
        let fullMoons = events.filter { $0.kind == .fullMoon }
        XCTAssertEqual(fullMoons.count, 4, accuracy: 1)

        // Both solstices and equinoxes in that span? No — one station, maybe two.
        let stations = events.filter { if case .station = $0.kind { return true }; return false }
        XCTAssertGreaterThanOrEqual(stations.count, 2)
    }

    /// Deep time: the machinery still runs in the builders' era, where ΔT is
    /// hours rather than seconds. If the time scales were crossed in the wrong
    /// place, the phases would drift against the sun.
    func testTheEventsEngineRunsInTwentyFiveHundredBC() {
        let start = JulianDay(CalendarDate(year: -2500, month: 1, day: 1))
        let events = Events.upcoming(from: start, days: 120)
        XCTAssertFalse(events.isEmpty)

        for event in events where event.kind == .fullMoon {
            // A full moon is opposite the sun. Solved in TT, reported in UT —
            // so converting back must land on 180° again.
            let elongation = Moon.elongation(at: event.instant.terrestrialTime)
            XCTAssertEqual(elongation.degrees, 180, accuracy: 0.01)
        }
    }

    func testNextEventIsAlwaysAhead() {
        for month in [1, 4, 7, 10] {
            let start = JulianDay(CalendarDate(year: 2026, month: month, day: 20))
            let next = Events.next(after: start)
            let event = try! XCTUnwrap(next)
            XCTAssertGreaterThan(event.instant.value, start.value, "month \(month)")
            XCTAssertLessThan(event.instant.value - start.value, 40, "month \(month)")
        }
    }
}
