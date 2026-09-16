import Foundation
import simd

/// How much of the frame to spend, decided where a test can reach it.
///
/// Measured on the iPad Pro (M5) at the midsummer sunrise, 2026-09-15: the
/// frame is fill-rate bound — 0.7× the pixels took it from 30 to 48 fps —
/// and the three 2048² shadow cascades are worth about four milliseconds.
/// The numbers are in ROADMAP.md's research note. This type turns them into
/// two decisions per device, kept out of the renderer so the renderer only
/// applies them.
public struct RenderBudget: Equatable, Sendable {

    /// Fraction of the drawable's width and height the scene is drawn at
    /// before MetalFX lifts it to native. 1 is native, no upscaling.
    public var renderScale: Float
    /// Square size of each shadow cascade.
    public var shadowResolution: Int

    /// The scale the measurement chose: half the pixels, with the spatial
    /// upscaler putting the detail back.
    public static let upscaledRenderScale: Float = 0.7
    /// Drawables at or under this many pixels are drawn native: a small Mac
    /// window is already cheap, and the upscaler's own cost is not free.
    public static let nativeBelowPixels = 2_000_000

    public static func resolve(drawablePixels: Int, isPhone: Bool,
                               upscalingAvailable: Bool) -> RenderBudget {
        RenderBudget(
            renderScale: upscalingAvailable && drawablePixels > nativeBelowPixels
                ? upscaledRenderScale : 1,
            // A phone's screen is a third the area of the iPad's and its
            // GPU the weaker; 1024² cascades on it lose nothing an eye
            // catches and buy back the milliseconds measured.
            shadowResolution: isPhone ? 1024 : 2048)
    }

    /// The renderer's own oracle path — `renderOffscreen`, the eye of the
    /// shadow-agreement test — draws native at full cascades, always, so no
    /// measurement moves when a budget changes.
    public static let oracle = RenderBudget(renderScale: 1, shadowResolution: 2048)
}

/// What the shadow cascades were fitted to, so a frame can tell whether they
/// need fitting again.
public struct ShadowKey: Equatable, Sendable {
    public var light: SIMD3<Float>
    public var cameraPosition: SIMD3<Float>
    public var cameraForward: SIMD3<Float>
    public var aspect: Float
    public var fieldOfView: Float
    /// Bumped whenever the geometry the cascades see changes — a scene
    /// load, or every frame of a monument transition.
    public var sceneStamp: Int

    public init(light: SIMD3<Float>, cameraPosition: SIMD3<Float>,
                cameraForward: SIMD3<Float>, aspect: Float, fieldOfView: Float,
                sceneStamp: Int) {
        self.light = light
        self.cameraPosition = cameraPosition
        self.cameraForward = cameraForward
        self.aspect = aspect
        self.fieldOfView = fieldOfView
        self.sceneStamp = sceneStamp
    }
}

/// Whether the shadow pass must run again this frame.
///
/// The cascades are three full renders of the monument and the plain; at
/// rest, or with time running at one second a second, nothing they depend
/// on has moved enough to see. At 1× the sun crosses a hundredth of a
/// degree in two and a half seconds, and a shadow drawn from a direction
/// that stale is a millimetre off at ten metres. Scrubbing, the era sweep
/// and a moving camera all cross the thresholds every frame, so they refit
/// every frame, as they must.
public enum ShadowRefit {

    /// Light direction change that forces a refit: 0.01°.
    public static let lightAngle: Float = 0.01 * .pi / 180
    /// Camera movement that forces a refit: two centimetres.
    public static let cameraDistance: Float = 0.02
    /// Camera turn that forces a refit: 0.02°.
    public static let cameraAngle: Float = 0.02 * .pi / 180

    public static func needed(from old: ShadowKey?, to new: ShadowKey) -> Bool {
        guard let old else { return true }
        if old.sceneStamp != new.sceneStamp { return true }
        if old.aspect != new.aspect || old.fieldOfView != new.fieldOfView { return true }
        if simd_length(old.cameraPosition - new.cameraPosition) > cameraDistance { return true }
        if angle(old.light, new.light) > lightAngle { return true }
        if angle(old.cameraForward, new.cameraForward) > cameraAngle { return true }
        return false
    }

    /// The angle between two directions, by atan2 of the cross and dot
    /// products rather than acos of the dot: near parallel, acos loses the
    /// whole angle to single-precision rounding — 0.02° came out as zero and
    /// the test for it failed — while the cross product keeps it.
    static func angle(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let la = simd_length(a), lb = simd_length(b)
        guard la > 0, lb > 0 else { return la == lb ? 0 : .pi }
        return atan2(simd_length(simd_cross(a, b)), simd_dot(a, b))
    }
}
