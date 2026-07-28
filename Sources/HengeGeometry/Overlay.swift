import Foundation
import simd
import HengeAstro

/// The geometry overlay: the monument's researched lines drawn on the turf,
/// and Hoyle's markers acted out on the Aubrey ring.
///
/// Two registers, deliberately distinct. The *lines* are survey: cardinal
/// directions, the solstice axis, the Station-Stone rectangle, the Avenue —
/// each carrying the tier of the claim it draws. The *markers* are the moving
/// part: gold stones on the Aubrey ring at the positions of the real sun,
/// moon and nodes, projected by `AubreyRing` from the ephemeris rather than
/// simulated by Hoyle's marker-shuffling rules (see AubreyRing's header for
/// why the projection is the honest version). Gold means moving, and moving
/// means hypothesis — the research note in `research/lunar-markers.md` is
/// binding on any prose shown beside this.
///
/// Everything here is CPU geometry in world space: ribbons draped over the
/// terrain by sampling the same ground function the stones are seated on.
/// The renderer draws the pieces unlit, so the diagram stays legible at
/// midnight — which is exactly when the moon lines matter.
public enum GeometryOverlay {

    /// One drawable piece: a mesh, its flat colour, and what it claims.
    public struct Piece: Sendable {
        public let name: String
        public let mesh: Mesh
        /// Linear RGB; w unused by the unlit path.
        public let colour: SIMD4<Float>
        public let tier: LoreTier

        public init(name: String, mesh: Mesh, colour: SIMD4<Float>, tier: LoreTier) {
            self.name = name
            self.mesh = mesh
            self.colour = colour
            self.tier = tier
        }
    }

    // ── palette ─────────────────────────────────────────────────────────────
    //
    // Not in the UI theme because the colours are part of the diagram's
    // meaning: gold is the moving hypothesis, silver the moon, pale stone the
    // fixed survey. Kept desaturated enough not to lie about the light.
    static let chalkLine = SIMD4<Float>(0.82, 0.80, 0.72, 1)
    static let bronzeLine = SIMD4<Float>(0.78, 0.60, 0.26, 1)
    static let silverLine = SIMD4<Float>(0.62, 0.68, 0.78, 1)
    static let gold = SIMD4<Float>(0.90, 0.70, 0.22, 1)

    /// How far above the ground a ribbon floats. Enough to clear the terrain
    /// mesh between samples, not enough to read as hovering.
    static let lift = 0.07

    // ── ribbons ─────────────────────────────────────────────────────────────

    /// A flat ribbon from `start` to `end` (ground coordinates, metres east
    /// and south), draped over the terrain by sampling `ground` every metre
    /// and a half. Normals face up; winding is counter-clockwise seen from
    /// above, which is what the renderer's back-face culling expects.
    static func ribbon(from start: SIMD2<Double>, to end: SIMD2<Double>,
                       width: Double = 0.4,
                       ground: (Double, Double) -> Double) -> Mesh {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.01 else { return Mesh() }
        let steps = max(2, Int(length / 1.5))
        let direction = delta / length
        let across = SIMD2(-direction.y, direction.x) * (width / 2)

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity((steps + 1) * 2)

        for i in 0...steps {
            let p = start + delta * (Double(i) / Double(steps))
            for corner in [p - across, p + across] {
                positions.append(SIMD3(Float(corner.x),
                                       Float(ground(corner.x, corner.y) + lift),
                                       Float(corner.y)))
                normals.append(SIMD3(0, 1, 0))
            }
        }
        for i in 0..<steps {
            let a = UInt32(i * 2), b = a + 1, c = a + 3, d = a + 2
            indices.append(contentsOf: [a, b, c, a, c, d])
        }
        return Mesh(positions: positions, normals: normals, indices: indices)
    }

    /// A ribbon along a bearing, between two distances from the centre.
    static func ray(azimuth: HengeAstro.Angle, from near: Double, to far: Double,
                    width: Double = 0.4,
                    ground: (Double, Double) -> Double) -> Mesh {
        let direction = WorldAxes.direction(azimuth: azimuth)
        return ribbon(from: SIMD2(direction.x, direction.z) * near,
                      to: SIMD2(direction.x, direction.z) * far,
                      width: width, ground: ground)
    }

    // ── the fixed survey ────────────────────────────────────────────────────

