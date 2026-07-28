import Foundation
import simd
import HengeGeometry

/// Layouts shared with `Shaders/Henge.metal`.
///
/// Swift and MSL agree here by hand, not by generated header, because the
/// shaders are compiled from source at load (see FACTORY.md). Every field is
/// 16-byte aligned or padded to it — MSL's `float3` occupies 16 bytes, and a
/// mismatch shows up as geometry in the wrong place rather than as an error.
public struct FrameUniforms {
    public var viewProjection: float4x4
    public var view: float4x4
    public var projection: float4x4
    public var cameraPosition: SIMD4<Float>
    /// Unit vector toward the sun, w unused.
    public var sunDirection: SIMD4<Float>
    /// Linear HDR radiance of the sun, w = angular radius in radians.
    public var sunRadiance: SIMD4<Float>
    /// Three cascade matrices, world → shadow clip space.
    public var shadowMatrices: (float4x4, float4x4, float4x4)
    /// Inverse of `viewProjection`, so the sky pass can unproject without
    /// inverting a matrix per pixel.
    public var inverseViewProjection: float4x4
    /// View-space split depths for cascade selection, w unused.
    public var cascadeSplits: SIMD4<Float>
    /// x: turbidity, y: exposure, z: seconds since start, w: shadow texel size.
    public var skyParameters: SIMD4<Float>
    /// Unit vector toward the moon, w = its angular radius in radians.
    public var moonDirection: SIMD4<Float>
    /// rgb: moonlight radiance. w: illuminated fraction, 0 new to 1 full.
    public var moonLight: SIMD4<Float>
    /// Half-extent in metres of each cascade's orthographic box, w unused.
    ///
    /// PCSS needs it twice over: to turn a shadow-map depth difference back
    /// into metres of blocker-to-receiver distance, and to turn the resulting
    /// penumbra width back into UV. Without it the softening would have to be
    /// a tuned constant, which is exactly what it must not be — the whole
    /// point is that the penumbra follows from the sun's angular size.
    public var cascadeRadii: SIMD4<Float>

    public init(viewProjection: float4x4 = matrix_identity_float4x4,
                view: float4x4 = matrix_identity_float4x4,
                projection: float4x4 = matrix_identity_float4x4,
                cameraPosition: SIMD4<Float> = .zero,
                sunDirection: SIMD4<Float> = SIMD4(0, 1, 0, 0),
                sunRadiance: SIMD4<Float> = SIMD4(1, 1, 1, 0.00465),
                shadowMatrices: (float4x4, float4x4, float4x4) =
                    (matrix_identity_float4x4, matrix_identity_float4x4, matrix_identity_float4x4),
                inverseViewProjection: float4x4 = matrix_identity_float4x4,
                cascadeSplits: SIMD4<Float> = SIMD4(20, 60, 200, 0),
                skyParameters: SIMD4<Float> = SIMD4(2.2, 1, 0, 1.0 / 2048.0),
                moonDirection: SIMD4<Float> = SIMD4(0, -1, 0, 0.0045),
                moonLight: SIMD4<Float> = .zero,
                cascadeRadii: SIMD4<Float> = SIMD4(24, 90, 320, 0)) {
        self.viewProjection = viewProjection
        self.view = view
        self.projection = projection
        self.cameraPosition = cameraPosition
        self.sunDirection = sunDirection
        self.sunRadiance = sunRadiance
        self.shadowMatrices = shadowMatrices
        self.inverseViewProjection = inverseViewProjection
        self.cascadeSplits = cascadeSplits
        self.skyParameters = skyParameters
        self.moonDirection = moonDirection
        self.moonLight = moonLight
        self.cascadeRadii = cascadeRadii
    }
}

/// Per-draw material and transform.
public struct DrawUniforms {
    public var model: float4x4
    public var normalMatrix: float4x4
    /// Linear albedo, w = roughness.
    public var albedo: SIMD4<Float>
    /// x: 0 for a stone (triplanar), 1 for the ground (tiled by world XZ).
    /// y: metres covered by one tile of the texture.
    /// z: normal-map strength. w: 1 when textured, 0 for flat shading.
    public var surface: SIMD4<Float>

    public init(model: float4x4 = matrix_identity_float4x4,
                normalMatrix: float4x4 = matrix_identity_float4x4,
                albedo: SIMD4<Float> = SIMD4(0.55, 0.53, 0.48, 0.85),
                surface: SIMD4<Float> = SIMD4(0, 1.4, 1.0, 1)) {
        self.model = model
        self.normalMatrix = normalMatrix
        self.albedo = albedo
        self.surface = surface
    }
}

/// One vertex, matching the MSL `Vertex` struct.
public struct MeshVertex {
    public var position: SIMD3<Float>
    public var normal: SIMD3<Float>

    public init(position: SIMD3<Float>, normal: SIMD3<Float>) {
        self.position = position
        self.normal = normal
    }
}

/// Materials the monument is built from.
///
/// Values are plausible dielectric albedos rather than measured spectra; M2
/// replaces them with something sourced. Flagged so nobody mistakes them for
/// survey data.
public enum SurfaceMaterial {
    /// Pale grey-brown silcrete.
    public static let sarsen = SIMD4<Float>(0.52, 0.49, 0.44, 0.88)
    /// Darker, blue-grey spotted dolerite.
    public static let bluestone = SIMD4<Float>(0.34, 0.36, 0.41, 0.80)
    /// Chalk grassland.
    public static let turf = SIMD4<Float>(0.28, 0.32, 0.18, 0.95)
    /// Weathered chalk, for the Aubrey holes.
    public static let chalk = SIMD4<Float>(0.74, 0.72, 0.66, 0.92)

    public static func albedo(for material: StoneMaterial) -> SIMD4<Float> {
        switch material {
        case .sarsen: sarsen
        case .bluestone: bluestone
        case .chalk: chalk
        }
    }
}
