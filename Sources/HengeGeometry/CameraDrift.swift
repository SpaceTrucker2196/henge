import Foundation
import simd

/// The weight behind a dragged view.
///
/// A direct drag moves the camera exactly as far as the finger and stops dead
/// when the finger stops. That is precise, and it stays the default — but it
/// cannot make a slow pan, because no hand moves slowly and evenly enough to
/// look like a crane. Every attempt reads as a hand on a tripod.
///
/// So this gives the view mass. A drag is no longer a position, it is a push:
/// each delta hands the camera momentum, and momentum bleeds away on its own.
/// The view therefore lags the finger going in and coasts on coming out, which
/// is what a counterweighted head feels like.
///
/// Both halves are the same equation — one exponential — so the view takes up
/// speed as gradually as it sheds it, and never lurches. A model that eased in
/// and stopped short would read as lag rather than as weight.
///
/// What is *not* symmetric is the friction, and that was a correction from
/// trying it. The first version used one constant for both and stopped too
/// soon the moment the finger left: it tracked like a heavy head and settled
/// like a light one. So there are two constants. Under the hand you feel the
/// mass and the friction together; let go and only the friction is left, and
/// the view runs on past where you stopped. That overshoot is the crane move.
///
/// It lives here rather than in the view because a decision is being made —
/// how far the camera turns this frame — and a decision in a view is a
/// decision no test can reach.
///
/// ## The two properties that pin it
///
/// A push of *X* degrees eventually turns the view by exactly *X* degrees:
/// starting speed is `X / τ` and the integral of `(X/τ)·e^(−t/τ)` over all
/// time is `X`. Momentum spreads a drag out in time; it does not invent or
/// swallow travel. And a drag sustained at a steady rate settles at exactly
/// the speed a direct drag would have moved at, because the push arriving each
/// second balances the momentum lost each second. Nothing here needs
/// recalibrating against the direct path — it *is* the direct path, delayed.
public struct CameraDrift: Sendable, Equatable {

    /// Seconds for the view to take up — or shed — most of a change of speed
    /// *while the finger is down*.
    ///
    /// This number is the mass you feel against your hand. At a third of a
    /// second the view is unmistakably heavy without feeling broken: a flick
    /// still lands where you aimed it, and a slow push still starts smoothly.
    public static let defaultTimeConstant = 0.35

    /// Seconds for the view to shed its speed *after the finger has gone*.
    ///
    /// Longer than the tracking constant, and that asymmetry is deliberate —
    /// it was asked for after the first version was tried on the device, which
    /// tracked well and stopped too soon. Physically it is the difference
    /// between a bearing you are pushing against and the same bearing let go:
    /// while your hand is on it you feel the mass *and* the friction, and when
    /// you release it only the friction is left. The view keeps travelling
    /// after you stop, which is the whole point of a crane move.
    ///
    /// The ratio is what to change if the coast is still not long enough: at
    /// 0.9 against 0.35 a flick now carries a little over two and a half times
    /// as far as the finger itself moved.
    public static let defaultReleaseTimeConstant = 0.9

    /// Below this the view is not moving, it is drifting. A hundredth of a
    /// degree a second is a number rather than a motion, and letting it run
    /// forever would keep the renderer awake for nothing.
    public static let restingSpeed = 0.01

    /// The mass, as a time. Never zero — dividing by it is how a push becomes
    /// a speed.
    public var timeConstant: Double

    /// The friction left once the hand has gone.
    public var releaseTimeConstant: Double

    /// Degrees per second: `x` swings the view about the vertical, `y` tips it.
    public private(set) var velocity: SIMD2<Double>

    /// Whether a finger is still on the glass. Set by `push`, cleared by
    /// `release` — it chooses which of the two constants is spending the
    /// momentum this frame.
    public private(set) var isTracking = false

    public init(timeConstant: Double = CameraDrift.defaultTimeConstant,
                releaseTimeConstant: Double = CameraDrift.defaultReleaseTimeConstant) {
        self.timeConstant = max(timeConstant, 1e-3)
        self.releaseTimeConstant = max(releaseTimeConstant, 1e-3)
        self.velocity = .zero
    }

    /// Whichever constant is spending the momentum right now.
    private var activeConstant: Double {
        isTracking ? timeConstant : releaseTimeConstant
    }

    /// Whether there is still momentum worth spending a frame on.
    public var isMoving: Bool {
        abs(velocity.x) > Self.restingSpeed || abs(velocity.y) > Self.restingSpeed
    }

    /// Hand the view the momentum for a turn of `degrees`.
    ///
    /// The caller passes the angle a *direct* drag would have turned through,
    /// so the gain calibration stays in one place and this stays a physics
    /// question rather than a taste question.
    public mutating func push(_ degrees: SIMD2<Double>) {
        isTracking = true
        velocity += degrees / timeConstant
    }

    /// The finger has left the glass. From here the momentum runs on under
    /// the lighter friction, and the view carries past where the hand stopped.
    public mutating func release() { isTracking = false }

    /// Let the momentum run for an interval, and report how far the view turned.
    ///
    /// Integrated in closed form rather than stepped, so the answer does not
    /// depend on the frame rate. A ProMotion display and a 60 Hz display must
    /// agree about where a flick lands, or the same gesture means two things.
    public mutating func advance(by seconds: Double) -> SIMD2<Double> {
        guard seconds > 0, isMoving else {
            velocity = .zero
            return .zero
        }
        let tau = activeConstant
        let decay = exp(-seconds / tau)
        // ∫₀ˢ v₀·e^(−t/τ) dt = v₀·τ·(1 − e^(−s/τ))
        let travelled = velocity * tau * (1 - decay)
        velocity *= decay
        if !isMoving { velocity = .zero }
        return travelled
    }

    /// The view has run into something on the way round. Take the momentum
    /// out of that axis rather than letting it press against the stop, which
    /// would hold the camera pinned to the limit after the finger had gone.
    public mutating func stopTurning() { velocity.x = 0 }

    /// The view has run into the ground, or the top of the sky.
    public mutating func stopTilting() { velocity.y = 0 }

    /// Everything stops: a recentre, or a change of station.
    public mutating func stop() {
        velocity = .zero
        isTracking = false
    }
}
