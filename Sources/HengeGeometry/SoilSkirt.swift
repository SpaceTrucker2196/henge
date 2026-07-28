import Foundation
import simd

/// The soil that has piled up where a stone meets the ground.
///
/// A megalith does not sit on the turf like a chess piece on a board. It stands
/// in a socket, and four and a half thousand years of rain, worm cast, molehill
/// and trampling have built a low irregular mound against its foot — thicker on
/// the lee side, scoured on the weather side, notched where a badger or an
/// antiquarian has been at it. Without something there, the junction reads as a
/// hard line and the stone reads as placed rather than rooted; it is the single
/// detail that most gives away a rendered monument.
///
/// This builds that mound as its own small mesh: a ring of triangles running
/// from part-way up the stone out to nothing, with the outer radius and the
/// height varying around the circumference from seeded noise. Seeded per stone,
/// so no two are alike and none moves between launches.
///
/// It is *not* a physical simulation of soil creep. It is a shape chosen to
/// look like the photographs, and it is worth saying so plainly rather than
/// dressing it up — the archaeology in this project is cited, and this is not
/// archaeology.
public enum SoilSkirt {

    /// How far the mound reaches out from the stone's face, metres, before the
    /// per-stone variation is applied.
    public static let reach: Float = 0.42

    /// How high it climbs the stone at its thickest.
    public static let rise: Float = 0.17

    /// Build the mound around one stone.
    ///
    /// `groundHeight` is asked for the terrain under each point of the ring, so
    /// the mound follows the contour rather than sitting on a flat disc — on a
    /// slope the uphill side is buried deeper, which is what actually happens.
    ///
    /// Returns an empty mesh for anything that is not standing on the ground:
    /// lintels and flush chalk features have no foot for soil to gather round.
    public static func build(around stone: Stone,
                             groundHeight: (Float, Float) -> Float = { _, _ in 0 },
                             segments: Int = 28) -> Mesh {
        guard isGroundFounded(stone), stone.material != .chalk else { return Mesh() }

        var random = SkirtRandom(seed: stone.seed &* 0x9E37_79B9)
        // Per-stone character, so some stones are barely tucked in and others
        // sit in a distinct bank.
        let bulk = 0.55 + random.nextFloat() * 0.95
        // Which way the drift has piled. Real prevailing wind is south-westerly,
        // but hedges, footfall and the monument's own shelter scatter it, so
        // this is a random bearing biased that way rather than fixed to it.
        let driftBearing = Float.pi * 1.25 + (random.nextFloat() - 0.5) * 2.4
        let driftStrength = 0.25 + random.nextFloat() * 0.55

        // Two noise frequencies around the circumference: a broad lobe or two,
        // and a finer crenellation. One frequency alone reads as an ellipse.
        let broadPhase = random.nextFloat() * 2 * .pi
        let finePhase = random.nextFloat() * 2 * .pi
        let broadLobes = Float(2 + Int(random.nextFloat() * 2))     // 2 or 3
        let fineLobes = Float(7 + Int(random.nextFloat() * 6))      // 7…12

        // The stone's footprint, as a radius per direction. A stone is a box
        // turned to its bearing, so this is the box's outline.
        let halfWidth = Float(stone.width) * 0.5
        let halfThickness = Float(stone.thickness) * 0.5
        let bearing = Float(stone.bearing.radians)

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        let base = Float(stone.position.y) - Float(stone.height) * 0.5

        for segment in 0...segments {
            let angle = Float(segment) / Float(segments) * 2 * .pi

            // Where the stone's face is in this direction — the box outline,
            // so the mound hugs a rectangular stone instead of ringing it in a
            // circle with gaps at the corners.
            let local = angle - bearing
            let footprint = boxRadius(halfWidth: halfWidth,
                                      halfThickness: halfThickness,
                                      angle: local)

            // How far the mound reaches here.
            let broad = sin(angle * broadLobes + broadPhase)
            let fine = sin(angle * fineLobes + finePhase)
            let drift = cos(angle - driftBearing) * driftStrength
            // Bound to explicit Floats: inlined, this chain of literal
            // arithmetic times the type-checker out.
            let broadTerm: Float = broad * 0.34
            let fineTerm: Float = fine * 0.13
            let variation: Float = 1 + broadTerm + fineTerm + drift
            let outward: Float = reach * bulk * max(variation, 0.18)
            let heightVariation: Float = 1 + broad * 0.28 + drift * 0.7
            let height: Float = rise * bulk * max(heightVariation, 0.15)

            let direction = SIMD2<Float>(sin(angle), cos(angle))

            // Inner ring: against the stone, part-way up it.
            let innerXZ = SIMD2(Float(stone.position.x), Float(stone.position.z))
                + direction * (footprint - 0.02)
            let innerGround = groundHeight(innerXZ.x, innerXZ.y)
            positions.append(SIMD3(innerXZ.x, max(base, innerGround) + height, innerXZ.y))
            normals.append(SIMD3(0, 1, 0))

            // Outer ring: feathered out to nothing on the turf.
            let outerXZ = SIMD2(Float(stone.position.x), Float(stone.position.z))
                + direction * (footprint + outward)
            let outerGround = groundHeight(outerXZ.x, outerXZ.y)
            positions.append(SIMD3(outerXZ.x, outerGround + 0.004, outerXZ.y))
            // Slope the outer normal outward and up, so the mound catches light
            // along its flank rather than reading as a flat washer.
            normals.append(normalize(SIMD3(direction.x * 0.55, 1, direction.y * 0.55)))
        }

        for segment in 0..<segments {
            let i = UInt32(segment * 2)
            // Counter-clockwise seen from above, matching every other mesh here
            // — the winding convention this project learned the hard way.
            indices += [i, i + 1, i + 2,
                        i + 1, i + 3, i + 2]
        }

        return Mesh(positions: positions, normals: normals, indices: indices)
    }

    /// A stone stands on the ground when its centre is about half its own
    /// height up. Lintels rest on uprights and their centres are far higher.
    public static func isGroundFounded(_ stone: Stone) -> Bool {
        Double(stone.position.y) <= stone.height / 2 + 0.3
    }

    /// Distance from a box's centre to its edge in a given direction.
    ///
    /// The mound has to hug a rectangular stone. Ringing it at a constant
    /// radius leaves the soil floating clear of the long faces and buried in
    /// the corners, which is worse than no mound at all.
    static func boxRadius(halfWidth: Float, halfThickness: Float, angle: Float) -> Float {
        let s = abs(sin(angle)), c = abs(cos(angle))
        // The larger of the two axis intercepts is the one the ray leaves by.
        let byWidth = s > 1e-4 ? halfWidth / s : Float.greatestFiniteMagnitude
        let byThickness = c > 1e-4 ? halfThickness / c : Float.greatestFiniteMagnitude
        return min(byWidth, byThickness)
    }
}

/// Seeded generator for the skirts, kept separate so the soil's look is not
/// coupled to the stones' own displacement noise.
struct SkirtRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0xDEAD_BEEF_CAFE_F00D : seed }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545_F491_4F6C_DD1D
    }

    mutating func nextFloat() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }
}
