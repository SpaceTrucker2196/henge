import XCTest
@testable import HengeGeometry
import HengeAstro

/// The animated state switch, held to the same standard as the states it
/// joins: the erosion pace, the construction order and the calendar's path
/// are all decisions, so they are all pinned here — the renderer applies
/// these numbers and adds none of its own.
final class TransitionTests: XCTestCase {

    // ── erosion pacing ──────────────────────────────────────────────────────

    func testSiltingRunsFromFreshToTodayFrontLoaded() {
        XCTAssertEqual(MonumentTransition.silting(0), 0, accuracy: 1e-12)
        XCTAssertEqual(MonumentTransition.silting(1), 1, accuracy: 1e-12)

        // Monotone: silt does not un-silt.
        var last = -1.0
        for step in 0...100 {
            let value = MonumentTransition.silting(Double(step) / 100)
            XCTAssertGreaterThan(value, last)
            last = value
        }

        // Front-loaded, as the ditch sections report: the primary silting
        // was rapid. More than three quarters of the movement lands in the
        // first half of the animation.
        XCTAssertGreaterThan(MonumentTransition.silting(0.5), 0.75)
    }

    func testErosionRunsTowardTheTargetState() {
        // Heading for the ruin: the earthwork starts fresh and ends silted.
        XCTAssertEqual(MonumentTransition.erosion(atProgress: 0, toward: .asItStands), 0)
        XCTAssertEqual(MonumentTransition.erosion(atProgress: 1, toward: .asItStands), 1)
        // Heading for the whole monument: the reverse.
        XCTAssertEqual(MonumentTransition.erosion(atProgress: 0, toward: .asItWas), 1)
        XCTAssertEqual(MonumentTransition.erosion(atProgress: 1, toward: .asItWas), 0)
    }

    // ── the earthwork on the erosion axis ───────────────────────────────────

    func testErosionEndpointsAreTheLabelledStates() {
        for (east, south) in [(-47.5, 0.0), (0.0, 54.2), (30.0, 30.0)] {
            XCTAssertEqual(Earthwork.heightDelta(east: east, south: south, erosion: 0),
                           Earthwork.heightDelta(east: east, south: south, state: .asItWas))
            XCTAssertEqual(Earthwork.heightDelta(east: east, south: south, erosion: 1),
                           Earthwork.heightDelta(east: east, south: south, state: .asItStands))
        }
    }

    func testProfileIsLinearInErosion() {
        // Linearity is what allows the renderer to morph two vertex buffers
        // instead of rebuilding the ring per frame: the midpoint profile
        // must be exactly the average of the endpoints, everywhere.
        for (east, south) in [(-47.5, 0.0), (54.2, 0.0), (0.0, -59.2), (33.0, 33.0)] {
            let fresh = Earthwork.heightDelta(east: east, south: south, erosion: 0)
            let now = Earthwork.heightDelta(east: east, south: south, erosion: 1)
            let mid = Earthwork.heightDelta(east: east, south: south, erosion: 0.5)
            XCTAssertEqual(mid, (fresh + now) / 2, accuracy: 1e-12)
        }
    }

    func testMorphMeshesShareOneGrid() {
        let fresh = Earthwork.build(erosion: 0) { _, _ in 0 }
        let eroded = Earthwork.build(erosion: 1) { _, _ in 0 }
        XCTAssertEqual(fresh.positions.count, eroded.positions.count)
        XCTAssertEqual(fresh.indices, eroded.indices)
        // Only height and wear may differ between the endpoints; the grid
        // itself — every x and z — is shared.
        for i in fresh.positions.indices {
            XCTAssertEqual(fresh.positions[i].x, eroded.positions[i].x)
            XCTAssertEqual(fresh.positions[i].z, eroded.positions[i].z)
        }
    }

    func testIntermediateMeshIsTheVertexWiseBlend() {
        let fresh = Earthwork.build(erosion: 0) { _, _ in 0 }
        let eroded = Earthwork.build(erosion: 1) { _, _ in 0 }
        let blended = Earthwork.build(erosion: 0.37) { _, _ in 0 }
        for i in fresh.positions.indices {
            let expected = fresh.positions[i].y
                + (eroded.positions[i].y - fresh.positions[i].y) * 0.37
            XCTAssertEqual(blended.positions[i].y, expected, accuracy: 1e-4,
                           "vertex \(i) is not on the line between the endpoints")
        }
    }

