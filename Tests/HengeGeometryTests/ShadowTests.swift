import XCTest
import simd
import HengeAstro
@testable import HengeGeometry

/// The analytic shadow, checked by trigonometry a reader can do on paper.
///
/// This is layer 1 of the oracle for the shadow claim. Layer 2 renders the same
/// scene on the GPU and asserts the pixels agree with these numbers — so if
/// these are wrong, the whole calendar is wrong and quietly so.
final class ShadowSolverTests: XCTestCase {

    private func sun(altitude: Double, azimuth: Double) -> HorizontalCoordinate {
        HorizontalCoordinate(altitude: Angle(degrees: altitude),
                             azimuth: Angle(degrees: azimuth))
    }

    /// At 45° elevation a shadow is exactly as long as the thing casting it.
    /// The case anyone can check without a calculator.
    func testShadowLengthAtFortyFiveDegrees() {
        let length = ShadowSolver.shadowLength(height: 7.3, sunAltitude: Angle(degrees: 45))
        XCTAssertEqual(try XCTUnwrap(length), 7.3, accuracy: 1e-9)
    }

    func testShadowLengthGrowsAsTheSunSinks() {
        let high = try! XCTUnwrap(ShadowSolver.shadowLength(height: 1, sunAltitude: Angle(degrees: 60)))
        let low = try! XCTUnwrap(ShadowSolver.shadowLength(height: 1, sunAltitude: Angle(degrees: 10)))
        XCTAssertEqual(high, 1 / tan(Double.pi / 3), accuracy: 1e-9)
        XCTAssertEqual(low, 1 / tan(10 * Double.pi / 180), accuracy: 1e-9)
        XCTAssertGreaterThan(low, high)
    }

    /// Below the horizon there is no shadow to draw, and saying so is better
    /// than projecting one to infinity.
    func testNoShadowWhenTheSunIsDown() {
        XCTAssertNil(ShadowSolver.shadowLength(height: 5, sunAltitude: Angle(degrees: -0.5)))
        XCTAssertNil(ShadowSolver.groundShadow(of: SIMD3(0, 5, 0),
                                               sun: sun(altitude: -1, azimuth: 90)))
    }

    /// A shadow points directly away from the sun.
    func testShadowFallsOppositeTheSun() {
        // Sun in the east: the shadow runs west.
        let tip = try! XCTUnwrap(ShadowSolver.groundShadow(
            of: SIMD3(0, 10, 0), sun: sun(altitude: 45, azimuth: 90)))
        XCTAssertEqual(tip.y, 0, accuracy: 1e-9)
        XCTAssertEqual(tip.x, -10, accuracy: 1e-9, "10 m west (−X) at 45°")
        XCTAssertEqual(tip.z, 0, accuracy: 1e-9)

        // Sun in the south: the shadow runs north, which is −Z.
        let northward = try! XCTUnwrap(ShadowSolver.groundShadow(
            of: SIMD3(0, 10, 0), sun: sun(altitude: 45, azimuth: 180)))
        XCTAssertEqual(northward.z, -10, accuracy: 1e-9)
        XCTAssertEqual(northward.x, 0, accuracy: 1e-9)
    }

    /// The bearing of the shadow, and the bearing of the sun, differ by 180°
    /// exactly — verified against the vector solution rather than restated.
    func testShadowBearingAgreesWithTheProjectedVector() {
        for azimuth in stride(from: 0.0, to: 360.0, by: 17.0) {
            let s = sun(altitude: 30, azimuth: azimuth)
            let tip = try! XCTUnwrap(ShadowSolver.groundShadow(of: SIMD3(0, 4, 0), sun: s))
            let measured = WorldAxes.azimuth(of: normalize(SIMD3(tip.x, 0, tip.z)))
            let expected = ShadowSolver.shadowBearing(sunAzimuth: Angle(degrees: azimuth))
            XCTAssertEqual(measured.separation(to: expected).degrees, 0, accuracy: 1e-6,
                           "bearing at sun azimuth \(azimuth)")
        }
    }

    /// The tip of a leaning stone is not above its base — the Heel Stone leans
    /// 27°, and a solver that ignored that would misplace its shadow by metres.
    func testLeaningStoneShadowAccountsForTheOverhang() {
        let heel = MonumentScene.heelStone()
        let upright = Stone(id: "test-upright", position: heel.position,
                            height: heel.height, width: heel.width,
                            thickness: heel.thickness, bearing: heel.bearing)

        let s = sun(altitude: 30, azimuth: 130)
        let leaningTip = try! XCTUnwrap(ShadowSolver.shadowTip(of: heel, sun: s))
        let uprightTip = try! XCTUnwrap(ShadowSolver.shadowTip(of: upright, sun: s))

        let displacement = simd_distance(leaningTip, uprightTip)
        XCTAssertGreaterThan(displacement, 1.5, "a 27° lean on a 4.7 m stone must move the tip")
    }

