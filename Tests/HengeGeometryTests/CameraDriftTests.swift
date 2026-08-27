import XCTest
import simd
@testable import HengeGeometry

/// The camera's momentum, checked against the exponential rather than against
/// itself.
///
/// Every fixture below is a number a reader can get from `e` and a pencil:
/// `1/e = 0.3679`, `1 − 1/e = 0.6321`, and the fact that the integral of a
/// decaying exponential over all time is its starting value times its time
/// constant. None of them were read off a run of this code.
final class CameraDriftTests: XCTestCase {

    /// Run a drift to a standstill and report how far the view turned.
    /// The step count is worked out once rather than accumulated, so that
    /// comparing two frame rates compares the frame rates and not the rounding
    /// error in a running total of sixtieths.
    private func coast(_ drift: inout CameraDrift,
                       seconds: Double,
                       step: Double = 1.0 / 120.0) -> SIMD2<Double> {
        var total = SIMD2<Double>.zero
        for _ in 0..<Int((seconds / step).rounded()) {
            total += drift.advance(by: step)
        }
        return total
    }

    // ── the travel is conserved ─────────────────────────────────────────────

    /// **Momentum spreads a drag out in time; it does not change how far it
    /// goes.**
    ///
    /// A push worth 30° must eventually turn the view 30°, because the drift
    /// starts at `30/τ` degrees a second and `∫₀^∞ (30/τ)·e^(−t/τ) dt = 30`.
    /// If this drifts, then smooth panning and direct panning disagree about
    /// what a gesture means, and the camera would arrive somewhere the finger
    /// did not ask for.
    func testAPushEventuallyTurnsTheViewTheDistanceItWasWorth() {
        var drift = CameraDrift()
        drift.push(SIMD2(30, -12))

        // Ten time constants: e^(−10) is 4.5e−5, so nothing measurable is left.
        let turned = coast(&drift, seconds: 10 * CameraDrift.defaultTimeConstant)

        XCTAssertEqual(turned.x, 30, accuracy: 0.01)
        XCTAssertEqual(turned.y, -12, accuracy: 0.01)
        XCTAssertFalse(drift.isMoving, "the view never came to rest")
    }

    // ── the coast runs on after the finger has gone ─────────────────────────

    /// **Letting go carries the view further than the finger travelled.**
    ///
    /// Asked for after the first version was tried on the device: it tracked
    /// well and stopped too soon. The fix is not more speed — the speed under
    /// the hand was right — but less friction once the hand has gone, so the
    /// ratio of the two time constants is exactly how much further a flick
    /// runs on. At 0.9 against 0.35 that is a little over two and a half
    /// times, and this asserts the number rather than the intention.
    func testReleasingCarriesFurtherThanTheDragItself() {
        let expected = CameraDrift.defaultReleaseTimeConstant
                     / CameraDrift.defaultTimeConstant

        var held = CameraDrift()
        held.push(SIMD2(30, 0))
        let whileTracking = coast(&held, seconds: 20)

        var released = CameraDrift()
        released.push(SIMD2(30, 0))
        released.release()
        let afterRelease = coast(&released, seconds: 20)

        // Under the hand, a push is worth exactly the angle it asked for.
        XCTAssertEqual(whileTracking.x, 30, accuracy: 0.05)
        // Let go, the same push runs on for the ratio of the two constants.
        XCTAssertEqual(afterRelease.x, 30 * expected, accuracy: 0.2)
        XCTAssertGreaterThan(afterRelease.x, whileTracking.x * 2,
                             "letting go barely changed the coast — the "
                             + "release friction is not being used")
    }

    /// **A release does not add speed, only distance.**
    ///
    /// The view must not lurch when the finger lifts. Momentum is conserved
    /// across the release; only the rate it is spent at changes. If this ever
    /// fails, letting go would kick the camera, which reads as a bug rather
    /// than as weight.
    func testReleasingDoesNotChangeTheSpeed() {
        var drift = CameraDrift()
        drift.push(SIMD2(30, -10))
        let before = drift.velocity
        drift.release()
        XCTAssertEqual(drift.velocity.x, before.x, accuracy: 1e-12)
        XCTAssertEqual(drift.velocity.y, before.y, accuracy: 1e-12)
    }

    // ── in and out are the same curve ───────────────────────────────────────

