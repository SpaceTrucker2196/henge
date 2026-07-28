import Foundation
import simd

/// A triangle mesh in plain arrays — no Metal types, because this module must
/// stay buildable and testable on a machine with no GPU.
public struct Mesh: Sendable {
    public var positions: [SIMD3<Float>]
    public var normals: [SIMD3<Float>]
    public var indices: [UInt32]
    /// Optional per-vertex blend, 0 bare soil to 1 turf. Empty on every mesh
    /// but the soil banks, which use it to fade into the grass they sit in.
    public var blends: [Float]

    public init(positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [],
                indices: [UInt32] = [], blends: [Float] = []) {
        self.positions = positions
        self.normals = normals
        self.blends = blends
        self.indices = indices
    }

    public var triangleCount: Int { indices.count / 3 }

    public mutating func append(_ other: Mesh) {
        let offset = UInt32(positions.count)
        positions.append(contentsOf: other.positions)
        normals.append(contentsOf: other.normals)
        indices.append(contentsOf: other.indices.map { $0 + offset })
    }
}

/// Turns a `Stone`'s dimensions into rock.
///
/// The first version built six independent box faces and displaced each along
/// its own normal. Three things were wrong with that, and all three showed the
/// moment it ran on a device:
///
/// 1. **The faces were not welded.** Vertices sharing an edge existed twice and
///    moved in different directions, so the stone split open along every edge —
///    those were the bright seams.
/// 2. **The edges were perfectly sharp.** Nothing on a weathered sarsen is, and
///    a hard 90° edge reads as a concrete slab rather than a boulder. Solidity
///    is carried by the silhouette more than by the shading.
/// 3. **Normals came from triangle winding**, which is only defined up to a
///    sign, so half the faces lit from the inside.
///
/// The shape is now one closed surface: a sphere swept onto a rounded box and
/// pushed about by noise. Every vertex belongs to a single surface, so edges
/// cannot come apart, normals are smooth across them, and the outline is a
/// stone rather than a rectangle.
public enum StoneMeshBuilder {

    /// Hermite fade, so the displacement dies smoothly rather than stepping.
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// The shape a particular stone takes: every knob the mesh has, drawn
    /// once per stone from its seed.
    ///
    /// This exists because the stones used to differ only in *shading* —
    /// per-stone texture offset and rotation — while every mesh shared one
    /// set of displacement parameters. Eighty of the same rock in eighty
    /// different coats. The parameters below are what "quarried, then four
    /// thousand years of weather" varies between one sarsen and the next,
    /// and their ranges are an artistic reading of generic weathered rock,
    /// deliberately not a claim about sarsen specifically — the geology
    /// strand of the research is still unusable (research notes, 2026-07-28).
    ///
    /// Everything scales from the caller's `roughness` and `rounding`, and
    /// vanishes with them: the shadow-agreement oracle builds its stones at
    /// zero-zero and must get the exact reference box, so individuality is
    /// part of the weathering, never part of the calibration solid.
    struct StoneShape {
        /// Exponent of the p-norm the corners are rounded against: 2 is the
        /// old inscribed ellipsoid, higher keeps faces flatter and gathers
        /// the rounding into a tighter arris — which is what a dressed block
        /// actually has.
        let arrisExponent: Double
        /// How far toward that p-norm surface the box is pulled.
        let rounding: Double
        /// Displacement, as a fraction of the smallest half-extent.
        let amplitude: Double
        /// Base frequency of the displacement field.
        let frequency: Double
        /// How much narrower the crown is than the foot, 0 to ~0.1. Scaled
        /// by the roughness knob so a calibration build tapers not at all.
        let taper: Double

        static func draw(seed: UInt64, roughness: Double, rounding: Double) -> StoneShape {
            var rng = SplitMix64(seed: seed)
            return StoneShape(
                arrisExponent: 2.0 + rng.unit() * 3.0,
                rounding: rounding * (0.75 + rng.unit() * 0.75),
                amplitude: roughness * (0.8 + rng.unit() * 0.45),
                frequency: 2.4 * (0.85 + rng.unit() * 0.4),
                taper: rng.unit() * 0.10 * min(roughness / 0.06, 1))
        }
    }

    /// Deterministic per-stone stream, so a stone's shape is a pure function
    /// of its seed. SplitMix64 because it is tiny, well-distributed, and
    /// self-contained — invariant 5 rules out a library for this.
    struct SplitMix64 {
        private var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        /// Uniform in [0, 1).
        mutating func unit() -> Double {
            Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
        }
    }