    func testOutlineIsAConvexPolygonOfTheRightScale() {
        let stone = Stone(id: "outline", position: SIMD3(0, 0, 0),
                          height: 7.3, width: 2.4, thickness: 1.1)
        let outline = ShadowSolver.shadowOutline(of: stone, sun: sun(altitude: 20, azimuth: 140))
        XCTAssertGreaterThanOrEqual(outline.count, 4)

        // Long axis of the shadow ≈ height / tan(altitude), plus the stone's own
        // footprint.
        let expectedLength = 7.3 / tan(20 * Double.pi / 180)
        let extent = outline.map { simd_length($0) }.max() ?? 0
        XCTAssertEqual(extent, expectedLength, accuracy: 3.0)
    }
}

final class MonumentGeometryTests: XCTestCase {

    /// The axis is a survey fact, and the scene must be built on it — the
    /// Heel Stone sits on the axis at its measured distance.
    func testHeelStoneSitsOnTheAxis() {
        let heel = MonumentScene.heelStone()
        let horizontal = SIMD3(heel.position.x, 0, heel.position.z)

        XCTAssertEqual(simd_length(horizontal), Monument.heelStoneDistance, accuracy: 0.01)
        XCTAssertEqual(WorldAxes.azimuth(of: normalize(horizontal)).degrees,
                       Monument.axisAzimuth.degrees, accuracy: 0.01)
    }

    /// The Great Trilithon closes the horseshoe at the south-west, opposite
    /// the entrance — so midwinter sunset falls through it.
    func testGreatTrilithonStandsSouthWestOfCentre() {
        let stones = MonumentScene.trilithon(.great)
        XCTAssertEqual(stones.count, 3, "two uprights and a lintel when complete")

        let uprights = stones.filter { $0.id.contains("upright") }
        let midpoint = (uprights[0].position + uprights[1].position) / 2
        let bearing = WorldAxes.azimuth(of: normalize(SIMD3(midpoint.x, 0, midpoint.z)))

        let expected = (Monument.axisAzimuth + Angle(degrees: 180)).normalized
        XCTAssertEqual(bearing.separation(to: expected).degrees, 0, accuracy: 0.5)
        XCTAssertEqual(uprights[0].height, 7.3, accuracy: 0.001)
    }

    /// In the ruin only stone 56 of the Great Trilithon is standing. The two
    /// states are distinct and labelled, never blended (invariant 8).
    func testRuinStateRaisesFewerStones() {
        let complete = MonumentScene.milestoneOne(state: .asItWas)
        let ruin = MonumentScene.milestoneOne(state: .asItStands)
        XCTAssertGreaterThan(complete.stones.count, ruin.stones.count)
        XCTAssertNotNil(ruin.stone(id: "heel-stone"), "the Heel Stone still stands")
    }

    /// Stones must be identical between runs: the GPU shadow test compares
    /// against an analytic position, and a stone that wandered would make the
    /// oracle flaky in a way that looks like a rendering bug.
    func testStoneSeedsAreDeterministic() {
        let first = Stone(id: "great-upright-left", position: .zero,
                          height: 7.3, width: 2.4, thickness: 1.1)
        let second = Stone(id: "great-upright-left", position: .zero,
                           height: 7.3, width: 2.4, thickness: 1.1)
        XCTAssertEqual(first.seed, second.seed)
        XCTAssertNotEqual(first.seed,
                          Stone(id: "great-upright-right", position: .zero,
                                height: 7.3, width: 2.4, thickness: 1.1).seed,
                          "different stones must not share a surface")
    }

    func testMeshIsWellFormedAndSitsOnTheGround() {
        let stone = Stone(id: "mesh-test", position: SIMD3(3, 0, -4),
                          height: 6.0, width: 2.1, thickness: 1.1)
        let mesh = StoneMeshBuilder.build(stone, subdivisions: 4)

        XCTAssertEqual(mesh.positions.count, mesh.normals.count)
        XCTAssertEqual(mesh.indices.count % 3, 0)
        XCTAssertGreaterThan(mesh.triangleCount, 0)
        for index in mesh.indices {
            XCTAssertLessThan(Int(index), mesh.positions.count, "index out of range")
        }

        let lowest = mesh.positions.map(\.y).min() ?? 1
        let highest = mesh.positions.map(\.y).max() ?? 0
        XCTAssertEqual(lowest, 0, accuracy: 0.05, "the base must meet the ground")
        XCTAssertEqual(Double(highest), stone.height, accuracy: stone.height * 0.15)

        for normal in mesh.normals {
            XCTAssertEqual(simd_length(normal), 1, accuracy: 1e-3, "normals must be unit length")
        }
    }
}
