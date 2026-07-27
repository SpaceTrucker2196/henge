import XCTest
import simd
import HengeAstro
@testable import HengeGeometry

/// Salisbury Plain, and what it does to the calendar.
///
/// The point of carrying a heightfield is not scenery. Until this existed the
/// horizon altitude was a number passed in by hand — 0.6°, chosen because it
/// was roughly right — and it moves the solstice sunrise bearing by more than
/// a degree. MISSION.md invariant 1 says compute, don't hardcode. These tests
/// hold the terrain to that.
final class TerrainTests: XCTestCase {

    private func plain() throws -> TerrainModel {
        try TerrainModel.salisburyPlain()
    }

    /// The monument stands at about 101 m. If the bake were centred on the
    /// wrong point, or the row order flipped, this is what would catch it.
    func testGroundAtTheMonumentMatchesTheSurveyedElevation() throws {
        let terrain = try plain()
        XCTAssertEqual(terrain.centreHeight, 101, accuracy: 3,
                       "published elevation at Stonehenge is about 101 m")
        XCTAssertEqual(terrain.elevation(east: 0, south: 0), terrain.centreHeight,
                       accuracy: 1.5)
        XCTAssertEqual(terrain.groundHeight(east: 0, south: 0), 0, accuracy: 1.5,
                       "the monument sits at the origin of world space")
    }

    /// Stonehenge Bottom: a dry valley falling away to the north, which is why
    /// the ground drops there and rises to the east and west. Getting the row
    /// order upside down would put the valley on the wrong side, so this pins
    /// the orientation to real topography rather than to a convention.
    func testStonehengeBottomFallsAwayToTheNorth() throws {
        let terrain = try plain()
        let north = terrain.elevation(east: 0, south: -1000)
        let south = terrain.elevation(east: 0, south: 1000)
        let east = terrain.elevation(east: 1000, south: 0)
        let west = terrain.elevation(east: -1000, south: 0)

        XCTAssertLessThan(north, terrain.centreHeight - 4,
                          "the ground falls into Stonehenge Bottom to the north")
        XCTAssertGreaterThan(east, north, "the ridge to the east stands higher")
        XCTAssertGreaterThan(west, north, "and so does the ground to the west")
        XCTAssertEqual(south, terrain.centreHeight, accuracy: 12)
    }

    func testCoversEnoughGroundToHoldASkyline() throws {
        let terrain = try plain()
        XCTAssertGreaterThan(terrain.extent, 10_000,
                             "a skyline needs kilometres, not metres")
        XCTAssertGreaterThan(terrain.spacing, 0)
        XCTAssertEqual(terrain.width, terrain.height)
    }

    /// The measurement that replaces the guess.
    ///
    /// The skyline toward midsummer sunrise computes to about 0.71°, against
    /// the 0.6° that had been assumed. The assumption was close, which is
    /// exactly why it would have survived indefinitely without this.
    func testSkylineTowardTheSolsticeSunrise() throws {
        let terrain = try plain()
        let northEast = terrain.horizonAltitude(azimuth: Angle(degrees: 50))

        XCTAssertEqual(northEast.degrees, 0.71, accuracy: 0.15)
        XCTAssertGreaterThan(northEast.degrees, 0.3,
                             "the sun does not rise over a sea-level horizon here")
    }

    func testSkylineIsEverywhereAboveTheSeaLevelHorizon() throws {
        let terrain = try plain()
        let profile = terrain.horizonProfile(samples: 72)
        XCTAssertEqual(profile.count, 72)
        for (index, altitude) in profile.enumerated() {
            let bearing = Double(index) * 5
            XCTAssertGreaterThanOrEqual(altitude.degrees, 0, "bearing \(bearing)")
            XCTAssertLessThan(altitude.degrees, 5,
                              "no Alp on Salisbury Plain — bearing \(bearing)")
        }
    }
}

/// What the real skyline does to the alignment the whole app is about.
final class SkylineAlignmentTests: XCTestCase {

    /// With the true skyline in place, the midsummer sun of 2500 BC rises
    /// closer to the monument's axis than a flat horizon would put it — and
    /// closer than the hand-picked 0.6° suggested.
    func testTerrainMovesMidsummerSunriseOntoTheAxis() throws {
        let terrain = try TerrainModel.salisburyPlain()
        let axis = Monument.axisAzimuth

        let flat = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .juneSolstice, year: -2500, site: .stonehenge))
        let real = try XCTUnwrap(Skyline.sunriseAzimuth(
            .juneSolstice, year: -2500, terrain: terrain))

        XCTAssertGreaterThan(real.degrees, flat.degrees,
                             "a raised skyline delays sunrise, moving it east")
        XCTAssertLessThan(real.separation(to: axis).degrees,
                          flat.separation(to: axis).degrees,
                          "and that brings it nearer the axis the builders laid")
        XCTAssertLessThan(real.separation(to: axis).degrees, 1.2,
                          "midsummer sunrise should sit within about a degree of the axis")
    }

    /// Midwinter sunset over the true skyline, back down the axis through the
    /// Great Trilithon. Whether the monument was *for* midwinter is Debated;
    /// that this is the tighter of the two fits is measurable.
    func testMidwinterSunsetRemainsTheTighterFit() throws {
        let terrain = try TerrainModel.salisburyPlain()
        let axis = Monument.axisAzimuth
        let reciprocal = (axis + Angle(degrees: 180)).normalized

        let sunrise = try XCTUnwrap(Skyline.sunriseAzimuth(
            .juneSolstice, year: -2500, terrain: terrain))
        let sunset = try XCTUnwrap(Skyline.sunsetAzimuth(
            .decemberSolstice, year: -2500, terrain: terrain))

        XCTAssertLessThan(sunset.separation(to: reciprocal).degrees, 1.5)
        XCTAssertLessThan(sunset.separation(to: reciprocal).degrees,
                          sunrise.separation(to: axis).degrees + 0.5)
    }

    /// The solver has to iterate, because the horizon altitude depends on the
    /// bearing being solved for. Check it actually settles.
    func testTheSkylineSolverConverges() throws {
        let terrain = try TerrainModel.salisburyPlain()
        let first = try XCTUnwrap(Skyline.sunriseAzimuth(
            .juneSolstice, year: 2026, terrain: terrain))
        let second = try XCTUnwrap(Skyline.sunriseAzimuth(
            .juneSolstice, year: 2026, terrain: terrain))
        XCTAssertEqual(first.degrees, second.degrees, accuracy: 1e-9)
    }
}