    /// The lines that do not move: cardinals, the axis, the Station-Stone
    /// rectangle, the Avenue. Each piece carries its tier — the axis is
    /// established, the rectangle's lunar reading is argued.
    public static func surveyPieces(ground: (Double, Double) -> Double) -> [Piece] {
        var pieces: [Piece] = []

        // Cardinal directions, as short strokes outside the bank rather than
        // lines through the monument — the diagram should not upstage it.
        for (name, azimuth) in [("North", 0.0), ("East", 90.0),
                                ("South", 180.0), ("West", 270.0)] {
            pieces.append(Piece(name: "cardinal \(name)",
                                mesh: ray(azimuth: Angle(degrees: azimuth),
                                          from: 48, to: 58, ground: ground),
                                colour: chalkLine, tier: .established))
        }

        // The solstice axis, from behind the Great Trilithon out past the
        // Heel Stone: the line the whole monument is an argument about.
        let axis = Monument.axisAzimuth
        pieces.append(Piece(name: "solstice axis",
                            mesh: ribbon(from: axisPoint(axis, -25),
                                         to: axisPoint(axis, 95),
                                         width: 0.55, ground: ground),
                            colour: bronzeLine, tier: .established))

        // The Station-Stone rectangle. The four corners are the stones'
        // surveyed positions; the long sides carry the lunar claim, so the
        // whole figure ships Debated and the lore note says why.
        let stations = MonumentScene.stationStones(state: .asItWas)
            .map { SIMD2($0.position.x, $0.position.z) }
        if stations.count == 4 {
            // 91 → 92 → 93 → 94 in order around the ring.
            for i in 0..<4 {
                let from = stations[i], to = stations[(i + 1) % 4]
                pieces.append(Piece(name: "station rectangle",
                                    mesh: ribbon(from: from, to: to,
                                                 width: 0.3, ground: ground),
                                    colour: silverLine, tier: .debated))
            }
        }

        // The Avenue's banks: two parallel strokes either side of the axis,
        // 22 m apart, running out to the north-east.
        let acrossAxis = (axis + Angle(degrees: 90)).normalized
        let acrossDirection = WorldAxes.direction(azimuth: acrossAxis)
        let half = SIMD2(acrossDirection.x, acrossDirection.z) * 11.0
        for side in [half, -half] {
            pieces.append(Piece(name: "avenue bank",
                                mesh: ribbon(from: axisPoint(axis, 55) + side,
                                             to: axisPoint(axis, 300) + side,
                                             width: 0.35, ground: ground),
                                colour: chalkLine, tier: .established))
        }
        return pieces
    }

    private static func axisPoint(_ azimuth: HengeAstro.Angle, _ distance: Double)
        -> SIMD2<Double> {
        let direction = WorldAxes.direction(azimuth: azimuth)
        return SIMD2(direction.x, direction.z) * distance
    }

    // ── the moving sky ──────────────────────────────────────────────────────

    /// Where the sun stands right now, as a gold stroke on the ground.
    public static func sunRay(azimuth: HengeAstro.Angle,
                              ground: (Double, Double) -> Double) -> Piece {
        Piece(name: "sun bearing",
              mesh: ray(azimuth: azimuth, from: 6, to: 70, width: 0.5,
                        ground: ground),
              colour: gold, tier: .established)
    }

    /// Where the moon stands right now, in silver.
    public static func moonRay(azimuth: HengeAstro.Angle,
                               ground: (Double, Double) -> Double) -> Piece {
        Piece(name: "moon bearing",
              mesh: ray(azimuth: azimuth, from: 6, to: 70, width: 0.5,
                        ground: ground),
              colour: silverLine, tier: .established)
    }

    // ── the markers ─────────────────────────────────────────────────────────

    /// Which drawn chalk disc a ring position lands in.
    ///
    /// `AubreyRing` anchors hole 0 to the monument's axis; the rendered discs
    /// are laid out from north. The marker belongs *in a hole* — Hoyle's
    /// scheme has no positions between them — so the ideal bearing snaps to
    /// the nearest disc.
    static func discIndex(forHole hole: Double) -> Int {
        let step = 360.0 / Double(AubreyRing.holeCount)
        let bearing = Monument.axisAzimuth.degrees + hole * step
        let index = Int((bearing / step).rounded()) % AubreyRing.holeCount
        return index < 0 ? index + AubreyRing.holeCount : index
    }

    /// The four gold markers — sun, moon, and the two nodes half a ring
    /// apart — standing in the Aubrey holes the ephemeris puts them in.
    ///
    /// Graded by height so they read apart at a distance: the sun's the
    /// tallest, the nodes the squattest. All gold, because gold is this
    /// diagram's word for "moving".
    public static func markerStones(at tt: JulianDay,
                                    ground: (Double, Double) -> Double) -> [Piece] {
        let markers = AubreyRing.markers(at: tt)
        let radius = Monument.aubreyCircleDiameter / 2
        let step = 360.0 / Double(AubreyRing.holeCount)

        let posts: [(name: String, hole: Double, height: Double)] = [
            ("sun marker", markers.sun, 1.5),
            ("moon marker", markers.moon, 1.1),
            ("node marker", markers.node, 0.8),
            ("node marker opposite",
             markers.node + Double(AubreyRing.holeCount) / 2, 0.8)
        ]

        return posts.map { post in
            let bearing = Angle(degrees: Double(discIndex(forHole: post.hole)) * step)
            let direction = WorldAxes.direction(azimuth: bearing)
            let east = direction.x * radius, south = direction.z * radius
            let stone = Stone(id: "overlay-\(post.name)",
                              position: SIMD3(east, ground(east, south), south),
                              height: post.height, width: 0.42, thickness: 0.42,
                              bearing: bearing)
            return Piece(name: post.name,
                         mesh: StoneMeshBuilder.build(stone, subdivisions: 6,
                                                      roughness: 0.04),
                         colour: gold, tier: .debated)
        }
    }
}
