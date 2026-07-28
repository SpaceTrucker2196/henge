import XCTest
@testable import HengeEngine
import HengeGeometry

/// The instance layout, and the scale of the thing it describes.
///
/// Both of these exist because of one bug. `GrassInstance` was declared in MSL
/// with a `packed_float3` root, giving a stride of 40, while Swift's
/// `SIMD3<Float>` made the same struct 48. Every blade after the first read its
/// fields eight bytes off, so heights and widths came out of neighbouring
/// blades' bit patterns and the sward grew to the height of the trilithons.
///
/// Nothing caught it. There is no correctness test a mesh can fail here — the
/// geometry was valid, the winding was right, it drew and it lit. It was simply
/// the wrong size, which only an eye or an assertion about real-world
/// dimensions can notice.
final class GrassLayoutTests: XCTestCase {

    /// Swift and MSL must agree on the instance stride by hand.
    ///
    /// 16 for the root (`SIMD3<Float>` is 16-byte aligned, not 12) plus seven
    /// floats, rounded up to the alignment: 48. If this changes, the MSL struct
    /// changes with it or the field turns to nonsense again.
    func testTheInstanceStrideIsWhatTheShaderExpects() {
        XCTAssertEqual(MemoryLayout<GrassBlade>.stride, 48)
        XCTAssertEqual(MemoryLayout<GrassBlade>.size, 44)
        XCTAssertEqual(MemoryLayout<GrassVertex>.stride, 8)
    }

    /// **Everything is modelled at true scale, in metres.**
    ///
    /// Chalk downland is grazed sward: 4 to 16 cm. Not prairie, not meadow, and
    /// emphatically not a fortieth of a sarsen's height in either direction.
    func testBladesAreTheSizeOfRealGrass() {
        let blades = GrassField.scatter(terrain: nil)
        XCTAssertGreaterThan(blades.count, 5_000)

        let heights = blades.map(\.height)
        XCTAssertGreaterThanOrEqual(heights.min() ?? 0, 0.03, "shorter than a lawn")
        XCTAssertLessThanOrEqual(heights.max() ?? 0, 0.20, "that is a hayfield")

        let widths = blades.map(\.width)
        XCTAssertGreaterThanOrEqual(widths.min() ?? 0, 0.0015)
        XCTAssertLessThanOrEqual(widths.max() ?? 0, 0.006, "that is a leek")

        // Most of the sward is short; the tall ones are the exception.
        let median = heights.sorted()[heights.count / 2]
        XCTAssertLessThan(median, 0.09, "median blade \(median) m")
    }

    /// And the relation the eye actually judges: a blade against a sarsen.
    func testGrassIsTheRightSizeAgainstTheStones() {
        let blades = GrassField.scatter(terrain: nil)
        let tallest = blades.map(\.height).max() ?? 0
        let upright = Monument.sarsenUprightHeight

        let ratio = Double(tallest) / upright
        XCTAssertLessThan(ratio, 0.06,
                          "the tallest blade is \(ratio * 100)% of a sarsen's height")
        XCTAssertGreaterThan(ratio, 0.01, "the grass has vanished")
    }

    /// Blades stay inside the radius they claim, or the fade has nothing to
    /// fade and the field ends at a visible edge.
    func testTheFieldStaysInsideItsRadius() {
        let blades = GrassField.scatter(terrain: nil)
        for blade in blades {
            let distance = (blade.root.x * blade.root.x + blade.root.z * blade.root.z)
                .squareRoot()
            XCTAssertLessThanOrEqual(distance, GrassField.radius + 0.01)
        }
    }

    /// The shared blade mesh is a closed strip ending in a point.
    func testTheBladeMeshIsAStripWithATip() {
        let (vertices, indices) = GrassField.bladeMesh()
        XCTAssertEqual(vertices.count, GrassField.segments * 2 + 1)
        XCTAssertEqual(indices.count % 3, 0)
        XCTAssertEqual(vertices.last?.side, 0, "the tip is a single vertex")
        XCTAssertEqual(vertices.first?.height, 0)
        XCTAssertEqual(vertices.last?.height, 1)
        for index in indices {
            XCTAssertLessThan(Int(index), vertices.count, "index out of range")
        }
    }
}
