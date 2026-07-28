import XCTest
@testable import HengeGeometry
import HengeAstro

/// The Aubrey counter ships as a toy. These tests say exactly how good a toy.
final class AubreyTests: XCTestCase {

    func testTheRingHasFiftySixHoles() {
        XCTAssertEqual(AubreyRing.holeCount, 56)
        XCTAssertEqual(AubreyRing.marker(for: Angle(degrees: 0)), 0)
        XCTAssertEqual(AubreyRing.marker(for: Angle(degrees: 180)), 28)
        XCTAssertEqual(AubreyRing.marker(for: Angle(degrees: 360)), 0, "the ring closes")
    }

    func testSeparationTakesTheShortWayRound() {
        XCTAssertEqual(AubreyRing.separation(0, 2), 2, accuracy: 1e-9)
        XCTAssertEqual(AubreyRing.separation(0, 54), 2, accuracy: 1e-9, "backwards is shorter")
        XCTAssertEqual(AubreyRing.separation(0, 28), 28, accuracy: 1e-9, "the far side")
        for a in stride(from: 0.0, to: 56.0, by: 3.5) {
            for b in stride(from: 0.0, to: 56.0, by: 3.5) {
                let gap = AubreyRing.separation(a, b)
                XCTAssertGreaterThanOrEqual(gap, 0)
                XCTAssertLessThanOrEqual(gap, 28)
            }
        }
    }

    /// **The honest scoring.** Run the ring's rule against the ephemeris's own
    /// eclipse seasons across a decade and report how it does. It should catch
    /// nearly all of them — and it should also fire when nothing happens,
    /// because three holes is a coarser net than the real ecliptic limits.
    func testTheRingCatchesRealEclipseSeasonsAndAlsoCriesWolf() {
        let start = JulianDay(CalendarDate(year: 2020, month: 1, day: 1))
        let events = Events.upcoming(from: start, days: 3652)

        let syzygies = events.filter { $0.kind == .newMoon || $0.kind == .fullMoon }
        let realEclipses = Set(events.compactMap { event -> Double? in
            if case .eclipsePossible = event.kind { return event.instant.value }
            return nil
        })
        XCTAssertGreaterThan(realEclipses.count, 40, "a decade should hold plenty")

        var caught = 0, missed = 0, falseAlarms = 0
        for syzygy in syzygies {
            let ringSays = AubreyRing.isEclipseSeason(at: syzygy.instant.terrestrialTime)
            let reallyIs = realEclipses.contains(syzygy.instant.value)
            switch (ringSays, reallyIs) {
            case (true, true): caught += 1
            case (false, true): missed += 1
            case (true, false): falseAlarms += 1
            case (false, false): break
            }
        }

        // It is a good counter, not a perfect one.
        let recall = Double(caught) / Double(caught + missed)
        XCTAssertGreaterThan(recall, 0.85,
            "recall \(caught)/\(caught + missed), false alarms \(falseAlarms) of \(syzygies.count)")

        // And it over-warns, which is the part a demo must not hide.
        XCTAssertGreaterThan(falseAlarms, 0,
                             "three holes is coarser than the real ecliptic limits")

        // Recorded rather than merely asserted, so the honest score is visible
        // in the log rather than only in the pass/fail: over a decade the ring
        // finds nearly every eclipse season and warns on some that pass
        // without one. That is what a Neolithic counter could plausibly do,
        // and it is the reason the feature is badged a hypothesis.
        print("Aubrey ring over a decade: caught \(caught), missed \(missed), "
              + "false alarms \(falseAlarms), from \(syzygies.count) syzygies")
    }

    /// The markers track the real bodies: the moon laps the ring about
    /// thirteen times a year while the sun goes round once.
    func testMarkersMoveAtTheRatesTheHypothesisNeeds() {
        let start = JulianDay(CalendarDate(year: 2026, month: 1, day: 1))
        let year = start + 365.2422

        let sunMoved = AubreyRing.hole(for: Sun.position(at: year).apparentLongitude)
            - AubreyRing.hole(for: Sun.position(at: start).apparentLongitude)
        XCTAssertEqual(abs(sunMoved), 0, accuracy: 0.2, "the sun returns to its hole in a year")

        // The node regresses about three holes a year — Hoyle's third marker.
        let nodeMoved = Moon.ascendingNode(at: start).degrees - Moon.ascendingNode(at: year).degrees
        let holes = (nodeMoved < 0 ? nodeMoved + 360 : nodeMoved) / 360 * 56
        XCTAssertEqual(holes, 3, accuracy: 0.15)
    }

    /// The one non-negotiable: it cannot be shown without its tier and sources.
    func testTheFeatureCarriesItsHypothesisBadge() {
        let note = AubreyRing.note
        XCTAssertEqual(note.tier, .debated)
        XCTAssertGreaterThanOrEqual(note.citations.count, 2,
                                    "Hoyle's claim and the rebuttal both")
        XCTAssertTrue(note.citations.contains { $0.source.contains("Hoyle") })
        XCTAssertTrue(note.citations.contains { $0.source.contains("Ruggles") })
    }
}
