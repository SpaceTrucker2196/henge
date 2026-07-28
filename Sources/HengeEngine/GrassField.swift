import Foundation
import simd
import HengeGeometry

/// One vertex of a blade, in the blade's own frame.
///
/// `height` runs 0 at the root to 1 at the tip and does all the work in the
/// vertex shader: it drives the taper, the cantilever bend, and how much of the
/// wind a point feels. `side` is −1 or +1 across the blade's width, and 0 at
/// the tip where the two edges meet.
public struct GrassVertex {
    public var height: Float
    public var side: Float
}

/// One blade, placed on the plain.
///
/// Deliberately small — eight floats. There are tens of thousands of these and
/// they are read once per vertex, so every field has to earn its bandwidth.
public struct GrassBlade {
    /// Where the blade is rooted, in world space.
    public var root: SIMD3<Float>
    /// Which way it faces, radians. Grass has no preferred direction; this is
    /// what stops the field looking combed.
    public var yaw: Float
    /// Length in metres.
    public var height: Float
    /// Width at the root, metres.
    public var width: Float
    /// How stiff this blade is, 0.6 to 1.4. Real swards are a mixture, and a
    /// uniform stiffness makes the whole field move as one sheet.
    public var stiffness: Float
    /// Phase offset for the flutter, radians. Without it every blade in a gust
    /// oscillates in lockstep, which reads as a vibrating carpet.
    public var phase: Float
    /// Multiplies the blade's colour, 0.82 to 1.18.
    public var tint: Float
    /// Padding to a 16-byte boundary, so the stride matches MSL's alignment.
    public var pad: Float = 0
}

/// A field of individual grass blades.
///
/// **Why geometry now, when the shading trick was working.** The wind-as-
/// reflectance model is right for the middle distance and beyond, and it stays
/// — a hundred metres out, a blade is a hundredth of a pixel and drawing it is
/// wasted work. But near the viewer it is visibly a *pattern moving over a
/// surface* rather than grass, and the app puts you standing on the turf at eye
/// height. So: real blades within a short radius, the shading model everywhere
/// else, and a fade where they meet.
///
/// The blades do not cast shadows. Fifty thousand slivers rendered into a
/// shadow map would cost more than everything else in the frame and buy a haze
/// of aliasing; they *receive* shadows, which is the part you notice when a
/// trilithon's shadow crosses the grass.
public enum GrassField {

    /// How far out blades are drawn, metres.
    ///
    /// Beyond this the textured ground with its wind shimmer takes over. Twenty
    /// eight metres is roughly where an individual blade stops being resolvable
    /// at a normal field of view on a phone-sized screen, which is the honest
    /// place to stop paying for them.
    public static let radius: Float = 28

    /// Blades per square metre.
    ///
    /// Real chalk downland runs to thousands of shoots per square metre; this
    /// is not that and cannot be. At 45 the field reads as continuous once the
    /// textured ground shows through between blades, which is what the ground
    /// is doing underneath them.
    public static let density: Float = 45

    /// How far the blades fade back into the textured ground, metres.
    public static let fade: Float = 6

    // ── the blade ───────────────────────────────────────────────────────────

    /// Segments along a blade. Four is enough for a curve that reads as a
    /// curve; the cost is per-blade, not per-segment, at this count.
    public static let segments = 4

    /// The blade's own geometry, shared by every instance.
    ///
    /// A tapering strip: `segments` quads and a tip triangle. Built once and
    /// drawn instanced, which is the entire reason this is affordable.
    public static func bladeMesh() -> (vertices: [GrassVertex], indices: [UInt16]) {
        var vertices: [GrassVertex] = []
        var indices: [UInt16] = []

        for segment in 0...segments {
            let t = Float(segment) / Float(segments)
            if segment == segments {
                vertices.append(GrassVertex(height: t, side: 0))   // the tip
            } else {
                vertices.append(GrassVertex(height: t, side: -1))
                vertices.append(GrassVertex(height: t, side: 1))
            }
        }

        for segment in 0..<segments {
            let base = UInt16(segment * 2)
            if segment == segments - 1 {
                // Last segment closes on the single tip vertex.
                let tip = UInt16(segments * 2)
                indices += [base, base + 1, tip]
            } else {
                indices += [base, base + 1, base + 2,
                            base + 1, base + 3, base + 2]
            }
        }
        return (vertices, indices)
    }

    // ── the field ───────────────────────────────────────────────────────────

    /// Scatter blades over a disc around the monument.
    ///
    /// Seeded, so the field is identical every run — a sward that reshuffled
    /// itself between launches would make every rendering test unrepeatable,
    /// and would be noticeable as a flicker whenever the scene reloaded.
    ///
    /// Placement is jittered grid rather than uniform random: pure random
    /// scatter clumps, and the gaps read as bald patches. The jitter is what
    /// keeps it from reading as a grid.
    public static func scatter(terrain: TerrainModel?,
                               radius: Float = GrassField.radius,
                               density: Float = GrassField.density) -> [GrassBlade] {
        var random = SandRandom(seed: 0x5EED_6A55)
        let spacing = 1 / sqrt(max(density, 0.01))
        let steps = Int((radius * 2 / spacing).rounded(.up))
        var blades: [GrassBlade] = []
        blades.reserveCapacity(steps * steps)

        for ix in 0..<steps {
            for iz in 0..<steps {
                let cellX = -radius + (Float(ix) + 0.5) * spacing
                let cellZ = -radius + (Float(iz) + 0.5) * spacing
                let x = cellX + (random.nextFloat() - 0.5) * spacing * 1.6
                let z = cellZ + (random.nextFloat() - 0.5) * spacing * 1.6

                let distance = sqrt(x * x + z * z)
                if distance > radius { continue }

                let ground = terrain.map {
                    Float($0.groundHeight(east: Double(x), south: Double(z)))
                } ?? 0

                // **True scale, in metres, like everything else here.**
                //
                // Chalk downland is grazed sward, not prairie: 4 to 16 cm, and
                // the tallest tussocks nowhere near knee height. Against a
                // 4.1 m sarsen a blade is about a fortieth of its width, which
                // is what it should look like.
                //
                // Skewed so most blades are short and a few stand proud;
                // squaring a uniform gives that without a second draw.
                let u = random.nextFloat()
                let height = 0.04 + u * u * 0.12

                blades.append(GrassBlade(
                    root: SIMD3(x, ground, z),
                    yaw: random.nextFloat() * 2 * .pi,
                    height: height,
                    // 2 to 4.5 mm — a real grass blade, measured.
                    width: 0.002 + random.nextFloat() * 0.0025,
                    stiffness: 0.6 + random.nextFloat() * 0.8,
                    phase: random.nextFloat() * 2 * .pi,
                    tint: 0.82 + random.nextFloat() * 0.36))
            }
        }
        return blades
    }
}

/// A small deterministic generator, so the sward is the same every launch.
///
/// xorshift64*, which is plenty for scattering grass and is a handful of
/// instructions. Local to this file because `HengeGeometry.SandRandom` is a
/// different generator with a different job, and sharing one would couple the
/// look of the grass to the shape of the stones.
struct SandRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545_F491_4F6C_DD1D
    }

    /// Uniform in [0, 1).
    mutating func nextFloat() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }
}
