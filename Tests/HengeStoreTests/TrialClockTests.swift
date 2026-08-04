import XCTest
@testable import HengeStore

/// The session clock.
///
/// A trial timer is a piece of arithmetic sitting directly on top of a hostile
/// input — the system clock, which the user owns and may set to anything at
/// all. These are the properties that stop it being either exploitable or
/// unfair, and each one is stated against a number worked out by hand rather
/// than against the implementation's own opinion.
final class TrialClockTests: XCTestCase {

    /// **The budget is fifteen minutes.** Nine hundred seconds; the product
    /// decision, pinned so a refactor cannot quietly re-price the free tier.
    func testTheBudgetIsFifteenMinutes() {
        XCTAssertEqual(TrialClock.budget, 900, accuracy: 1e-9)
    }

    /// **Spending reduces what is left, second for second.**
    ///
    /// Sixty steps of one second is one minute gone, and fourteen left of the
    /// fifteen — arithmetic a reader can redo without opening the source.
    func testSpendingReducesTheRemainder() {
        var clock = TrialClock()
        XCTAssertEqual(clock.remaining, 900, accuracy: 1e-9)

        for _ in 0..<60 { clock.advance(by: 1) }

        XCTAssertEqual(clock.consumed, 60, accuracy: 1e-9)
        XCTAssertEqual(clock.remaining, 840, accuracy: 1e-9,
                       "a minute of one-second ticks should leave 14:00")
        XCTAssertFalse(clock.hasExpired)
    }

    /// **The clock never runs backwards.**
    ///
    /// A negative delta is what a device reports when its owner winds the
    /// clock back — across a timezone, or on purpose. Crediting it would print
    /// the workaround on the box: set the date back, get the trial again.
    func testTimeIsNeverRefunded() {
        var clock = TrialClock()
        clock.advance(by: 1)
        let afterOneSecond = clock.consumed

        clock.advance(by: -600)
        clock.advance(by: -0.001)

        XCTAssertEqual(clock.consumed, afterOneSecond, accuracy: 1e-9,
                       "a backwards clock refunded trial time")
    }

    /// **A stalled clock cannot poison the budget.**
    ///
    /// NaN propagates through every comparison as `false`, so a single NaN
    /// delta reaching `consumed` would leave `hasExpired` permanently false —
    /// an unlimited trial produced by arithmetic rather than by decision.
    func testNonFiniteDeltasAreRefused() {
        var clock = TrialClock()
        clock.advance(by: .nan)
        clock.advance(by: .infinity)
        clock.advance(by: -.infinity)

        XCTAssertEqual(clock.consumed, 0, accuracy: 1e-9)
        XCTAssertTrue(clock.remaining.isFinite,
                      "a non-finite delta reached the budget")
    }

    /// **An hour in the background costs a second, not an hour.**
    ///
    /// `Date()` keeps counting while iOS has the process parked. The delta
    /// measured across a resume is wall-clock time the user never saw, and
    /// charging it would end the session while the phone was in a pocket.
    func testASuspendedAppIsNotASpentApp() {
        var clock = TrialClock()
        clock.advance(by: 3600)

        XCTAssertEqual(clock.consumed, TrialClock.maximumStep, accuracy: 1e-9,
                       "an hour-long background gap was charged in full")
        XCTAssertFalse(clock.hasExpired,
                       "one resume from the background ended the session")
    }

    /// **The budget floors at zero and stays there.**
    ///
    /// Fifteen hundred one-second ticks is well past nine hundred; remaining
    /// must sit at exactly zero rather than going negative and formatting as
    /// "-10:00".
    func testTheRemainderNeverGoesNegative() {
        var clock = TrialClock()
        for _ in 0..<1500 { clock.advance(by: 1) }

        XCTAssertEqual(clock.consumed, 900, accuracy: 1e-9)
        XCTAssertEqual(clock.remaining, 0, accuracy: 1e-9)
        XCTAssertTrue(clock.hasExpired)
        XCTAssertEqual(clock.formattedRemaining, "0:00")
    }

    /// **A clock restored out of range is brought into it.**
    func testInitialisationClampsToTheBudget() {
        XCTAssertEqual(TrialClock(consumed: -50).consumed, 0, accuracy: 1e-9)
        XCTAssertEqual(TrialClock(consumed: 5000).consumed, 900, accuracy: 1e-9)
        XCTAssertEqual(TrialClock(consumed: .nan).consumed, 0, accuracy: 1e-9)
    }

    /// **The countdown reads the way a clock reads.**
    ///
    /// Rounded up, so a running trial never displays "0:00" while it is still
    /// running — the display hits zero at the same moment the session does.
    func testTheCountdownFormatsAsMinutesAndSeconds() {
        XCTAssertEqual(TrialClock().formattedRemaining, "15:00")

        // 900 − 61 = 839 s = 13 min 59 s.
        var clock = TrialClock(consumed: 61)
        XCTAssertEqual(clock.formattedRemaining, "13:59")

        // A part-second left still reads as a second remaining.
        clock = TrialClock(consumed: 899.5)
        XCTAssertEqual(clock.formattedRemaining, "0:01")
    }
}
