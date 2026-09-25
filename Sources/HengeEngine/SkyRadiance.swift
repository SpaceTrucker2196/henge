import Foundation
import simd

/// The Preetham daylight model on the CPU — the same arithmetic as
/// `preethamSky` in `Henge.metal`, in `Float` so the two agree to the ulp.
///
/// Why it exists twice: `scene_fragment` used to evaluate the model four
/// times per fragment, and two of those — the zenith and the horizon toward
/// the sun, which feed the hemispheric ambient — depend on nothing that
/// changes across the frame. Evaluating them once here and handing them
/// down as uniforms removes two `acos`, a `tan`, eight `exp` and two cubic
/// polynomials from every stone, ground and blade fragment. The dome, the
/// reflection and the fog still sample the model per pixel because their
/// direction varies.
///
/// Preetham, Shirley & Smits, "A Practical Analytic Model for Daylight"
/// (SIGGRAPH 1999). Chosen over Hosek–Wilkie because it is closed form and
/// carries no coefficient table with its own licence.
/// The one number that ties the scene's linear units to the world's:
/// Preetham's zenith luminance is in kcd/m², and the shader has always
/// scaled it by 0.05, so one scene unit is 20 kcd/m² of luminance — and,
/// for irradiance, 20 klux. The sun's radiance is derived from the same
/// constant, so sun and sky share one scale and cannot drift apart.
public enum RadiometricScale {
    public static let kilocandelaPerUnit: Float = 20
}

public enum SkyRadiance {

    /// The zenith luminance `Y_z` in kcd/m², before the app's radiometric
    /// scale and the twilight fall-off. Exposed on its own because it is the
    /// one quantity in the model a reader can check against the paper by
    /// hand: with the sun at the zenith `θ_s = 0`, `χ = (4/9 − T/120)·π`.
    public static func zenithLuminance(turbidity t: Float, sunTheta: Float) -> Float {
        let chi = (4.0 / 9.0 - t / 120.0) * (Float.pi - 2.0 * sunTheta)
        return max((4.0453 * t - 4.9710) * tan(chi) - 0.2155 * t + 2.4192, 0)
    }

    /// Linear sRGB radiance of the sky in `direction`, in the scene's units
    /// (one unit is 20 kcd/m²: the paper's kcd/m² times 0.05), dimmed
    /// through twilight exactly as the shader dims it.
    public static func preetham(direction: SIMD3<Float>,
                                sun: SIMD3<Float>,
                                turbidity t: Float) -> SIMD3<Float> {
        let cosTheta = max(direction.y, 0.001)
        let cosGamma = min(max(simd_dot(direction, sun), -1), 1)
        let gamma = acos(cosGamma)
        let sunTheta = acos(min(max(sun.y, -1), 1))

        let A = SIMD3<Float>(-0.0193 * t - 0.2592, 0.1787 * t - 1.4630, -0.0167 * t - 0.2608)
        let B = SIMD3<Float>(-0.0665 * t + 0.0008, -0.3554 * t + 0.4275, -0.0950 * t + 0.0092)
        let C = SIMD3<Float>(-0.0004 * t + 0.2125, -0.0227 * t + 5.3251, -0.0079 * t + 0.2102)
        let D = SIMD3<Float>(-0.0641 * t - 0.8989, 0.1206 * t - 2.5771, -0.0441 * t - 1.6537)
        let E = SIMD3<Float>(-0.0033 * t + 0.0452, -0.0670 * t + 0.3703, -0.0109 * t + 0.0529)

        func exp3(_ v: SIMD3<Float>) -> SIMD3<Float> { SIMD3(exp(v.x), exp(v.y), exp(v.z)) }
        let cosSun = cos(sunTheta)
        let num = (1 + A * exp3(B / cosTheta))
                * (1 + C * exp3(D * gamma) + E * cosGamma * cosGamma)
        let den = (1 + A * exp3(B))
                * (1 + C * exp3(D * sunTheta) + E * cosSun * cosSun)
        let xyY = num / simd_max(den, SIMD3(repeating: 1e-4))

        let theta2 = sunTheta * sunTheta, theta3 = theta2 * sunTheta
        let zenithY = zenithLuminance(turbidity: t, sunTheta: sunTheta)
        let zenithx =
            (0.00165 * theta3 - 0.00375 * theta2 + 0.00209 * sunTheta) * t * t +
            (-0.02903 * theta3 + 0.06377 * theta2 - 0.03202 * sunTheta + 0.00394) * t +
            (0.11693 * theta3 - 0.21196 * theta2 + 0.06052 * sunTheta + 0.25886)
        let zenithy =
            (0.00275 * theta3 - 0.00610 * theta2 + 0.00317 * sunTheta) * t * t +
            (-0.04214 * theta3 + 0.08970 * theta2 - 0.04153 * sunTheta + 0.00516) * t +
            (0.15346 * theta3 - 0.26756 * theta2 + 0.06670 * sunTheta + 0.26688)

        let Y = zenithY * xyY.y
        let x = zenithx * xyY.x
        let y = zenithy * xyY.z
        let yFloor = max(y, 1e-4)
        let XYZ = SIMD3<Float>(x / yFloor * Y, Y, (1 - x - y) / yFloor * Y)
        let rgb = SIMD3<Float>(
            simd_dot(XYZ, SIMD3( 3.2406, -1.5372, -0.4986)),
            simd_dot(XYZ, SIMD3(-0.9689,  1.8758,  0.0415)),
            simd_dot(XYZ, SIMD3( 0.0557, -0.2040,  1.0570))
        )

        let dusk = smoothstep(0, 0.208, -sun.y)
        return simd_max(rgb, .zero) / RadiometricScale.kilocandelaPerUnit
             * (1 + (0.16 - 1) * dusk)
    }

    /// The two per-frame constants the fragment shaders read as uniforms:
    /// the zenith, and the horizon in the sun's azimuth lifted 0.12 (the
    /// same slight lift the shader used, so the horizon term never sits on
    /// the model's `cosTheta` floor).
    public static func ambientConstants(sun: SIMD3<Float>, turbidity: Float)
        -> (zenith: SIMD3<Float>, horizon: SIMD3<Float>) {
        let zenith = preetham(direction: SIMD3(0, 1, 0), sun: sun, turbidity: turbidity)
        let towardSun = simd_normalize(SIMD3(sun.x, 0.12, sun.z))
        let horizon = preetham(direction: towardSun, sun: sun, turbidity: turbidity)
        return (zenith, horizon)
    }

    /// MSL's `smoothstep`, kept here so the twilight curve is one expression
    /// on both sides.
    static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
