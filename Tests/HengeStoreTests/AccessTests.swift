import XCTest
@testable import HengeStore

/// Who may do what.
///
/// `Access` is the only thing in the app that answers that question, which is
/// the point: the sheet that offers the purchase and the button that needs one
/// read the same value, so they cannot come to different conclusions. These
/// tests walk every branch of it, including the one a `#if os(macOS)` would
/// have hidden from the oracle entirely.
final class AccessTests: XCTestCase {

    private func access(_ policy: StorePolicy,
                        _ entitlement: Entitlement,
                        consumed: TimeInterval = 0) -> Access {
        Access(policy: policy,
               entitlement: entitlement,
               clock: TrialClock(consumed: consumed))
    }

    // ── the paid build ──────────────────────────────────────────────────────

    /// **A fresh trial may look at the monument but not travel.**
    ///
    /// Time travel is what the purchase is *for*, so it is premium from the
    /// first frame. A feature that worked for fourteen minutes and then
    /// vanished would teach the user it was broken, not that it was paid.
    func testAFreshTrialSeesTheMonumentButCannotTravel() {
        let fresh = access(.appStore, .trial)

        XCTAssertTrue(fresh.allows(.monument))
        XCTAssertFalse(fresh.allows(.timeTravel),
                       "time travel was free during the trial")
        XCTAssertFalse(fresh.isLocked)
        XCTAssertTrue(fresh.showsCountdown)
        XCTAssertFalse(fresh.isUnlocked)
    }

    /// **Time travel stays shut for the whole trial, not just the end of it.**
    ///
    /// Checked one second in and one second before expiry, because a gate
    /// written as `hasExpired ? denied : allowed` would pass the first of
    /// those and fail the intent.
    func testTimeTravelIsClosedForEverySecondOfTheTrial() {
        for consumed in [0.0, 1.0, 450.0, 899.0] {
            let a = access(.appStore, .trial, consumed: consumed)
            XCTAssertFalse(a.allows(.timeTravel),
                           "time travel opened \(consumed) s into the trial")
        }
    }

    /// **When the fifteen minutes are gone, the scene closes and the paywall
    /// stands.**
    func testAnExpiredTrialIsLocked() {
        let spent = access(.appStore, .trial, consumed: TrialClock.budget)

        XCTAssertFalse(spent.allows(.monument),
                       "the scene stayed open past the session's end")
        XCTAssertFalse(spent.allows(.timeTravel))
        XCTAssertTrue(spent.isLocked)
        XCTAssertFalse(spent.showsCountdown,
                       "a spent clock was still counting down")
    }

    /// **The full version owns everything, and is never shown a clock.**
    ///
    /// Including when the session clock happens to have run out underneath —
    /// buying at 14:59 must not leave a paywall on screen for a second.
    func testTheFullVersionIsWholeEvenOnASpentClock() {
        let owner = access(.appStore, .full, consumed: TrialClock.budget)

        XCTAssertTrue(owner.isUnlocked)
        XCTAssertTrue(owner.allows(.monument))
        XCTAssertTrue(owner.allows(.timeTravel))
        XCTAssertFalse(owner.isLocked,
                       "a purchase left the paywall standing")
        XCTAssertFalse(owner.showsCountdown,
                       "an owner was reminded of the clock they bought out of")
    }

    // ── the direct-download build ───────────────────────────────────────────

    /// **The Mac disk image is whole, always.**
    ///
    /// StoreKit can only validate a purchase in an App Store–distributed app,
    /// and Henge for Mac ships as a Developer ID download from river.io. A
    /// paywall there would be a lock with no key in existence. This is the
    /// branch a compile-time `#if os(macOS)` would have made untestable, which
    /// is why the policy is a value.
    func testTheDirectDownloadBuildIsNeverGated() {
        for entitlement in Entitlement.allCases {
            for consumed in [0.0, TrialClock.budget, TrialClock.budget * 2] {
                let a = access(.directDownload, entitlement, consumed: consumed)

                XCTAssertTrue(a.isUnlocked)
                XCTAssertTrue(a.allows(.monument))
                XCTAssertTrue(a.allows(.timeTravel),
                              "the Mac build gated time travel")
                XCTAssertFalse(a.isLocked,
                               "the Mac build raised a paywall it cannot open")
                XCTAssertFalse(a.showsCountdown,
                               "the Mac build ran a trial countdown")
            }
        }
    }

    /// **Every feature is decided, none defaulted.**
    ///
    /// Walks `Feature.allCases` so that adding a case without teaching
    /// `Access` about it shows up here rather than in the field.
    func testEveryFeatureIsAllowedOnceUnlocked() {
        let owner = access(.appStore, .full)
        for feature in Feature.allCases {
            XCTAssertTrue(owner.allows(feature),
                          "\(feature) was withheld from a paying owner")
        }
    }

    /// **The policies genuinely differ.** A guard against both constants
    /// drifting to the same value in some future edit, which would silently
    /// either free the iOS build or gate the Mac one.
    func testTheTwoPoliciesAreNotTheSame() {
        XCTAssertTrue(StorePolicy.appStore.isPaywalled)
        XCTAssertFalse(StorePolicy.directDownload.isPaywalled)
    }
}