    /// **One time constant of coasting sheds exactly 1/e of the speed.**
    ///
    /// This is the definition of the time constant, and asserting it here is
    /// what makes "eases in exactly as it eases out" a fact about the code
    /// rather than a claim in a comment: there is one exponential, so the two
    /// halves cannot drift apart.
    func testOneTimeConstantShedsAllButOneOverE() {
        var drift = CameraDrift()
        let tau = CameraDrift.defaultTimeConstant
        drift.push(SIMD2(tau * 100, 0))          // exactly 100°/s to start with
        XCTAssertEqual(drift.velocity.x, 100, accuracy: 1e-9)

        _ = drift.advance(by: tau)

        XCTAssertEqual(drift.velocity.x, 100 * exp(-1), accuracy: 1e-9)
        XCTAssertEqual(drift.velocity.x, 36.7879, accuracy: 1e-3)
    }

    /// **The first time constant of a coast covers 63.2% of its travel.**
    ///
    /// `1 − 1/e` again, from the other side. Most of the movement happens
    /// early and the tail is long and slow, which is what "coasts to a stop"
    /// has to mean if it is not to read as an abrupt cut.
    func testMostOfTheTravelHappensInTheFirstTimeConstant() {
        var drift = CameraDrift()
        drift.push(SIMD2(100, 0))

        let early = drift.advance(by: CameraDrift.defaultTimeConstant)

        XCTAssertEqual(early.x, 100 * (1 - exp(-1)), accuracy: 1e-9)
        XCTAssertEqual(early.x, 63.212, accuracy: 1e-2)
    }

    // ── a held drag settles at the speed a direct drag would have moved ─────

    /// **Dragging steadily settles at the speed direct dragging would give.**
    ///
    /// The push arriving each second eventually balances the momentum lost
    /// each second, so a finger sweeping at a rate worth 60°/s ends up turning
    /// the view at 60°/s. This is why smooth panning needs no separate gain:
    /// hold the drag and you get the old behaviour, delayed by the mass.
    ///
    /// Tolerance is 3%: the balance is exact in the limit and about 1% off at
    /// a 120 Hz step, which is arithmetic rather than a defect.
    func testASustainedDragSettlesAtTheDirectSpeed() {
        var drift = CameraDrift()
        let step = 1.0 / 120.0
        let directSpeed = 60.0                   // degrees a second

        // Three seconds is over eight time constants of build-up.
        for _ in 0..<Int(3.0 / step) {
            drift.push(SIMD2(directSpeed * step, 0))
            _ = drift.advance(by: step)
        }

        XCTAssertEqual(drift.velocity.x, directSpeed,
                       accuracy: directSpeed * 0.03)
    }

    // ── the frame rate is not allowed to change the gesture ─────────────────

    /// **A flick lands in the same place at 60 Hz and at 120 Hz.**
    ///
    /// The decay is integrated in closed form for exactly this reason. A
    /// per-frame multiply would make the same push travel further on a slower
    /// display, so the identical gesture would mean two different things on an
    /// iPhone and on an external monitor.
    func testTheTravelDoesNotDependOnTheFrameRate() {
        var fast = CameraDrift()
        var slow = CameraDrift()
        var single = CameraDrift()
        fast.push(SIMD2(45, 20))
        slow.push(SIMD2(45, 20))
        single.push(SIMD2(45, 20))

        let atOneTwenty = coast(&fast, seconds: 1.0, step: 1.0 / 120.0)
        let atSixty = coast(&slow, seconds: 1.0, step: 1.0 / 60.0)
        let inOneGo = single.advance(by: 1.0)

        XCTAssertEqual(atOneTwenty.x, atSixty.x, accuracy: 1e-9)
        XCTAssertEqual(atOneTwenty.y, atSixty.y, accuracy: 1e-9)
        XCTAssertEqual(atOneTwenty.x, inOneGo.x, accuracy: 1e-9)
        XCTAssertEqual(atOneTwenty.y, inOneGo.y, accuracy: 1e-9)
    }

    // ── running into something ──────────────────────────────────────────────

    /// **A stop takes the momentum out of the axis that hit it, and leaves the
    /// other one running.**
    ///
    /// The ground is a stop. Without this the camera would sit pinned against
    /// the floor for as long as the momentum lasted, and a user who had let go
    /// would watch a view that would not settle.
    func testHittingAStopClearsOnlyThatAxis() {
        var drift = CameraDrift()
        drift.push(SIMD2(40, -40))

        drift.stopTilting()

        XCTAssertEqual(drift.velocity.y, 0)
        XCTAssertGreaterThan(drift.velocity.x, 1, "the swing was stopped too")
        let turned = drift.advance(by: 1.0)
        XCTAssertEqual(turned.y, 0)
        XCTAssertGreaterThan(turned.x, 0)
    }

    /// **A drift with no momentum reports no movement and costs nothing.**
    func testAStillViewStaysStill() {
        var drift = CameraDrift()
        XCTAssertFalse(drift.isMoving)
        XCTAssertEqual(drift.advance(by: 1.0), .zero)
    }
}
