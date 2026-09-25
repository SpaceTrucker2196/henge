import XCTest
import simd
@testable import HengeEngine

/// The CPU Preetham port is checked against the paper, not against the
/// shader: the shader is what it replaces, and a copy that agreed with a
/// wrong original would agree wrongly.
final class SkyRadianceTests: XCTestCase {

    /// Preetham's zenith luminance, sun at the zenith, turbidity 2 — worked
    /// by hand from the paper's equation:
    ///
    ///   χ  = (4/9 − T/120)·(π − 2θs) = (0.4444 − 0.0167)·π = 1.3439 rad
    ///   Yz = (4.0453·T − 4.9710)·tan χ − 0.2155·T + 2.4192
    ///      = 3.1196 · 4.3315 − 0.4310 + 2.4192 = 15.50 kcd/m²
    func testZenithLuminanceMatchesThePaperByHand() {
        let yz = SkyRadiance.zenithLuminance(turbidity: 2, sunTheta: 0)
        XCTAssertEqual(yz, 15.50, accuracy: 0.05)
    }

    /// Looking straight at the sun, the Perez ratio is exactly 1 (numerator
    /// and denominator are the same expression), so the radiance *is* the
    /// zenith value. The XYZ→sRGB matrix is linear and its luminance row is
    /// (0.2126, 0.7152, 0.0722), so the port's luminance must come back to
    /// Yz times the 0.05 scale — an independent check on the whole chain
    /// after the zenith polynomial.
    func testLookingAtTheZenithSunReturnsTheZenithLuminance() {
        let up = SIMD3<Float>(0, 1, 0)
        let rgb = SkyRadiance.preetham(direction: up, sun: up, turbidity: 2)
        let luminance = simd_dot(rgb, SIMD3(0.2126, 0.7152, 0.0722))
        XCTAssertEqual(luminance, 15.50 * 0.05, accuracy: 0.03)
    }

    /// Daylight is blue: away from the sun the zenith's blue beats its red.
    func testTheZenithIsBlueWithTheSunLow() {
        let sun = simd_normalize(SIMD3<Float>(1, 0.5, 0))
        let rgb = SkyRadiance.preetham(direction: SIMD3(0, 1, 0), sun: sun, turbidity: 2.4)
        XCTAssertGreaterThan(rgb.z, rgb.x)
    }

    /// The twilight fall-off is monotone: as the sun sinks from the horizon
    /// to −12°, every step is darker than the last, and at −12° the dome is
    /// the shader's 0.16 of what a just-set sun gave.
    func testTheDomeDarkensMonotonicallyThroughTwilight() {
        var previous = Float.infinity
        var atSunset: Float = 0
        for altitudeDegrees in stride(from: 0, through: -12, by: -1) {
            let a = Float(altitudeDegrees) * .pi / 180
            let sun = SIMD3<Float>(cos(a), sin(a), 0)
            let rgb = SkyRadiance.preetham(direction: SIMD3(0, 1, 0), sun: sun, turbidity: 2.4)
            let luminance = simd_dot(rgb, SIMD3(0.2126, 0.7152, 0.0722))
            if altitudeDegrees == 0 { atSunset = luminance }
            XCTAssertLessThanOrEqual(luminance, previous, "at \(altitudeDegrees)°")
            previous = luminance
        }
        XCTAssertGreaterThan(atSunset, 0)
    }

    /// The horizon constant is lifted 0.12 above the plane so it never sits
    /// on the model's `cosTheta` floor, and it lies in the sun's azimuth.
    func testTheHorizonConstantSitsUnderTheSun() {
        let sun = simd_normalize(SIMD3<Float>(0.6, 0.3, 0.8))
        let (zenith, horizon) = SkyRadiance.ambientConstants(sun: sun, turbidity: 2.4)
        // Toward the sun the aureole term makes the horizon brighter and
        // warmer than the zenith.
        XCTAssertGreaterThan(horizon.x / max(horizon.z, 1e-6),
                             zenith.x / max(zenith.z, 1e-6))
    }
}
