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
/// A quarried sarsen is a boulder, not a brick: the approach is to subdivide a
/// box and push every vertex along its normal by layered value noise, seeded
/// from the stone's id. Deterministic on purpose — the shadow tests need the
/// same stone in the same place on every run, and an artist's random would
/// make the oracle flaky.
public enum StoneMeshBuilder {

    /// - Parameter subdivisions: per box face. 12 is enough to read as stone
    ///   without drowning the vertex count; the tests use 2 for speed.
    public static func build(_ stone: Stone, subdivisions: Int = 12,
                             roughness: Double = 0.06) -> Mesh {
        var mesh = Mesh()
        let hw = stone.width / 2
        let ht = stone.thickness / 2
        let h = stone.height

        var noise = ValueNoise(seed: stone.seed)

        // Six faces of a box, each a subdivided grid in local space where the
        // stone stands at the origin, base at y = 0.
        typealias V3 = SIMD3<Double>
        let faces: [(origin: V3, u: V3, v: V3)] = [
            (V3(-hw, 0, -ht), V3(2 * hw, 0, 0), V3(0, h, 0)),        // front
            (V3(hw, 0, ht), V3(-2 * hw, 0, 0), V3(0, h, 0)),         // back
            (V3(-hw, 0, ht), V3(0, 0, -2 * ht), V3(0, h, 0)),        // left
            (V3(hw, 0, -ht), V3(0, 0, 2 * ht), V3(0, h, 0)),         // right
            (V3(-hw, h, -ht), V3(2 * hw, 0, 0), V3(0, 0, 2 * ht)),   // top
            (V3(-hw, 0, ht), V3(2 * hw, 0, 0), V3(0, 0, -2 * ht))    // bottom
        ]

        for face in faces {
            let faceNormal = normalize(cross(face.u, face.v))
            var positions: [SIMD3<Float>] = []
            var normals: [SIMD3<Float>] = []
            var indices: [UInt32] = []

            let n = subdivisions
            for i in 0...n {
                for j in 0...n {
                    let s = Double(i) / Double(n)
                    let t = Double(j) / Double(n)
                    var p = face.origin + face.u * s + face.v * t

                    // Displace along the face normal. Taper the displacement to
                    // zero at the base so stones sit flush in the ground rather
                    // than hovering on a lumpy footing.
                    let groundFade = min(1.0, p.y / 0.4)
                    let amount = noise.fbm(p * 1.7) * roughness * stone.width * groundFade
                    p += faceNormal * amount

                    positions.append(SIMD3<Float>(p))
                    normals.append(SIMD3<Float>(faceNormal))
                }
            }

            for i in 0..<n {
                for j in 0..<n {
                    let a = UInt32(i * (n + 1) + j)
                    let b = UInt32((i + 1) * (n + 1) + j)
                    let c = UInt32((i + 1) * (n + 1) + j + 1)
                    let d = UInt32(i * (n + 1) + j + 1)
                    indices.append(contentsOf: [a, b, c, a, c, d])
                }
            }

            mesh.append(Mesh(positions: positions, normals: normals, indices: indices))
        }

        recomputeNormals(&mesh)
        transform(&mesh, stone: stone)
        return mesh
    }

    /// Smooth normals from the displaced surface, so the lighting follows the
    /// rock rather than the box it started as.
    static func recomputeNormals(_ mesh: inout Mesh) {
        var accumulated = [SIMD3<Float>](repeating: .zero, count: mesh.positions.count)
        for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
            let i0 = Int(mesh.indices[triangle])
            let i1 = Int(mesh.indices[triangle + 1])
            let i2 = Int(mesh.indices[triangle + 2])
            let e1 = mesh.positions[i1] - mesh.positions[i0]
            let e2 = mesh.positions[i2] - mesh.positions[i0]
            let faceNormal = cross(e1, e2)
            accumulated[i0] += faceNormal
            accumulated[i1] += faceNormal
            accumulated[i2] += faceNormal
        }
        mesh.normals = accumulated.map { n in
            let len = length(n)
            return len > 1e-6 ? n / len : SIMD3<Float>(0, 1, 0)
        }
    }

    /// Local space → world: lean, then bearing, then translate.
    static func transform(_ mesh: inout Mesh, stone: Stone) {
        let cosLean = Float(cos(stone.lean.radians))
        let sinLean = Float(sin(stone.lean.radians))
        let cosBearing = Float(cos(stone.bearing.radians))
        let sinBearing = Float(sin(stone.bearing.radians))
        let origin = SIMD3<Float>(stone.position)

        for i in mesh.positions.indices {
            let p = mesh.positions[i]
            // Lean tips the stone in its own +Z, before the bearing rotation.
            let leaned = SIMD3<Float>(p.x, p.y * cosLean - p.z * sinLean,
                                      p.y * sinLean + p.z * cosLean)
            let rotated = SIMD3<Float>(
                leaned.x * cosBearing + leaned.z * sinBearing,
                leaned.y,
                leaned.x * sinBearing - leaned.z * cosBearing
            )
            mesh.positions[i] = rotated + origin

            let n = mesh.normals[i]
            let nLeaned = SIMD3<Float>(n.x, n.y * cosLean - n.z * sinLean,
                                       n.y * sinLean + n.z * cosLean)
            mesh.normals[i] = SIMD3<Float>(
                nLeaned.x * cosBearing + nLeaned.z * sinBearing,
                nLeaned.y,
                nLeaned.x * sinBearing - nLeaned.z * cosBearing
            )
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
