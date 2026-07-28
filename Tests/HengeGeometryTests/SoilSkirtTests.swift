import XCTest
import simd
@testable import HengeGeometry
import HengeAstro

final class SoilSkirtTests: XCTestCase {

    private func upright(id: String = "s", seed: UInt64 = 1) -> Stone {
        Stone(id: id, position: SIMD3(0, 2.1, 0), height: 4.2, width: 2.1,
              thickness: 1.1, bearing: Angle(degrees: 30), material: .sarsen, seed: seed)
    }

    /// The mound hugs a rectangular stone rather than ringing it in a circle.
    ///
    /// A constant radius leaves soil floating clear of the long faces and
    /// buried at the corners, which is more obviously wrong than no mound.
    func testTheFootprintFollowsTheBoxNotACircle() {
        let along = SoilSkirt.boxRadius(halfWidth: 1.0, halfThickness: 0.4, angle: .pi / 2)
        let across = SoilSkirt.boxRadius(halfWidth: 1.0, halfThickness: 0.4, angle: 0)
        XCTAssertEqual(along, 1.0, accuracy: 1e-4)
        XCTAssertEqual(across, 0.4, accuracy: 1e-4)

        // Never smaller than the inradius, never larger than the diagonal.
        for step in 0..<64 {
            let angle = Float(step) / 64 * 2 * .pi
            let r = SoilSkirt.boxRadius(halfWidth: 1.0, halfThickness: 0.4, angle: angle)
            XCTAssertGreaterThanOrEqual(r, 0.4 - 1e-4, "angle \(angle)")
            XCTAssertLessThanOrEqual(r, sqrt(1.0 + 0.16) + 1e-4, "angle \(angle)")
        }
    }

    /// **Not uniform.** The whole point is irregularity: the outer edge must
    /// vary substantially around one stone, or it is a washer.
    func testOneMoundIsIrregularAroundItsStone() {
        let stone = upright()
        let mesh = SoilSkirt.build(around: stone)
        XCTAssertFalse(mesh.indices.isEmpty)

        // Odd vertices are the outer ring.
        let outer = stride(from: 1, to: mesh.positions.count, by: 2).map { mesh.positions[$0] }
        let radii = outer.map { simd_length(SIMD2($0.x, $0.z)) }
        let spread = (radii.max() ?? 0) - (radii.min() ?? 0)
        XCTAssertGreaterThan(spread, 0.15,
                             "the outer edge varies by only \(spread) m — that is a collar")

        // And the height varies too, not just the reach.
        let inner = stride(from: 0, to: mesh.positions.count, by: 2).map { mesh.positions[$0].y }
        XCTAssertGreaterThan((inner.max() ?? 0) - (inner.min() ?? 0), 0.02)
    }

    /// **And no two alike.** Seeded per stone, so a circle of thirty does not
    /// wear thirty identical collars.
    func testNoTwoMoundsAreTheSame() {
        let shapes = (1...12).map { seed -> [Float] in
            let mesh = SoilSkirt.build(around: upright(id: "s\(seed)", seed: UInt64(seed)))
            return stride(from: 1, to: mesh.positions.count, by: 2)
                .map { simd_length(SIMD2(mesh.positions[$0].x, mesh.positions[$0].z)) }
        }
        for (i, a) in shapes.enumerated() {
            for b in shapes[(i + 1)...] {
                let difference = zip(a, b).map { abs($0 - $1) }.max() ?? 0
                XCTAssertGreaterThan(difference, 0.02, "two stones share a mound")
            }
        }
    }

    /// It is stable between runs. A sward or a soil bank that reshuffles itself
    /// on every launch is a flicker, and makes every render test unrepeatable.
    func testTheSameStoneAlwaysGetsTheSameMound() {
        let a = SoilSkirt.build(around: upright(seed: 77))
        let b = SoilSkirt.build(around: upright(seed: 77))
        XCTAssertEqual(a.positions, b.positions)
    }

    /// Nothing gathers round a lintel: it is three metres in the air.
    func testLintelsAndFlushFeaturesGetNoSoil() {
        let lintel = Stone(id: "lintel", position: SIMD3(0, 4.1, 0), height: 0.8,
                           width: 3.2, thickness: 1.0, material: .sarsen)
        XCTAssertTrue(SoilSkirt.build(around: lintel).indices.isEmpty)
        XCTAssertFalse(SoilSkirt.isGroundFounded(lintel))

        let disc = Stone(id: "aubrey", position: SIMD3(0, 0.05, 0), height: 0.1,
                         width: 1.8, thickness: 1.8, material: .chalk)
        XCTAssertTrue(SoilSkirt.build(around: disc).indices.isEmpty)
    }

    /// The mound follows the contour rather than sitting on a flat disc — on a
    /// slope the uphill side really is buried deeper.
    func testTheMoundFollowsTheGround() {
        let slope: (Float, Float) -> Float = { x, _ in x * 0.15 }
        let mesh = SoilSkirt.build(around: upright(), groundHeight: slope)
        let outer = stride(from: 1, to: mesh.positions.count, by: 2).map { mesh.positions[$0] }

        for point in outer {
            XCTAssertEqual(point.y, slope(point.x, point.z), accuracy: 0.02,
                           "the outer edge left the ground at x \(point.x)")
        }
    }

    /// Every mound is a closed strip with consistent winding — the convention
    /// this project learned the hard way, and which a new mesh is the easiest
    /// place to get wrong again.
    func testTheStripIsWoundLikeEverythingElse() {
        let mesh = SoilSkirt.build(around: upright())
        XCTAssertEqual(mesh.indices.count % 3, 0)

        var upward = 0
        for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = mesh.positions[Int(mesh.indices[triangle])]
            let b = mesh.positions[Int(mesh.indices[triangle + 1])]
            let c = mesh.positions[Int(mesh.indices[triangle + 2])]
            if simd_cross(b - a, c - a).y > 0 { upward += 1 }
        }
        let total = mesh.indices.count / 3
        XCTAssertEqual(upward, total,
                       "\(total - upward) of \(total) triangles face downward")
    }
}
