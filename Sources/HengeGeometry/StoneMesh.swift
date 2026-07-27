import Foundation
import simd

/// A triangle mesh in plain arrays — no Metal types, because this module must
/// stay buildable and testable on a machine with no GPU.
public struct Mesh: Sendable {
    public var positions: [SIMD3<Float>]
    public var normals: [SIMD3<Float>]
    public var indices: [UInt32]

    public init(positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [],
                indices: [UInt32] = []) {
        self.positions = positions
        self.normals = normals
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

    /// - Parameters:
    ///   - subdivisions: drives ring and segment counts; 12 is ample here.
    ///   - roughness: radial displacement as a fraction of the smallest
    ///     half-extent. Zero gives the exact rounded box.
    ///   - rounding: 0 is a hard box, 1 an inscribed ellipsoid. Real sarsens
    ///     sit close to the box end — enough to lose the machined edge, not so
    ///     much that they inflate into pillows.
    public static func build(_ stone: Stone, subdivisions: Int = 12,
                             roughness: Double = 0.06,
                             rounding: Double = 0.13) -> Mesh {
        let rings = max(6, subdivisions * 2)
        let segments = max(8, subdivisions * 3)

        // Megaliths sit in a socket, and a leaning one must: tipping a body
        // about the centre of its base lifts the far edge clear of the ground,
        // which reads as a stone hovering over its own shadow. The Heel Stone
        // leans 27°, so this is not a small effect.
        let halfThickness = stone.thickness / 2
        let sink = halfThickness * abs(sin(stone.lean.radians)) + 0.15

        let half = SIMD3<Double>(stone.width / 2,
                                 (stone.height + sink) / 2,
                                 stone.thickness / 2)
        // Local origin sits at ground level, so the body straddles it.
        let centre = SIMD3<Double>(0, half.y - sink, 0)
        // Displacement is scaled by the narrowest dimension so a slender stone
        // does not get lumps wider than itself.
        let smallestHalf = min(half.x, min(half.y, half.z))

        var noise = ValueNoise(seed: stone.seed)

        /// Surface point in the stone's own space, for a unit direction.
        func surface(_ direction: SIMD3<Double>) -> SIMD3<Double> {
            let d = simd_normalize(direction)

            // Where the ray leaves the box, and where it leaves the ellipsoid
            // inscribed in that same box. Blending the two knocks the corners
            // off without shortening the stone.
            //
            // The ellipsoid has to be scaled per axis. A sphere of the smallest
            // half-extent looks like the same idea and is not: on a stone three
            // times taller than it is thick it pulls the ends in by a third of
            // a metre, and the base lifts off the ground.
            let boxScale = max(abs(d.x) / half.x, max(abs(d.y) / half.y, abs(d.z) / half.z))
            let box = d / boxScale
            let ellipsoidScale = sqrt(pow(d.x / half.x, 2)
                                      + pow(d.y / half.y, 2)
                                      + pow(d.z / half.z, 2))
            let ellipsoid = d / ellipsoidScale
            var point = simd_mix(box, ellipsoid, SIMD3(repeating: rounding))

            if roughness > 0 {
                // Displaced along the direction, so the amount depends only on
                // where a vertex sits — not on which face claimed it. That is
                // what stops a welded surface tearing at its edges.
                var amount = noise.fbm(d * 2.4) * roughness * smallestHalf * 2

                // Fade the displacement out toward the waterline, and over a
                // generous band.
                //
                // The naive reason is that a lumpy surface crossing a flat
                // ground plane meets it in a comb rather than a line. The real
                // reason is harsher: near sunrise and sunset the sun sits a few
                // degrees up, and a shadow is stretched by 1/tan(altitude). At
                // 7° that is a factor of eight — so a three-centimetre bump at
                // the base throws a quarter-metre spike across the turf, and
                // the low-sun moments this app exists for are exactly when it
                // shows.
                let heightAboveGround = point.y + centre.y
                let fade = smoothstep(0.0, 1.6, heightAboveGround)
                amount *= fade

                point += d * amount
            }
            return point + centre
        }

        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        // One vertex per position: poles are single vertices and the longitude
        // seam reuses column zero, so there is no crack anywhere on the solid.
        positions.append(SIMD3<Float>(surface(SIMD3(0, 1, 0))))
        let northPole: UInt32 = 0

        for ring in 1..<rings {
            let phi = Double(ring) * .pi / Double(rings)
            for segment in 0..<segments {
                let theta = Double(segment) * 2 * .pi / Double(segments)
                let direction = SIMD3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta))
                positions.append(SIMD3<Float>(surface(direction)))
            }
        }

        positions.append(SIMD3<Float>(surface(SIMD3(0, -1, 0))))
        let southPole = UInt32(positions.count - 1)

        func index(ring: Int, segment: Int) -> UInt32 {
            UInt32(1 + (ring - 1) * segments + (segment % segments))
        }

        for segment in 0..<segments {
            indices.append(contentsOf: [northPole,
                                        index(ring: 1, segment: segment + 1),
                                        index(ring: 1, segment: segment)])
        }

        for ring in 1..<(rings - 1) {
            for segment in 0..<segments {
                let a = index(ring: ring, segment: segment)
                let b = index(ring: ring, segment: segment + 1)
                let c = index(ring: ring + 1, segment: segment + 1)
                let d = index(ring: ring + 1, segment: segment)
                indices.append(contentsOf: [a, b, c, a, c, d])
            }
        }

        for segment in 0..<segments {
            indices.append(contentsOf: [southPole,
                                        index(ring: rings - 1, segment: segment),
                                        index(ring: rings - 1, segment: segment + 1)])
        }

        var mesh = Mesh(positions: positions,
                        normals: [SIMD3<Float>](repeating: .zero, count: positions.count),
                        indices: indices)

        smoothNormals(&mesh, centre: SIMD3<Float>(centre))
        transform(&mesh, stone: stone)
        return mesh
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
}
