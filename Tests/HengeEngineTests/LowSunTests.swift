import XCTest
import Metal
import simd
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// Shadows at the hours the monument is about.
///
/// The renderer spent five milestones drawing no shadow between sunrise and
/// half a degree of altitude: the cascade fit was gated on
/// `sunDirection.y > 0.01`, which reads like a guard against a degenerate
/// below-horizon light and is really a guard against 0.573° of sky — the exact
/// window the definition of done lives in.
///
/// The first version of this suite failed to catch it, which is worth more than
/// the fix. It measured shadow on the **ground**, and at 0.3° altitude the
/// ground is lit at an incidence of 89.7°: it receives almost nothing, so
/// removing the sun from it removes almost nothing, and the frame reads the
/// same whether shadows are drawn or not. The measurements were identical to
/// three significant figures with the bug present and absent.
///
/// At sunrise the shadow lives on the **vertical faces**, which are lit nearly
/// head-on — which is also where you see it at the monument, the Heel Stone's
/// shadow thrown across the uprights. So these tests are differential: render a
/// receiving stone alone, render it again with a caster upwind, and require the
/// second to be darker. That difference is zero when the cascades are not fitted.
@MainActor
final class LowSunTests: XCTestCase {

    static let size = 320

    private func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; low-sun shadows unverified here.")
        }
        return device
    }

    /// Mean brightness of the receiving stone's sunward face.
    ///
    /// The sun is due east at a grazing altitude, so shadows run west. The
    /// receiver stands 30 m west of the caster; the camera sits west of the
    /// caster too, looking at the receiver, so the caster itself is behind the
    /// camera and never enters the frame. Any change in the measurement is
    /// therefore a shadow and nothing else.
    ///
    /// Direct light only, by default. With the atmosphere modelled, the sun
    /// a third of a degree up delivers about 40 lux to a face that the
    /// sunrise sky lights with kilolux — the shadow is real and a
    /// thousandth of the face's brightness, which eight bits cannot hold.
    /// The suite exists to catch the cascades not being fitted below 0.573°,
    /// so it measures the sun's term alone, exposed so that the sun's own
    /// luminance lands at one fixed display level whatever its altitude:
    /// with the fit present the shadow is the whole of the light, and
    /// without it there is no shadow at all, which is exactly 0.0 %.
    private func receiverBrightness(sunAltitude: Double, withCaster: Bool,
                                    skyLight: Bool = false) throws -> Double {
        let device = try makeDevice()

        let receiver = Stone(id: "receiver", position: SIMD3(-30, 0, 0),
                             height: 6.0, width: 4.0, thickness: 1.2, material: .sarsen)
        let caster = Stone(id: "caster", position: SIMD3(0, 0, 0),
                           height: 7.0, width: 8.0, thickness: 1.2, material: .sarsen)
        let stones = withCaster ? [receiver, caster] : [receiver]

        var camera = Camera(position: SIMD3(-16, 3.5, 9), target: SIMD3(-30, 3, 0))
        camera.near = 0.4
        camera.far = 300

        let sun = HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                       azimuth: Angle(degrees: 90))
        var state = SceneState(sun: sun, camera: camera, turbidity: 2.4, exposure: 1.6,
                               surfaceTexturing: false, weathering: false,
                               grassBlades: false)
        state.skyLight = skyLight
        if !skyLight {
            // Sun luminance × exposure = 3.5 puts a sunlit face near the
            // middle of the tone curve — about 115 of 255 — whether the sun
            // is a third of a degree up or five.
            let luminance = simd_dot(state.sunRadiance, SIMD3(0.2126, 0.7152, 0.0722))
            state.exposure = 3.5 / max(luminance, 1e-6)
        }
        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 2048)
        try renderer.load(scene: MonumentScene(stones: stones))

        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                             mipmapLevel: 0)
        }

        // Average the middle of the frame, which is the receiver's face.
        var total = 0.0
        var count = 0
        for y in (Self.size / 3)..<(Self.size * 2 / 3) {
            for x in (Self.size / 3)..<(Self.size * 2 / 3) {
                let offset = (y * Self.size + x) * 4
                let b = Double(pixels[offset])
                let g = Double(pixels[offset + 1])
                let r = Double(pixels[offset + 2])
                total += 0.2126 * r + 0.7152 * g + 0.0722 * b
                count += 1
            }
        }
        return total / Double(count)
    }

    /// How much darker the receiver gets when something stands in front of it.
    private func shadowDepth(sunAltitude: Double) throws -> Double {
        let lit = try receiverBrightness(sunAltitude: sunAltitude, withCaster: false)
        let shaded = try receiverBrightness(sunAltitude: sunAltitude, withCaster: true)
        guard lit > 1 else { return 0 }
        return (lit - shaded) / lit
    }

    /// **The regression.** A third of a degree above the horizon, one stone
    /// must darken another.
    func testAStoneShadowsAnotherAtSunrise() throws {
        let depth = try shadowDepth(sunAltitude: 0.3)
        // Five percent. The number was first set against an observed 8.7%
        // with the sky's light included and a hand-tuned sun a hundred times
        // brighter than the atmosphere allows on the horizon; with the sun
        // computed and the sky switched off the measured depth is nearly
        // the whole of the light. The threshold stays where it was: what the
        // assertion separates is "a shadow" from "no shadow at all", and no
        // shadow at all is exactly 0.0%.
        XCTAssertGreaterThan(depth, 0.05,
                             "the receiver darkened by only \(depth * 100)% at 0.3° — "
                             + "the sun is up and nothing is casting")
    }

    /// The old gate's blind spot was everything below 0.573°. Each of these
    /// used to draw flat.
    func testTheOldGatesBlindSpotIsCovered() throws {
        for altitude in [0.05, 0.2, 0.4, 0.55] {
            let depth = try shadowDepth(sunAltitude: altitude)
            XCTAssertGreaterThan(depth, 0.05,
                                 "no shadow at \(altitude)°: \(depth * 100)%")
        }
    }

    /// A control well above the horizon, so a failure above reads as "low sun
    /// broken" rather than "shadows broken".
    ///
    /// Five degrees, not twenty. A seven-metre stone at 20° throws its shadow
    /// only 19 m and the receiver stands at 30 m, so that control failed for
    /// trigonometry rather than for anything the renderer did — and at 10° the
    /// shadow clears the receiver's foot but not its middle, where this
    /// measures. Both are correct behaviour, which is why the control moved
    /// rather than the tolerance.
    func testShadowsAlsoWorkWellAboveTheHorizon() throws {
        XCTAssertGreaterThan(try shadowDepth(sunAltitude: 5), 0.05)
    }

    /// Below the horizon there is no sun, so there is nothing to shadow — the
    /// case the original threshold was reaching for, and still correct.
    func testNothingIsLitBelowTheHorizon() throws {
        // The sky on and the app's exposure: this is a claim about the
        // picture, not about the cascades.
        let brightness = try receiverBrightness(sunAltitude: -3, withCaster: false,
                                                skyLight: true)
        XCTAssertLessThan(brightness, 110, "the stone is sunlit with the sun down")
    }
}
