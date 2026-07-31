import XCTest
import simd
@testable import HengeUI
import HengeAstro
import HengeGeometry

/// The app's state machine.
///
/// This target exists because the wind needed a test and there was nowhere to
/// put it: `SkyModel` drives every jump, every clock and every number the
/// almanac shows, and had no coverage whatever. These are the invariants that
/// would be silently wrong rather than visibly broken.
@MainActor
final class SkyModelTests: XCTestCase {

    /// **Wind keeps wall-clock time, never the astronomical clock.**
    ///
    /// Time here runs at up to a day a second. A breeze scaled by that would be
    /// a strobe, and one paused with the sun would be a photograph.
    func testWindKeepsWallClockTimeNotSkyTime() {
        let model = SkyModel()
        model.rate = 86_400
        model.isPlaying = true
        model.advance(byRealSeconds: 2)
        XCTAssertEqual(model.windTime, 2, accuracy: 1e-9,
                       "wind time was scaled by the playback rate")

        model.isPlaying = false
        model.advance(byRealSeconds: 3)
        XCTAssertEqual(model.windTime, 5, accuracy: 1e-9,
                       "the breeze stopped because the sun was paused")
    }

    /// The astronomical clock, by contrast, *is* scaled and *does* pause.
    func testSkyTimeScalesWithTheRateAndStopsWhenPaused() {
        let model = SkyModel()
        model.time = JulianDay(CalendarDate(year: 2026, month: 6, day: 21))
        let start = model.time.value

        model.rate = 86_400          // a day a second
        model.isPlaying = true
        model.advance(byRealSeconds: 1)
        XCTAssertEqual(model.time.value - start, 1, accuracy: 1e-6)

        model.isPlaying = false
        model.advance(byRealSeconds: 10)
        XCTAssertEqual(model.time.value - start, 1, accuracy: 1e-6, "paused time moved")
    }

    /// The scene the renderer draws and the numbers the almanac prints come
    /// from one moment. If these ever diverge the app is lying in the most
    /// damaging way available to it — a picture that disagrees with its caption.
    func testTheSceneAndTheAlmanacShareOneSun() {
        let model = SkyModel()
        model.viewpoint = .stonehenge
        model.time = JulianDay(CalendarDate(year: 2026, month: 6, day: 21, hour: 4, minute: 52))

        let almanac = model.sun
        let scene = model.sceneState.sun
        XCTAssertEqual(scene.altitude.degrees, almanac.altitude.degrees, accuracy: 1e-9)
        XCTAssertEqual(scene.azimuth.degrees, almanac.azimuth.degrees, accuracy: 1e-9)
    }

    /// Jumping to a station lands on the sun's arrival, not on a calendar date.
    func testJumpingToAStationLandsOnTheSun() {
        let model = SkyModel()
        model.time = JulianDay(CalendarDate(year: 2026, month: 1, day: 15))
        model.jump(to: .juneSolstice)

        let longitude = Sun.position(at: model.time.terrestrialTime).apparentLongitude
        XCTAssertEqual(longitude.signedNormalized.degrees, 90, accuracy: 0.01)
    }

    /// Sunrise jumps land at sunrise — near enough that the sun is on the
    /// horizon rather than merely on the right day.
    func testJumpingToASunriseLandsAtSunrise() {
        // All eight stations, not one: M7's second item asked whether the
        // sunrise landing held for the whole wheel, and the answer should
        // be an assertion rather than a recollection.
        let model = SkyModel()
        model.viewpoint = .stonehenge
        for station in WheelStation.allCases {
            model.time = JulianDay(CalendarDate(year: 2026, month: 1, day: 2))
            model.jumpToSunrise(of: station)
            XCTAssertEqual(model.sun.altitude.degrees, 0, accuracy: 1.5,
                           "\(station) landed at altitude "
                           + "\(model.sun.altitude.degrees)°")
        }
    }

