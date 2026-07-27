import Foundation
import simd

/// Matrix helpers, written out rather than pulled from a library.
///
/// Metal's clip space runs z from 0 at the near plane to 1 at the far plane —
/// not −1 to 1 as OpenGL does. Getting that wrong produces a scene that looks
/// almost right and a depth buffer that is quietly useless, so the projections
/// here are built for Metal's convention deliberately.
public enum MetalMath {

    /// Right-handed perspective, reverse-Z off (near maps to 0).
    public static func perspective(fovyRadians: Float, aspect: Float,
                                   near: Float, far: Float) -> float4x4 {
        let y = 1 / tan(fovyRadians * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        return float4x4(columns: (
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1),
            SIMD4<Float>(0, 0, z * near, 0)
        ))
    }

    /// Right-handed orthographic — what the shadow cascades render through.
    public static func orthographic(left: Float, right: Float, bottom: Float,
                                    top: Float, near: Float, far: Float) -> float4x4 {
        let rl = right - left, tb = top - bottom, fn = far - near
        return float4x4(columns: (
            SIMD4<Float>(2 / rl, 0, 0, 0),
            SIMD4<Float>(0, 2 / tb, 0, 0),
            SIMD4<Float>(0, 0, -1 / fn, 0),
            SIMD4<Float>(-(right + left) / rl, -(top + bottom) / tb, -near / fn, 1)
        ))
    }

    public static func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>,
                              up: SIMD3<Float> = SIMD3(0, 1, 0)) -> float4x4 {
        let f = normalize(target - eye)
        // Guard the degenerate case where the view direction is parallel to up,
        // which happens the moment a camera looks straight down at the plan view.
        let safeUp = abs(dot(f, normalize(up))) > 0.999 ? SIMD3<Float>(0, 0, 1) : up
        let s = normalize(cross(f, safeUp))
        let u = cross(s, f)
        return float4x4(columns: (
            SIMD4<Float>(s.x, u.x, -f.x, 0),
            SIMD4<Float>(s.y, u.y, -f.y, 0),
            SIMD4<Float>(s.z, u.z, -f.z, 0),
            SIMD4<Float>(-dot(s, eye), -dot(u, eye), dot(f, eye), 1)
        ))
    }

    public static func translation(_ t: SIMD3<Float>) -> float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
        return m
    }

    public static func scale(_ s: Float) -> float4x4 {
        float4x4(diagonal: SIMD4<Float>(s, s, s, 1))
    }

    /// Correct normal transform: the inverse transpose. For the rigid
    /// transforms the monument uses this equals the model matrix, but the
    /// stones will eventually be scaled and then it will not.
    public static func normalMatrix(from model: float4x4) -> float4x4 {
        model.inverse.transpose
    }
}

/// A camera as the app thinks about it.
public struct Camera: Sendable {

    public var position: SIMD3<Float>
    public var target: SIMD3<Float>
    public var fieldOfView: Float
    public var near: Float
    public var far: Float

    public init(position: SIMD3<Float> = SIMD3(0, 12, 46),
                target: SIMD3<Float> = SIMD3(0, 3, 0),
                fieldOfView: Float = 55 * .pi / 180,
                near: Float = 0.2,
                far: Float = 40_000) {
        self.position = position
        self.target = target
        self.fieldOfView = fieldOfView
        self.near = near
        self.far = far
    }

    public func view() -> float4x4 { MetalMath.lookAt(eye: position, target: target) }

    public func projection(aspect: Float) -> float4x4 {
        MetalMath.perspective(fovyRadians: fieldOfView, aspect: aspect, near: near, far: far)
    }

    /// Orbit at a given distance and bearing — the M1 camera control.
    public static func orbiting(distance: Float, azimuthDegrees: Float,
                                elevationDegrees: Float,
                                target: SIMD3<Float> = SIMD3(0, 3, 0)) -> Camera {
        let az = azimuthDegrees * .pi / 180
        let el = max(-1.4, min(1.4, elevationDegrees * .pi / 180))
        // Azimuth from north through east, matching the astronomy convention:
        // +X east, +Y up, +Z south.
        let offset = SIMD3<Float>(
            distance * cos(el) * sin(az),
            distance * sin(el),
            -distance * cos(el) * cos(az)
        )
        return Camera(position: target + offset, target: target)
    }
}