    /// - Parameters:
    ///   - subdivisions: grid divisions per box face.
    ///   - roughness: radial displacement as a fraction of the smallest
    ///     half-extent. Zero gives the exact rounded box.
    ///   - rounding: 0 is a hard box, 1 an inscribed ellipsoid. Real sarsens
    ///     sit close to the box end — enough to lose the machined edge, not so
    ///     much that they inflate into pillows.
    public static func build(_ stone: Stone, subdivisions: Int = 12,
                             roughness: Double = 0.06,
                             rounding: Double = 0.13) -> Mesh {
        let n = max(2, subdivisions)

        // Megaliths sit in a socket, and a leaning one must: tipping a body
        // about the centre of its base lifts the far edge clear of the ground.
        let halfThickness = stone.thickness / 2
        let sink = halfThickness * abs(sin(stone.lean.radians)) + 0.15

        let half = SIMD3<Double>(stone.width / 2,
                                 (stone.height + sink) / 2,
                                 stone.thickness / 2)
        let centre = SIMD3<Double>(0, half.y - sink, 0)
        let smallestHalf = min(half.x, min(half.y, half.z))

        var noise = ValueNoise(seed: stone.seed)
        let shapeOf = StoneShape.draw(seed: stone.seed,
                                      roughness: roughness, rounding: rounding)

        /// Shape a point on the box surface: round the corners, weather it,
        /// then taper the crown.
        ///
        /// All three steps are functions of the point alone, never of the
        /// face it came from — which is what lets vertices shared between
        /// faces be welded and still land in the same place.
        func shape(_ boxPoint: SIMD3<Double>) -> SIMD3<Double> {
            let d = simd_normalize(boxPoint)

            // The p-norm surface inscribed in the same box. At p = 2 this is
            // the old inscribed ellipsoid; this stone's own exponent keeps
            // the faces flatter and gathers the rounding into an arris of its
            // own tightness. Scaled per axis, as the ellipsoid was, so a tall
            // stone is not shortened along its long axis.
            let p = shapeOf.arrisExponent
            let pNormScale = pow(pow(abs(d.x / half.x), p)
                                 + pow(abs(d.y / half.y), p)
                                 + pow(abs(d.z / half.z), p), 1 / p)
            var point = simd_mix(boxPoint, d / pNormScale,
                                 SIMD3(repeating: shapeOf.rounding))

            if shapeOf.amplitude > 0 {
                var amount = noise.rockField(d * shapeOf.frequency)
                    * shapeOf.amplitude * smallestHalf * 2
                // Fade out toward the waterline. A shadow is stretched by
                // 1/tan(altitude), and at the low sun this app exists for that
                // is a factor of eight or nine — so a three-centimetre bump at
                // the base throws a quarter-metre spike across the turf.
                amount *= smoothstep(0.0, 1.6, point.y + centre.y)
                point += d * amount
            }

            // The crown narrows. Real uprights taper — they were dressed to
            // — and a fractional squeeze of the top against the foot is the
            // single cheapest thing that makes two stones of the same nominal
            // dimensions read as two stones. A pure function of the point's
            // own height, so welding is untouched; zero at the foot, so the
            // sockets and the waterline tests are too.
            let crown = smoothstep(0.15, 1.0, (boxPoint.y + half.y) / (2 * half.y))
            let squeeze = 1 - shapeOf.taper * crown
            point.x *= squeeze
            point.z *= squeeze
            return point + centre
        }

        // Six face grids, welded where they meet.
        //
        // The previous version swept a UV sphere onto the box, which spent
        // nearly all its vertices around the long axis and left the small top
        // face covered by a ring or two. The top came out a coarse faceted
        // bevel that reads as the rim of an open tube rather than the end of a
        // solid — the reason the pillars looked unclosed. A box grid spends its
        // vertices evenly over the actual surface instead.
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var welded: [WeldKey: UInt32] = [:]

        func vertex(_ boxPoint: SIMD3<Double>) -> UInt32 {
            // Key on the *box* point, before shaping: it is exact on shared
            // edges, where a shaped position might differ in the last bit.
            let key = WeldKey(boxPoint)
            if let existing = welded[key] { return existing }
            let index = UInt32(positions.count)
            welded[key] = index
            positions.append(SIMD3<Float>(shape(boxPoint)))
            return index
        }

        typealias V3 = SIMD3<Double>
        let faces: [(origin: V3, u: V3, v: V3)] = [
            (V3(-half.x, -half.y, -half.z), V3(2 * half.x, 0, 0), V3(0, 2 * half.y, 0)),
            (V3(half.x, -half.y, half.z), V3(-2 * half.x, 0, 0), V3(0, 2 * half.y, 0)),
            (V3(-half.x, -half.y, half.z), V3(0, 0, -2 * half.z), V3(0, 2 * half.y, 0)),
            (V3(half.x, -half.y, -half.z), V3(0, 0, 2 * half.z), V3(0, 2 * half.y, 0)),
            (V3(-half.x, half.y, -half.z), V3(2 * half.x, 0, 0), V3(0, 0, 2 * half.z)),
            (V3(-half.x, -half.y, half.z), V3(2 * half.x, 0, 0), V3(0, 0, -2 * half.z))
        ]

        for face in faces {
            for i in 0..<n {
                for j in 0..<n {
                    let s0 = Double(i) / Double(n), s1 = Double(i + 1) / Double(n)
                    let t0 = Double(j) / Double(n), t1 = Double(j + 1) / Double(n)

                    let a = vertex(face.origin + face.u * s0 + face.v * t0)
                    let b = vertex(face.origin + face.u * s1 + face.v * t0)
                    let c = vertex(face.origin + face.u * s1 + face.v * t1)
                    let d = vertex(face.origin + face.u * s0 + face.v * t1)
                    indices.append(contentsOf: [a, b, c, a, c, d])
                }
            }
        }

        var mesh = Mesh(positions: positions,
                        normals: [SIMD3<Float>](repeating: .zero, count: positions.count),
                        indices: indices)

        smoothNormals(&mesh, centre: SIMD3<Float>(centre))
        transform(&mesh, stone: stone)
        return mesh
    }

