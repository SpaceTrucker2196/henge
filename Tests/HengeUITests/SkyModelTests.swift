import XCTest
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
        let model = SkyModel()
        model.viewpoint = .stonehenge
        model.time = JulianDay(CalendarDate(year: 2026, month: 6, day: 1))
        model.jumpToSunrise(of: .juneSolstice)

        XCTAssertEqual(model.sun.altitude.degrees, 0, accuracy: 1.5,
                       "landed at altitude \(model.sun.altitude.degrees)°")
    }

    /// Zoom is bounded at both ends, in both kinds of view. An unbounded zoom
    /// inverts the projection or turns the camera inside out.
    func testZoomIsBoundedInBothStations() {
        let model = SkyModel()

        model.station = .aerial
        for _ in 0..<200 { model.zoom(by: 1.4) }
        XCTAssertGreaterThanOrEqual(model.cameraDistance, 14)
        for _ in 0..<200 { model.zoom(by: 0.7) }
        XCTAssertLessThanOrEqual(model.cameraDistance, 420)

        model.station = .altarStone
        for _ in 0..<200 { model.zoom(by: 1.4) }
        XCTAssertGreaterThanOrEqual(model.fieldOfView, 24)
        for _ in 0..<200 { model.zoom(by: 0.7) }
        XCTAssertLessThanOrEqual(model.fieldOfView, 96)

        // And a nonsense scale must not corrupt the state.
        let before = model.fieldOfView
        model.zoom(by: 0)
        model.zoom(by: -1)
        XCTAssertEqual(model.fieldOfView, before)
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