    func testTheEntranceStaysLevelAtEveryErosion() {
        // The processional way must not grow a bank halfway through the
        // animation any more than it may at rest.
        let axis = Monument.axisAzimuth.degrees * Double.pi / 180
        for erosion in stride(from: 0.0, through: 1.0, by: 0.1) {
            for radius in stride(from: 42.0, through: 62.0, by: 2.0) {
                let east = radius * sin(axis)
                let south = -radius * cos(axis)
                XCTAssertEqual(Earthwork.heightDelta(east: east, south: south,
                                                     erosion: erosion),
                               0, accuracy: 0.01)
            }
        }
    }

    // ── stone cues ──────────────────────────────────────────────────────────

    func testEveryChangedStoneIsCuedAndNoUnchangedStoneIs() {
        let ruin = MonumentScene.complete(state: .asItStands)
        let whole = MonumentScene.complete(state: .asItWas)
        let cues = MonumentTransition.cues(from: ruin, to: whole)

        let ruinByID = Dictionary(uniqueKeysWithValues: ruin.stones.map { ($0.id, $0) })
        let wholeByID = Dictionary(uniqueKeysWithValues: whole.stones.map { ($0.id, $0) })
        for id in Set(ruinByID.keys).union(wholeByID.keys) {
            if ruinByID[id] == wholeByID[id] {
                XCTAssertNil(cues[id], "\(id) is identical in both states yet cued")
            } else {
                XCTAssertNotNil(cues[id], "\(id) changes but has no cue")
            }
        }
        // The Aubrey holes were there first and are there still.
        XCTAssertNil(cues["aubrey-hole-0"])
        // The Heel Stone never moved.
        XCTAssertNil(cues["stone-96"])
    }

    func testCueWindowsSitInsideTheAnimation() {
        let cues = MonumentTransition.cues(from: .complete(state: .asItStands),
                                           to: .complete(state: .asItWas))
        for (id, cue) in cues {
            XCTAssertGreaterThanOrEqual(cue.window.lowerBound, 0, id)
            XCTAssertLessThanOrEqual(cue.window.upperBound, 1, id)
            XCTAssertGreaterThan(cue.sinkDepth, 0, id)
        }
    }

    func testRaisingFollowsTheBuildSequence() {
        let cues = MonumentTransition.cues(from: .complete(state: .asItStands),
                                           to: .complete(state: .asItWas))
        // A circle lintel cannot be seated before its upright is up: every
        // returning circle upright (1–30) precedes every returning circle
        // lintel (101–130).
        func starts(_ numbers: ClosedRange<Int>) -> [Double] {
            cues.compactMap { id, cue in
                guard let n = Int(id.dropFirst("stone-".count)),
                      id.hasPrefix("stone-"), numbers.contains(n) else { return nil }
                return cue.window.lowerBound
            }
        }
        let uprightStarts = starts(1...30)
        let lintelStarts = starts(101...130)
        XCTAssertFalse(uprightStarts.isEmpty)
        XCTAssertFalse(lintelStarts.isEmpty)
        XCTAssertLessThan(uprightStarts.max()!, lintelStarts.min()!,
                          "a lintel rises before the circle's uprights are up")
        // The bluestones are the Stage-2 rearrangement: they arrive last,
        // after the sarsens.
        let sarsenStarts = cues.compactMap { id, cue -> Double? in
            guard let n = Int(id.dropFirst("stone-".count).description),
                  (1...30).contains(n) else { return nil }
            return cue.window.lowerBound
        }
        let bluestoneStarts = cues.compactMap { id, cue -> Double? in
            id.hasPrefix("bluestone-") ? cue.window.lowerBound : nil
        }
        XCTAssertFalse(bluestoneStarts.isEmpty)
        XCTAssertLessThan(sarsenStarts.max()!, bluestoneStarts.min()!,
                          "a bluestone arrives before the sarsen circle is up")
    }

    func testRuinDropsLintelsBeforeUprights() {
        let cues = MonumentTransition.cues(from: .complete(state: .asItWas),
                                           to: .complete(state: .asItStands))
        // Gravity's order: a falling circle lintel starts before any
        // falling circle upright.
        let lintelStarts = cues.compactMap { id, cue -> Double? in
            guard let n = Int(id.dropFirst("stone-".count).description),
                  (101...130).contains(n) else { return nil }
            return cue.window.lowerBound
        }
        let uprightStarts = cues.compactMap { id, cue -> Double? in
            guard let n = Int(id.dropFirst("stone-".count).description),
                  (1...30).contains(n) else { return nil }
            return cue.window.lowerBound
        }
        XCTAssertFalse(lintelStarts.isEmpty)
        XCTAssertFalse(uprightStarts.isEmpty)
        XCTAssertLessThan(lintelStarts.max()!, uprightStarts.min()!,
                          "an upright falls before the lintel it carries")
    }

