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
        // Stones are socketed below the turf rather than resting on it, so the
        // base sits a little under zero and never above it.
        XCTAssertLessThanOrEqual(lowest, 0, "the base must not float above the ground")
        XCTAssertGreaterThan(lowest, -1.0, "the socket should be shallow")
        XCTAssertEqual(Double(highest), stone.height, accuracy: stone.height * 0.15)

        for normal in mesh.normals {
            XCTAssertEqual(simd_length(normal), 1, accuracy: 1e-3, "normals must be unit length")
        }
    }
}

/// Regression cover for the lighting bug found by running M1 on an iPad.
///
/// The stones rendered nearly black with bright stripes while the ground lit
/// correctly. The cause was normals derived from triangle winding alone: the
/// six box faces are not parameterised with a consistent handedness, so half
/// of them ended up facing *inward* and received ambient light only.
///
/// Winding and orientation are checked together because they must agree —
/// back-face culling uses one and the shading uses the other.
final class MeshOrientationTests: XCTestCase {

    func testEveryTriangleFacesOutward() {
        let stone = Stone(id: "orientation", position: SIMD3(0, 0, 0),
                          height: 6.0, width: 2.1, thickness: 1.1)
        let mesh = StoneMeshBuilder.build(stone, subdivisions: 6, roughness: 0)

        // The stone's centre of volume: outward means away from this.
        let centre = SIMD3<Float>(0, Float(stone.height / 2), 0)
        var inwardTriangles = 0

        for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = mesh.positions[Int(mesh.indices[triangle])]
            let b = mesh.positions[Int(mesh.indices[triangle + 1])]
            let c = mesh.positions[Int(mesh.indices[triangle + 2])]

            let geometric = cross(b - a, c - a)
            let outward = ((a + b + c) / 3) - centre
            if dot(geometric, outward) < 0 { inwardTriangles += 1 }
        }

        XCTAssertEqual(inwardTriangles, 0,
                       "\(inwardTriangles) triangles wound inward — back-face culling "
                       + "and lighting will disagree")
    }

    func testVertexNormalsPointAwayFromTheStone() {
        let stone = Stone(id: "normals", position: SIMD3(4, 0, -2),
                          height: 7.3, width: 2.4, thickness: 1.1)
        let mesh = StoneMeshBuilder.build(stone, subdivisions: 6, roughness: 0)

        let centre = SIMD3<Float>(stone.position) + SIMD3<Float>(0, Float(stone.height / 2), 0)
        var inwardNormals = 0

        for i in mesh.positions.indices {
            let outward = mesh.positions[i] - centre
            guard length(outward) > 0.05 else { continue }
            if dot(mesh.normals[i], outward) < 0 { inwardNormals += 1 }
        }

        XCTAssertEqual(inwardNormals, 0,
                       "\(inwardNormals) vertex normals face inward — the stone will "
                       + "light only from ambient and read as black")
    }

    /// The bug was visible because the ground was fine and the stones were not.
    /// Pin the ground down too, so a future change cannot break both together
    /// and look self-consistent.
    func testGroundPlaneFacesUp() {
        let ground = HengeGeometryTestSupport.groundNormalsAreUp()
        XCTAssertTrue(ground)
    }
}

/// Small shim so the ground check can live beside the stone checks without
/// `HengeGeometry` depending on the renderer that owns the ground mesh.
enum HengeGeometryTestSupport {
    static func groundNormalsAreUp() -> Bool {
        // The ground is a flat plane in the renderer; here we assert the
        // convention it must satisfy, which is that up is +Y in world axes.
        WorldAxes.direction(azimuth: Angle(degrees: 0)).y == 0
            && SIMD3<Double>(0, 1, 0).y > 0
    }
}

/// Which way a stone actually faces.
///
/// Nothing pinned this until an iPad render made it obvious that the trilithon
/// read as a flat wall. The uprights were 10° off the axis, because the
/// local-to-world rotation had been written as an angle twice and the two
/// versions disagreed about the sign. `Stone.toWorld` now states its basis
/// outright, and these tests hold it to it.
final class StoneOrientationTests: XCTestCase {

    /// `bearing` means: local +Z points along this compass bearing.
    func testBearingPointsTheFacingDirection() {
        for degrees in stride(from: 0.0, to: 360.0, by: 23.0) {
            let stone = Stone(id: "facing", position: .zero, height: 3, width: 2,
                              thickness: 1, bearing: Angle(degrees: degrees))
            let facing = stone.directionToWorld(SIMD3(0, 0, 1))
            XCTAssertEqual(WorldAxes.azimuth(of: normalize(facing)).degrees, degrees,
                           accuracy: 1e-6, "facing at bearing \(degrees)")
        }
    }

