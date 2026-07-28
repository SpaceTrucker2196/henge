import XCTest
import simd
import HengeAstro
@testable import HengeGeometry

/// The geometry overlay, checked as geometry: the lines must lie on the
/// ground they claim to be drawn on, run the bearings they claim to run, and
/// the gold markers must stand on the Aubrey circle where the ephemeris —
/// not a script — puts them.
final class OverlayTests: XCTestCase {

    /// A deliberately lumpy synthetic ground, so "follows the terrain" is a
    /// real claim rather than a test against a flat plane.
    private func hill(_ east: Double, _ south: Double) -> Double {
        0.03 * east + 0.6 * sin(south * 0.21)
    }

    private func centroid(_ mesh: Mesh) -> SIMD3<Double> {
        var sum = SIMD3<Double>.zero
        for p in mesh.positions { sum += SIMD3<Double>(p) }
        return sum / Double(max(mesh.positions.count, 1))
    }

    func testRibbonsFollowTheGround() {
        let mesh = GeometryOverlay.ribbon(from: SIMD2(-40, 10), to: SIMD2(35, -50),
                                          ground: hill)
        XCTAssertGreaterThan(mesh.triangleCount, 20)
        for p in mesh.positions {
            let expected = hill(Double(p.x), Double(p.z)) + GeometryOverlay.lift
            XCTAssertEqual(Double(p.y), expected, accuracy: 1e-4,
                           "a ribbon vertex floats \(Double(p.y) - expected) m "
                           + "off the terrain at (\(p.x), \(p.z))")
        }
    }

    func testRibbonTrianglesFaceUp() {
        let mesh = GeometryOverlay.ribbon(from: SIMD2(0, 0), to: SIMD2(50, 0),
                                          ground: { _, _ in 0 })
        for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = mesh.positions[Int(mesh.indices[triangle])]
            let b = mesh.positions[Int(mesh.indices[triangle + 1])]
            let c = mesh.positions[Int(mesh.indices[triangle + 2])]
            XCTAssertGreaterThan(cross(b - a, c - a).y, 0,
                                 "overlay ribbon wound downward — back-face "
                                 + "culling would erase it")
        }
    }

    func testCardinalStrokesPointWhereTheyClaim() {
        let pieces = GeometryOverlay.surveyPieces(ground: { _, _ in 0 })
        // World axes: +X east, +Z south. North is therefore −Z.
        let north = try! XCTUnwrap(pieces.first { $0.name == "cardinal North" })
        for p in north.mesh.positions {
            XCTAssertEqual(Double(p.x), 0, accuracy: 0.3)
            XCTAssertLessThan(p.z, -47, "north stroke strayed south of its band")
            XCTAssertGreaterThan(p.z, -59)
        }
        let east = try! XCTUnwrap(pieces.first { $0.name == "cardinal East" })
        for p in east.mesh.positions {
            XCTAssertEqual(Double(p.z), 0, accuracy: 0.3)
            XCTAssertGreaterThan(p.x, 47)
        }
    }

    func testTheAxisRibbonRunsTheAxis() {
        let pieces = GeometryOverlay.surveyPieces(ground: { _, _ in 0 })
        let axis = try! XCTUnwrap(pieces.first { $0.name == "solstice axis" })
        // Independent trigonometry: the axis azimuth is 49.9°, so the line's
        // direction on the ground is (sin 49.9°, −cos 49.9°) in (east, south),
        // and every vertex must sit within half the ribbon's width of it.
        let direction = SIMD2(sin(49.9 * .pi / 180), -cos(49.9 * .pi / 180))
        for p in axis.mesh.positions {
            let point = SIMD2(Double(p.x), Double(p.z))
            let offAxis = abs(point.x * direction.y - point.y * direction.x)
            XCTAssertLessThan(offAxis, 0.4,
                              "axis ribbon vertex \(offAxis) m off the line")
        }
        XCTAssertEqual(axis.tier, .established)
    }

    func testTheStationRectangleUsesTheStonesOwnCorners() {
        let pieces = GeometryOverlay.surveyPieces(ground: { _, _ in 0 })
            .filter { $0.name == "station rectangle" }
        XCTAssertEqual(pieces.count, 4, "a rectangle has four sides")
        for piece in pieces { XCTAssertEqual(piece.tier, .debated) }

        let stones = MonumentScene.stationStones(state: .asItWas)
        XCTAssertEqual(stones.count, 4)
        // Every stone must be an endpoint of some side: the nearest ribbon
        // vertex to each stone should be within the ribbon's own geometry of
        // it. This checks the overlay reads the survey rather than keeping a
        // private copy of the rectangle.
        for stone in stones {
            let target = SIMD2(stone.position.x, stone.position.z)
            let nearest = pieces.flatMap(\.mesh.positions).map {
                simd_length(SIMD2(Double($0.x), Double($0.z)) - target)
            }.min() ?? .infinity
            XCTAssertLessThan(nearest, 0.5,
                              "no rectangle side reaches \(stone.id)")
        }
    }

    func testMarkersStandOnTheAubreyCircleWhereTheEphemerisPutsThem() {
        // Within a day of the March 2000 equinox the sun's apparent longitude
        // is within a degree of zero, so its marker occupies hole 0 — which
        // snaps to the drawn disc nearest the axis. The bearing arithmetic is
        // checkable by hand: hole step 360/56 = 6.4286°, axis 49.9°, nearest
        // disc index round(49.9 / 6.4286) = 8, bearing 51.43°.
        let equinox2000 = JulianDay(2_451_623.816)
        let pieces = GeometryOverlay.markerStones(at: equinox2000.terrestrialTime,
                                                  ground: { _, _ in 0 })
        XCTAssertEqual(pieces.count, 4, "sun, moon, and both nodes")

        let radius = Monument.aubreyCircleDiameter / 2
        for piece in pieces {
            let c = centroid(piece.mesh)
            XCTAssertEqual(simd_length(SIMD2(c.x, c.z)), radius, accuracy: 1.0,
                           "\(piece.name) stands off the Aubrey circle")
            XCTAssertEqual(piece.tier, .debated,
                           "a marker that shipped un-badged would violate "
                           + "invariant 3")
        }

        let sun = try! XCTUnwrap(pieces.first { $0.name == "sun marker" })
        let bearing = 8.0 * 360.0 / 56.0 * .pi / 180
        let expected = SIMD2(sin(bearing) * radius, -cos(bearing) * radius)
        let actual = centroid(sun.mesh)
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.6)
        XCTAssertEqual(actual.z, expected.y, accuracy: 0.6)
    }

    func testTheNodeMarkersStandOpposite() {
        let pieces = GeometryOverlay.markerStones(at: JulianDay(2_451_623.816).terrestrialTime,
                                                  ground: { _, _ in 0 })
        let nodes = pieces.filter { $0.name.hasPrefix("node marker") }
        XCTAssertEqual(nodes.count, 2)
        let a = centroid(nodes[0].mesh), b = centroid(nodes[1].mesh)
        // Diametric holes are exactly 28 apart, so the snapped discs are
        // exactly opposite and the centroids cancel.
        XCTAssertEqual(a.x + b.x, 0, accuracy: 0.6)
        XCTAssertEqual(a.z + b.z, 0, accuracy: 0.6)
    }
}