    func testCuesAreDeterministic() {
        let a = MonumentTransition.cues(from: .complete(state: .asItStands),
                                        to: .complete(state: .asItWas))
        let b = MonumentTransition.cues(from: .complete(state: .asItStands),
                                        to: .complete(state: .asItWas))
        XCTAssertEqual(a, b)
    }

    // ── placement ───────────────────────────────────────────────────────────

    func testPlacementRisesAndSinksThroughTheWindow() {
        let cue = MonumentTransition.StoneCue(window: 0.4...0.5, sinkDepth: 5)

        // An incoming stone is absent before its window, buried at its
        // start, seated at its end, and stays.
        XCTAssertFalse(MonumentTransition.placement(cue: cue, progress: 0.1,
                                                    role: .incoming).visible)
        let rising = MonumentTransition.placement(cue: cue, progress: 0.45,
                                                  role: .incoming)
        XCTAssertTrue(rising.visible)
        XCTAssertEqual(rising.sink, 2.5, accuracy: 1e-9)
        let seated = MonumentTransition.placement(cue: cue, progress: 0.8,
                                                  role: .incoming)
        XCTAssertTrue(seated.visible)
        XCTAssertEqual(seated.sink, 0, accuracy: 1e-9)

        // An outgoing stone is the mirror: present and seated before,
        // sinking through, gone after.
        let standing = MonumentTransition.placement(cue: cue, progress: 0.1,
                                                    role: .outgoing)
        XCTAssertTrue(standing.visible)
        XCTAssertEqual(standing.sink, 0, accuracy: 1e-9)
        XCTAssertFalse(MonumentTransition.placement(cue: cue, progress: 0.6,
                                                    role: .outgoing).visible)
    }

    // ── the path through time ───────────────────────────────────────────────

    func testTimelineLandsOnTheTargetEraExactly() {
        let start = JulianDay(year: 2026, month: 8, day: 3, hour: 9)
        let timeline = MonumentTransition.EraTimeline(from: start, toYear: -2199)

        XCTAssertEqual(timeline.julianDay(at: 0).value, start.value)
        let end = timeline.julianDay(at: 1)
        let landed = end.calendarDate
        XCTAssertEqual(landed.year, -2199)
        XCTAssertEqual(landed.month, 8)
        XCTAssertEqual(landed.day, 3.375, accuracy: 1e-6,
                       "the time of day must survive the four millennia")
    }

    func testTimelineKeepsWholeDayStepsSoTheClockReadsTrue() {
        // Away from the feathered tail, the sweep moves in whole days plus
        // the deliberate diurnal cycles — so the time of day at progress p
        // is exactly the start's time of day advanced by dayCycles·p, and
        // the sun arcs rather than strobes.
        let start = JulianDay(year: 2026, month: 8, day: 3, hour: 9)
        let timeline = MonumentTransition.EraTimeline(from: start, toYear: -2199)
        for step in 1...89 {
            let p = Double(step) / 100
            let shift = timeline.julianDay(at: p).value
                - start.value - MonumentTransition.dayCycles * p
            XCTAssertEqual(shift, shift.rounded(), accuracy: 1e-6,
                           "at p=\(p) the day shift is not whole")
        }
    }

    func testTimelineYearsWalkMonotonically() {
        let start = JulianDay(year: 2026, month: 8, day: 3, hour: 9)
        let timeline = MonumentTransition.EraTimeline(from: start, toYear: -2199)
        var lastYear = Int.max
        for step in 0...100 {
            let year = timeline.julianDay(at: Double(step) / 100).calendarDate.year
            XCTAssertLessThanOrEqual(year, lastYear,
                                     "the calendar backtracked at step \(step)")
            lastYear = year
        }
        XCTAssertEqual(lastYear, -2199)
    }

    func testEraYearsAnchorTheStates() {
        // Stage 2 complete, c. 2200 BC: astronomical year −2199.
        XCTAssertEqual(MonumentTransition.eraYear(of: .asItWas, presentYear: 2026), -2199)
        // The ruin is simply the present.
        XCTAssertEqual(MonumentTransition.eraYear(of: .asItStands, presentYear: 2026), 2026)
    }
}