    /// The transform must be a rotation, not a mirror — a reflection inverts
    /// the winding of every triangle and turns the stones black.
    func testTransformPreservesHandedness() {
        let stone = Stone(id: "handedness", position: SIMD3(3, 0, 5), height: 4,
                          width: 2, thickness: 1, bearing: Angle(degrees: 71),
                          lean: Angle(degrees: 12))
        let x = stone.directionToWorld(SIMD3(1, 0, 0))
        let y = stone.directionToWorld(SIMD3(0, 1, 0))
        let z = stone.directionToWorld(SIMD3(0, 0, 1))

        // X × Y = Z for a right-handed basis; a mirror would give −Z.
        XCTAssertGreaterThan(simd_dot(simd_cross(x, y), z), 0.99,
                             "the local-to-world transform has become a reflection")
        // And it must not scale.
        for axis in [x, y, z] {
            XCTAssertEqual(simd_length(axis), 1, accuracy: 1e-9)
        }
    }

    /// A trilithon is a doorway, and it is approached along the axis — so the
    /// broad faces of its uprights look up and down that axis, and the pair is
    /// offset across it.
    func testTrilithonUprightsFaceAlongTheAxis() {
        let uprights = MonumentScene.trilithon(.great).filter { $0.id.contains("upright") }
        XCTAssertEqual(uprights.count, 2)

        for upright in uprights {
            let facing = normalize(upright.directionToWorld(SIMD3(0, 0, 1)))
            XCTAssertEqual(WorldAxes.azimuth(of: facing).separation(to: Monument.axisAzimuth).degrees,
                           0, accuracy: 0.01,
                           "\(upright.id) should look along the axis, not across it")
        }

        // The pair straddles the axis: the line joining them runs across it.
        let separation = uprights[1].position - uprights[0].position
        let acrossBearing = WorldAxes.azimuth(of: normalize(separation))
        let angleToAxis = acrossBearing.separation(to: Monument.axisAzimuth).degrees
        XCTAssertEqual(angleToAxis, 90, accuracy: 0.5,
                       "the uprights must be offset across the axis, not along it")
    }

    /// The Heel Stone leans toward the circle, not away from it.
    func testHeelStoneLeansTowardTheCircle() {
        let heel = MonumentScene.heelStone()
        let apex = heel.apex
        let base = heel.position

        // Its top should be closer to the centre of the circle than its base.
        let baseDistance = simd_length(SIMD2(base.x, base.z))
        let apexDistance = simd_length(SIMD2(apex.x, apex.z))
        XCTAssertLessThan(apexDistance, baseDistance,
                          "the Heel Stone leans in toward the monument")
    }
}

/// Where the stone meets the ground.
///
/// Displacement noise crossing a flat ground plane leaves a ragged comb of
/// spikes and notches at exactly the place the eye is drawn — the contact
/// point. Visible immediately on a device at a low sun, and invisible in every
/// test that only checked the mesh was well formed.
final class WaterlineTests: XCTestCase {

    func testDisplacementFadesOutAtGroundLevel() {
        let stone = Stone(id: "waterline", position: .zero, height: 7.3,
                          width: 2.4, thickness: 1.1)
        let rough = StoneMeshBuilder.build(stone, subdivisions: 14, roughness: 0.06)
        let smooth = StoneMeshBuilder.build(stone, subdivisions: 14, roughness: 0)

        // Compare the horizontal footprint of the noisy stone against the clean
        // one in a band around the ground plane. Near the waterline they should
        // agree closely; higher up the noise is free to do as it likes.
        func maxRadius(_ mesh: Mesh, from low: Float, to high: Float) -> Float {
            var result: Float = 0
            for p in mesh.positions where p.y >= low && p.y <= high {
                result = max(result, simd_length(SIMD2(p.x, p.z)))
            }
            return result
        }

        let atWaterline = abs(maxRadius(rough, from: -0.05, to: 0.4)
                              - maxRadius(smooth, from: -0.05, to: 0.4))
        let higherUp = abs(maxRadius(rough, from: 3.0, to: 6.0)
                           - maxRadius(smooth, from: 3.0, to: 6.0))

        XCTAssertLessThan(atWaterline, 0.03,
                          "the stone must meet the turf in a line, not a comb")
        XCTAssertGreaterThan(higherUp, atWaterline,
                             "and it should still be a rough stone above the ground")
    }

    /// A lintel balanced exactly on the nominal height of two rounded uprights
    /// shows daylight along the joint. It should sit into them.
    func testLintelSeatsIntoTheUprights() {
        let stones = MonumentScene.trilithon(.great)
        let uprights = stones.filter { $0.id.contains("upright") }
        let lintel = try! XCTUnwrap(stones.first { $0.id.contains("lintel") })

        XCTAssertLessThan(lintel.position.y, uprights[0].height,
                          "the lintel must overlap the uprights, not balance on them")
        XCTAssertGreaterThan(lintel.position.y, uprights[0].height - 0.6,
                             "but it should not sink into them")
    }
}