    /// Position key for welding. Quantised to a tenth of a millimetre, which is
    /// far finer than any stone and far coarser than floating-point noise.
    struct WeldKey: Hashable {
        let x: Int64, y: Int64, z: Int64
        init(_ p: SIMD3<Double>) {
            x = Int64((p.x * 10_000).rounded())
            y = Int64((p.y * 10_000).rounded())
            z = Int64((p.z * 10_000).rounded())
        }
    }

    /// Area-weighted vertex normals over the finished surface.
    ///
    /// The surface is closed and welded, so accumulating face normals gives
    /// smooth shading across edges for nothing. Orientation is settled against
    /// the outward direction from the body's centre rather than against the
    /// winding, because winding alone cannot tell inside from outside — and
    /// getting that wrong is what turned the stones black.
    static func smoothNormals(_ mesh: inout Mesh, centre: SIMD3<Float>) {
        var accumulated = [SIMD3<Float>](repeating: .zero, count: mesh.positions.count)

        for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
            let i0 = Int(mesh.indices[triangle])
            let i1 = Int(mesh.indices[triangle + 1])
            let i2 = Int(mesh.indices[triangle + 2])
            let p0 = mesh.positions[i0], p1 = mesh.positions[i1], p2 = mesh.positions[i2]

            var faceNormal = cross(p1 - p0, p2 - p0)
            let outward = ((p0 + p1 + p2) / 3) - centre
            if dot(faceNormal, outward) < 0 {
                faceNormal = -faceNormal
                mesh.indices.swapAt(triangle + 1, triangle + 2)
            }
            // Deliberately not normalised: the cross product's length is twice
            // the triangle's area, which is the weighting a smooth normal wants.
            accumulated[i0] += faceNormal
            accumulated[i1] += faceNormal
            accumulated[i2] += faceNormal
        }

        for i in accumulated.indices {
            let length = simd_length(accumulated[i])
            if length > 1e-9 {
                mesh.normals[i] = accumulated[i] / length
            } else {
                let outward = mesh.positions[i] - centre
                let outwardLength = simd_length(outward)
                mesh.normals[i] = outwardLength > 1e-9
                    ? outward / outwardLength : SIMD3<Float>(0, 1, 0)
            }
        }
    }

    /// Local space → world, delegating to `Stone.toWorld` so the mesh and the
    /// shadow solver cannot drift apart.
    static func transform(_ mesh: inout Mesh, stone: Stone) {
        for i in mesh.positions.indices {
            let local = SIMD3<Double>(mesh.positions[i])
            mesh.positions[i] = SIMD3<Float>(stone.toWorld(local))

            let localNormal = SIMD3<Double>(mesh.normals[i])
            let worldNormal = stone.directionToWorld(localNormal)
            let length = simd_length(worldNormal)
            mesh.normals[i] = length > 1e-9
                ? SIMD3<Float>(worldNormal / length)
                : mesh.normals[i]
        }
    }
}

