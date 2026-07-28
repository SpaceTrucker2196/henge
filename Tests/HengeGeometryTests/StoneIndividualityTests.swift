import XCTest
import simd
@testable import HengeGeometry

/// The stones must be individuals in the mesh, not just in the shading —
/// and must stay inside the envelope the analytic shadow is solved from.
///
/// Appearance faults render correctly and pass every existing test, so per
/// the research note these assertions are about measurable geometry: how far
/// two same-dimension stones differ, and how far any stone may stray from
/// the box the shadow solver believes in.
final class StoneIndividualityTests: XCTestCase {

    private func stone(_ id: String) -> Stone {
        Stone(id: id, position: .zero, height: 7.3, width: 2.4, thickness: 1.1)
    }

    func testTheSameSeedRebuildsTheSameStone() {
        let first = StoneMeshBuilder.build(stone("stone-56"), subdivisions: 8)
        let second = StoneMeshBuilder.build(stone("stone-56"), subdivisions: 8)
        XCTAssertEqual(first.positions.count, second.positions.count)
        for i in first.positions.indices {
            XCTAssertEqual(first.positions[i], second.positions[i],
                           "vertex \(i) moved between two builds of the same "
                           + "stone — the shadow tests depend on this never "
                           + "happening")
        }
    }

    func testDifferentStonesAreDifferentSolids() {
        // Same dimensions, same subdivisions — the only thing that differs is
        // the seed, so any difference below is the mesh's own individuality.
        // The box-grid topology is identical, so vertices correspond by index.
        let ids = ["stone-1", "stone-2", "stone-3", "stone-9", "stone-17"]
        let meshes = ids.map { StoneMeshBuilder.build(stone($0), subdivisions: 8) }

        for i in 0..<meshes.count {
            for j in (i + 1)..<meshes.count {
                var sum = 0.0
                for k in meshes[i].positions.indices {
                    sum += Double(simd_length_squared(meshes[i].positions[k]
                                                      - meshes[j].positions[k]))
                }
                let rms = (sum / Double(meshes[i].positions.count)).squareRoot()
                // Centimetres of solid difference, not texels of coat. The
                // floor is deliberately far below the amplitude range so a
                // future retuning of the ranges cannot flake it, and far
                // above float noise.
                XCTAssertGreaterThan(rms, 0.015,
                                     "\(ids[i]) and \(ids[j]) differ by an RMS "
                                     + "of \(rms) m — same rock, different coat")
            }
        }
    }

    func testEveryStoneStaysInsideTheShadowSolversEnvelope() {
        // The analytic shadow is cast from the stone's bounding box. The
        // displacement is bounded by construction (rockField is normalised,
        // amplitude tops out at 1.25 × the 0.06 base), so no vertex may
        // stand further than that bound off the nominal box — if one does,
        // the mesh and the mathematics have started describing different
        // stones.
        let ceiling = 0.06 * 1.25 * 2 * 0.55 + 0.01   // amplitude bound + weld slack
        for id in ["stone-1", "stone-11", "stone-23", "stone-30"] {
            let probe = stone(id)
            let mesh = StoneMeshBuilder.build(probe, subdivisions: 8)
            for p in mesh.positions {
                XCTAssertLessThan(abs(Double(p.x)) - probe.width / 2, ceiling,
                                  "\(id): a vertex stands \(p.x) from centre")
                XCTAssertLessThan(abs(Double(p.z)) - probe.thickness / 2, ceiling,
                                  "\(id): a vertex stands \(p.z) through the face")
                XCTAssertLessThan(Double(p.y) - probe.height, ceiling,
                                  "\(id): the crown overtops the nominal height")
            }
        }
    }

    func testTheCalibrationBuildIsTheExactBox() {
        // The shadow-agreement oracle builds at roughness 0, rounding 0 and
        // measures against the analytic box. Every per-stone liberty — arris,
        // displacement, taper — must vanish with those knobs, or the oracle
        // is comparing the mathematics to a stone it never described.
        let probe = stone("gnomon")
        let mesh = StoneMeshBuilder.build(probe, subdivisions: 6,
                                          roughness: 0, rounding: 0)
        var maxX: Float = 0, maxZ: Float = 0, maxY: Float = 0
        for p in mesh.positions {
            maxX = max(maxX, abs(p.x))
            maxZ = max(maxZ, abs(p.z))
            maxY = max(maxY, p.y)
        }
        XCTAssertEqual(Double(maxX), probe.width / 2, accuracy: 1e-6)
        XCTAssertEqual(Double(maxZ), probe.thickness / 2, accuracy: 1e-6)
        XCTAssertEqual(Double(maxY), probe.height, accuracy: 1e-6)
    }

    func testTheDisplacementFieldIsBounded() {
        // rockField feeds an amplitude that the envelope test above turns
        // into a promise to the shadow solver, so its bound is asserted
        // directly: normalised octaves with weights clamped to [0, 1] can
        // never leave [-1, 1].
        var noise = ValueNoise(seed: 0xDEADBEEF)
        for i in 0..<2000 {
            let p = SIMD3(Double(i % 17) * 0.37, Double(i % 23) * 0.29,
                          Double(i % 31) * 0.41)
            let value = noise.rockField(p)
            XCTAssertLessThanOrEqual(abs(value), 1.0,
                                     "rockField(\(p)) = \(value) escaped its bound")
        }
    }
}
