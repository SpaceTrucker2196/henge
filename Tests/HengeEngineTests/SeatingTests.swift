import XCTest
import simd
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// Every stone stands on the ground it is actually over.
///
/// `MonumentScene` places stones on a flat datum — the archaeology gives a plan
/// position and a height, not a contour under each socket — while the ground
/// mesh is displaced by the real heightfield. Across the monument that is about
/// a metre of relief, which left the outer stones visibly floating.
@MainActor
final class SeatingTests: XCTestCase {

    /// No stone hangs in the air, and none is swallowed.
    func testNoStoneFloatsOrSinks() throws {
        let terrain = try TerrainModel.salisburyPlain()
        let scene = MonumentScene.complete(state: .asItWas)

        // Lintels rest on uprights, not on the ground: an impost's base is
        // legitimately 3.6 m in the air. A stone is ground-founded when its
        // centre sits about half its own height up, which is what separates the
        // two without needing a flag the archaeology does not carry.
        func isGroundFounded(_ stone: Stone) -> Bool {
            Double(stone.position.y) <= stone.height / 2 + 0.3
        }

        var worst = (id: "", gap: 0.0)
        for stone in scene.stones where isGroundFounded(stone) {
            let mesh = HengeRenderer.seat(
                StoneMeshBuilder.build(stone, subdivisions: 6, roughness: 0.02, rounding: 0.2),
                of: stone, on: terrain)
            guard let base = mesh.positions.map(\.y).min() else { continue }

            let ground = Float(terrain.groundHeight(east: Double(stone.position.x),
                                                    south: Double(stone.position.z)))
            let gap = Double(base - ground)

            // Positive is a stone hanging above its ground; negative is one set
            // into it. A socket is fine, a gap never is.
            XCTAssertLessThanOrEqual(gap, 0.02,
                                     "\(stone.id) floats \(gap) m above the turf")
            XCTAssertGreaterThan(gap, -1.2,
                                 "\(stone.id) is buried \(-gap) m deep")
            if abs(gap) > abs(worst.gap) { worst = (stone.id, gap) }
        }
        XCTAssertFalse(scene.stones.isEmpty)
    }

    /// **The regression.** Unseated, the outer stones miss their ground by
    /// enough to see — this asserts the terrain actually varies across the
    /// monument, so the seating is doing work rather than adding zero.
    func testTheGroundIsNotFlatAcrossTheMonument() throws {
        let terrain = try TerrainModel.salisburyPlain()
        let scene = MonumentScene.complete(state: .asItWas)

        let heights = scene.stones.map {
            terrain.groundHeight(east: Double($0.position.x), south: Double($0.position.z))
        }
        let relief = (heights.max() ?? 0) - (heights.min() ?? 0)
        XCTAssertGreaterThan(relief, 0.25,
                             "only \(relief) m of relief — seating would be a no-op "
                             + "and this suite would prove nothing")

        // And unseated meshes really do miss: the failure the fix addresses.
        let outermost = scene.stones
            .filter { Double($0.position.y) <= $0.height / 2 + 0.3 }
            .max { simd_length($0.position) < simd_length($1.position) }!
        let raw = StoneMeshBuilder.build(outermost, subdivisions: 6,
                                         roughness: 0.02, rounding: 0.2)
        let rawBase = Double(raw.positions.map(\.y).min() ?? 0)
        let ground = terrain.groundHeight(east: Double(outermost.position.x),
                                          south: Double(outermost.position.z))
        XCTAssertGreaterThan(abs(rawBase - ground), 0.1,
                             "\(outermost.id) would have sat within 0.1 m by luck")
    }

    /// Flush features stay flush. Sinking a chalk disc puts it under the turf.
    func testChalkDiscsAreNotSunk() throws {
        let terrain = try TerrainModel.salisburyPlain()
        let scene = MonumentScene.complete(state: .asItWas)
        guard let disc = scene.stones.first(where: { $0.material == .chalk }) else {
            throw XCTSkip("no chalk features in this scene")
        }

        let mesh = HengeRenderer.seat(
            StoneMeshBuilder.build(disc, subdivisions: 5, roughness: 0.02, rounding: 0.2),
            of: disc, on: terrain)
        let top = Double(mesh.positions.map(\.y).max() ?? 0)
        let ground = terrain.groundHeight(east: Double(disc.position.x),
                                          south: Double(disc.position.z))
        XCTAssertGreaterThan(top, ground - 0.01, "the Aubrey hole vanished under the turf")
    }
}
