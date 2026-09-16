import XCTest
import simd
@testable import HengeEngine

/// The frame budget and the shadow-refit rule, held to the numbers the iPad
/// measured rather than to the renderer that applies them.
final class RenderBudgetTests: XCTestCase {

    // ── the budget ──────────────────────────────────────────────────────────

    func testAnIPadDrawableIsUpscaledAndAPhoneGetsSmallerCascades() {
        let ipad = RenderBudget.resolve(drawablePixels: 2752 * 2064, isPhone: false,
                                        upscalingAvailable: true)
        XCTAssertEqual(ipad.renderScale, 0.7)
        XCTAssertEqual(ipad.shadowResolution, 2048)

        let phone = RenderBudget.resolve(drawablePixels: 1206 * 2622, isPhone: true,
                                         upscalingAvailable: true)
        XCTAssertEqual(phone.renderScale, 0.7)
        XCTAssertEqual(phone.shadowResolution, 1024)
    }

    func testASmallWindowAndADeviceWithoutMetalFXDrawNative() {
        let window = RenderBudget.resolve(drawablePixels: 1280 * 800, isPhone: false,
                                          upscalingAvailable: true)
        XCTAssertEqual(window.renderScale, 1)
        let simulator = RenderBudget.resolve(drawablePixels: 2752 * 2064, isPhone: false,
                                             upscalingAvailable: false)
        XCTAssertEqual(simulator.renderScale, 1)
    }

    func testTheOracleIsNativeAtFullCascades() {
        XCTAssertEqual(RenderBudget.oracle.renderScale, 1)
        XCTAssertEqual(RenderBudget.oracle.shadowResolution, 2048)
    }

    // ── the refit rule ──────────────────────────────────────────────────────

    private func key(light: SIMD3<Float> = simd_normalize(SIMD3(0.5, 0.3, -0.6)),
                     position: SIMD3<Float> = SIMD3(0, 1.7, 0),
                     forward: SIMD3<Float> = SIMD3(0, 0, -1),
                     aspect: Float = 1.5, fov: Float = 62, stamp: Int = 1) -> ShadowKey {
        ShadowKey(light: light, cameraPosition: position, cameraForward: forward,
                  aspect: aspect, fieldOfView: fov, sceneStamp: stamp)
    }

    private func turned(_ v: SIMD3<Float>, byDegrees d: Float) -> SIMD3<Float> {
        let axis = simd_normalize(simd_cross(v, SIMD3<Float>(0, 1, 0)))
        let q = simd_quatf(angle: d * .pi / 180, axis: axis)
        return simd_normalize(q.act(v))
    }

    func testTheFirstFrameAlwaysFits() {
        XCTAssertTrue(ShadowRefit.needed(from: nil, to: key()))
    }

    func testAnUnmovedFrameKeepsItsCascades() {
        XCTAssertFalse(ShadowRefit.needed(from: key(), to: key()))
    }

    /// At one second a second the sun crosses a hundredth of a degree in
    /// about 2.5 s: a fit that stale is a millimetre off at ten metres.
    func testTheSunMayCreepButNotStride() {
        let old = key()
        let crept = key(light: turned(old.light, byDegrees: 0.005))
        XCTAssertFalse(ShadowRefit.needed(from: old, to: crept))
        let strode = key(light: turned(old.light, byDegrees: 0.02))
        XCTAssertTrue(ShadowRefit.needed(from: old, to: strode))
    }

    func testTheCameraMayBreatheButNotWalkOrTurn() {
        let old = key()
        XCTAssertFalse(ShadowRefit.needed(from: old, to: key(position: SIMD3(0.01, 1.7, 0))))
        XCTAssertTrue(ShadowRefit.needed(from: old, to: key(position: SIMD3(0.05, 1.7, 0))))
        XCTAssertFalse(ShadowRefit.needed(from: old, to: key(forward: turned(old.cameraForward, byDegrees: 0.01))))
        XCTAssertTrue(ShadowRefit.needed(from: old, to: key(forward: turned(old.cameraForward, byDegrees: 0.05))))
    }

    func testAChangedSceneOrLensRefits() {
        let old = key()
        XCTAssertTrue(ShadowRefit.needed(from: old, to: key(stamp: 2)))
        XCTAssertTrue(ShadowRefit.needed(from: old, to: key(aspect: 1.6)))
        XCTAssertTrue(ShadowRefit.needed(from: old, to: key(fov: 40)))
    }
}