    /// Zoom is bounded at both ends, at every station. An unbounded zoom
    /// inverts the projection or turns the camera inside out.
    ///
    /// The contract changed on the owner's order (2026-07-31): pinch is a
    /// *lens* everywhere, aerial included — zooming out widens the field
    /// of view so more sky comes into frame, and the camera's range no
    /// longer rides the pinch at all.
    func testZoomIsALensBoundedAtBothStops() {
        let model = SkyModel()

        for station in [SkyModel.Station.aerial, .altarStone] {
            model.station = station
            model.fieldOfView = 62
            for _ in 0..<200 { model.zoom(by: 1.4) }
            XCTAssertGreaterThanOrEqual(model.fieldOfView, 22)
            for _ in 0..<200 { model.zoom(by: 0.7) }
            XCTAssertLessThanOrEqual(model.fieldOfView, 110)
            XCTAssertEqual(model.cameraDistance, 92,
                           "range must not ride the pinch — the lens does")
        }

        // And a nonsense scale must not corrupt the state.
        let before = model.fieldOfView
        model.zoom(by: 0)
        model.zoom(by: -1)
        XCTAssertEqual(model.fieldOfView, before)
    }

    /// The ground plan's labels: present exactly when the overlay is on,
    /// carrying the surveyed figures, projected inside the frame.
    func testGroundLabelsCarryTheSurveyAndRideTheOverlay() {
        let model = SkyModel()
        XCTAssertTrue(model.groundLabels(aspect: 1.5).isEmpty,
                      "no overlay, no labels")

        model.showsAlignmentOverlay = true
        model.station = .aerial
        let labels = model.groundLabels(aspect: 1.5)
        XCTAssertFalse(labels.isEmpty)

        let names = Set(labels.map(\.id))
        // From the default aerial camera at least two cardinals and the
        // circle must be in frame; every label that projects must land
        // near the screen.
        XCTAssertFalse(names.intersection(["N", "E", "S", "W"]).isEmpty)
        XCTAssertTrue(names.contains("Sarsen circle"))
        let sarsen = labels.first { $0.id == "Sarsen circle" }
        XCTAssertEqual(sarsen?.detail, "33 m across",
                       "the label must carry the surveyed figure")
        for label in labels {
            XCTAssertTrue((-0.2...1.2).contains(label.x))
            XCTAssertTrue((-0.2...1.2).contains(label.y))
        }
    }

    /// Recentre puts every view parameter back, not merely the bearing.
    func testRecentreRestoresTheWholeView() {
        let model = SkyModel()
        model.drag(by: SIMD2(400, 120))
        model.station = .aerial
        model.zoom(by: 2.5)
        model.recentre()

        XCTAssertEqual(model.fieldOfView, 62, accuracy: 1e-9)
        XCTAssertEqual(model.cameraDistance, 92, accuracy: 1e-9)
    }
}

extension SkyModelTests {

    /// **The eye never goes under the plain.**
    ///
    /// Pitched far enough down, the orbit camera put the eye below Salisbury
    /// Plain — and from under it you are looking at the back of a single-sided,
    /// unlit terrain mesh, which reads as the world having been switched off.
    /// On a heightfield "below ground" is a different number everywhere, so the
    /// clamp asks the terrain rather than comparing against zero.
    func testTheCameraCannotGoUnderground() {
        let model = SkyModel()
        model.viewpoint = .stonehenge
        model.station = .aerial

        // Drive the view as far down as the gestures allow, from several
        // bearings and ranges — the clamp has to hold everywhere, not at the
        // one spot it was tuned at.
        for bearing in stride(from: 0.0, to: 360.0, by: 45) {
            model.cameraAzimuth = bearing
            for distance in [20.0, 90.0, 300.0] {
                model.cameraDistance = distance
                for _ in 0..<60 { model.drag(by: SIMD2(0, -60)) }

                let camera = model.camera
                let ground = model.groundHeight(east: Double(camera.position.x),
                                                south: Double(camera.position.z))
                XCTAssertGreaterThanOrEqual(
                    Double(camera.position.y), ground + SkyModel.minimumClearance - 1e-4,
                    "bearing \(bearing), range \(distance): eye at "
                    + "\(camera.position.y) with ground at \(ground)")
            }
        }
    }

    /// Clamping must not swing the view. Raising the eye without raising what
    /// it looks at would make the camera tip toward its own feet as it clamps.
    func testClampingPreservesTheViewDirection() {
        let model = SkyModel()
        model.station = .aerial
        model.cameraDistance = 40
        for _ in 0..<60 { model.drag(by: SIMD2(0, -60)) }

        let camera = model.camera
        let direction = simd_normalize(camera.target - camera.position)
        XCTAssertEqual(simd_length(direction), 1, accuracy: 1e-5)
        XCTAssertLessThan(abs(direction.y), 0.999, "the camera is looking straight down")
    }
}