/// Small deterministic value noise. Not the prettiest gradient noise, but it is
/// self-contained — MISSION.md invariant 5 rules out pulling in a library for
/// this, and a stone only needs to look quarried.
struct ValueNoise {

    private var state: UInt64

    init(seed: UInt64) { self.state = seed | 1 }

    private func hash(_ x: Int, _ y: Int, _ z: Int) -> Double {
        var h = state
        h ^= UInt64(bitPattern: Int64(x)) &* 0x9E3779B97F4A7C15
        h ^= UInt64(bitPattern: Int64(y)) &* 0xC2B2AE3D27D4EB4F
        h ^= UInt64(bitPattern: Int64(z)) &* 0x165667B19E3779F9
        h ^= h >> 33
        h = h &* 0xFF51AFD7ED558CCD
        h ^= h >> 33
        return Double(h % 100_000) / 100_000.0 * 2 - 1
    }

    private func sample(_ p: SIMD3<Double>) -> Double {
        let i = SIMD3<Int>(Int(floor(p.x)), Int(floor(p.y)), Int(floor(p.z)))
        let f = p - SIMD3<Double>(Double(i.x), Double(i.y), Double(i.z))
        // Smoothstep so the lattice does not show as creases.
        let w = f * f * (3.0 - 2.0 * f)

        var result = 0.0
        for dx in 0...1 {
            for dy in 0...1 {
                for dz in 0...1 {
                    let corner = hash(i.x + dx, i.y + dy, i.z + dz)
                    let weight = (dx == 0 ? 1 - w.x : w.x)
                        * (dy == 0 ? 1 - w.y : w.y)
                        * (dz == 0 ? 1 - w.z : w.z)
                    result += corner * weight
                }
            }
        }
        return result
    }

    /// Four octaves: broad lumps down to surface grain.
    mutating func fbm(_ p: SIMD3<Double>) -> Double {
        var total = 0.0
        var amplitude = 1.0
        var frequency = 1.0
        var normalisation = 0.0
        for _ in 0..<4 {
            total += sample(p * frequency) * amplitude
            normalisation += amplitude
            amplitude *= 0.5
            frequency *= 2.13
        }
        return total / normalisation
    }

    /// The displacement field the stones are carved with: a hybrid
    /// multifractal with one level of domain warp, in place of plain fBm.
    ///
    /// Plain fBm reads as *noise* — every octave everywhere at full strength.
    /// Weathered rock is not like that: where the surface stands proud it is
    /// broken and detailed, where it has worn smooth it is smooth at every
    /// scale at once. Musgrave's hybrid multifractal gets exactly that by
    /// letting each octave's weight ride on the octaves before it, and a
    /// single warp of the domain bends the features so they stop looking
    /// gridded. (Musgrave, Kolb & Mace, "The synthesis and rendering of
    /// eroded fractal terrains", SIGGRAPH 1989 — applied here at hand scale
    /// rather than landscape scale.)
    ///
    /// Bounded in [-1, 1] by construction — each octave contributes at most
    /// `amplitude × weight ≤ amplitude` — so the mesh tests can state a hard
    /// ceiling on how far a vertex may leave the box.
    mutating func rockField(_ p: SIMD3<Double>) -> Double {
        // One warp level: three decorrelated samples bend the domain.
        let warp = SIMD3(sample(p + SIMD3(31.7, 0, 0)),
                         sample(p + SIMD3(0, 47.3, 0)),
                         sample(p + SIMD3(0, 0, 12.9)))
        let q = p + warp * 0.6

        var total = 0.0
        var amplitude = 1.0
        var frequency = 1.0
        var normalisation = 0.0
        var weight = 1.0
        for _ in 0..<4 {
            let signal = sample(q * frequency) * weight
            total += signal * amplitude
            normalisation += amplitude
            // The next octave is strongest where this one stood proud —
            // clamped to [0, 1] so the sum stays bounded.
            weight = min(max(0.5 + signal, 0), 1)
            amplitude *= 0.5
            frequency *= 2.13
        }
        return total / normalisation
    }
}