extension SkyModelTests {

    /// The day bar's profile covers a whole local day and finds the sun.
    func testTheDayProfileSpansOneDay() {
        let model = SkyModel()
        model.viewpoint = .stonehenge
        model.time = JulianDay(CalendarDate(year: 2026, month: 6, day: 21, hour: 12))

        let profile = model.dayProfile(samples: 96)
        XCTAssertEqual(profile.count, 96)
        // Midsummer at 51° N: the sun climbs past 60° and dips below the
        // horizon, but never as far as astronomical night — Wiltshire has none
        // in June, which is a real fact the bar should show.
        XCTAssertGreaterThan(profile.max() ?? 0, 58)
        XCTAssertLessThan(profile.min() ?? 0, 0)
        XCTAssertGreaterThan(profile.min() ?? -90, -18,
                             "there is no astronomical night here in midsummer")
    }

    /// Midwinter is the other case, and must reach real night.
    func testMidwinterReachesAstronomicalNight() {
        let model = SkyModel()
        model.viewpoint = .stonehenge
        model.time = JulianDay(CalendarDate(year: 2026, month: 12, day: 21, hour: 12))
        let profile = model.dayProfile(samples: 96)
        XCTAssertLessThan(profile.min() ?? 0, -18)
        XCTAssertLessThan(profile.max() ?? 90, 20, "the midwinter sun stays low")
    }

    /// Scrubbing lands where it was asked to, and keeps the date.
    func testScrubbingMovesWithinTheDay() {
        let model = SkyModel()
        model.viewpoint = .stonehenge
        model.time = JulianDay(CalendarDate(year: 2026, month: 6, day: 21, hour: 3))
        // The *local* day, not the UT one. In BST local midnight is 23:00 UT
        // the previous evening, so scrubbing to the left edge of the bar
        // legitimately moves the UT date back a day while staying on the same
        // local day — which is the day the bar is showing.
        let localDay = model.dayStart.value

        for fraction in [0.0, 0.25, 0.5, 0.75, 0.999] {
            model.scrub(toFractionOfDay: fraction)
            XCTAssertEqual(model.fractionOfDay, fraction, accuracy: 1e-6)
            XCTAssertEqual(model.dayStart.value, localDay, accuracy: 1e-6,
                           "scrubbing to \(fraction) left the local day")
        }

        // Out of range is clamped rather than wrapping into another date.
        model.scrub(toFractionOfDay: 1.8)
        XCTAssertLessThanOrEqual(model.fractionOfDay, 1.0)
        model.scrub(toFractionOfDay: -0.5)
        XCTAssertGreaterThanOrEqual(model.fractionOfDay, 0.0)
    }

    /// Local midnight is local midnight: the bar's left edge is 00:00 on the
    /// site's clock, not on UT.
    func testTheDayStartsAtLocalMidnight() {
        let model = SkyModel()
        model.viewpoint = .stonehenge
        model.time = JulianDay(CalendarDate(year: 2026, month: 6, day: 21, hour: 15))

        // BST is UT+1 in June, so local midnight is 23:00 UT the day before.
        let start = model.dayStart.calendarDate
        let hourUT = (start.day - start.day.rounded(.down)) * 24
        XCTAssertEqual(hourUT, 23, accuracy: 0.02,
                       "local midnight landed at \(hourUT):00 UT")
    }

    /// Deep time has no time zones, so the local day is the solar one.
    func testDeepTimeUsesTheSolarDay() {
        let model = SkyModel()
        model.viewpoint = .stonehenge
        model.time = JulianDay(CalendarDate(year: -2500, month: 7, day: 14, hour: 12))

        XCTAssertEqual(model.clockOffsetHours, GeographicSite.stonehenge.longitude.degrees / 15,
                       accuracy: 1e-9)
        let profile = model.dayProfile(samples: 48)
        XCTAssertEqual(profile.count, 48)
        XCTAssertGreaterThan(profile.max() ?? 0, 55, "midsummer sun in the builders' era")
    }
}
