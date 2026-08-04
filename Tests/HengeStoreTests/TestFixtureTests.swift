import XCTest
@testable import HengeStore

/// The harness door.
///
/// `applyTestFixture` exists so the expired paywall can be photographed
/// without sitting in front of a simulator for a quarter of an hour. A door
/// like that is only acceptable while it is provably shut by default, which
/// is what these two tests are for.
@MainActor
final class TestFixtureTests: XCTestCase {

    /// **Shut unless asked for by name.** An empty environment — and an
    /// environment full of other variables — must leave the clock untouched.
    func testTheFixtureIsInertWithoutItsVariable() {
        let store = PurchaseController(policy: .appStore)
        store.applyTestFixture(environment: [:])
        XCTAssertEqual(store.clock.consumed, 0, accuracy: 1e-9)

        store.applyTestFixture(environment: ["HOME": "/tmp", "LANG": "en_US"])
        XCTAssertEqual(store.clock.consumed, 0, accuracy: 1e-9,
                       "an unrelated environment moved the trial clock")
    }

    /// **Open when it is.** Seeding the full budget puts the session at its
    /// end, which is the state the paywall screenshot needs.
    func testTheFixtureSeedsTheClockWhenAsked() {
        let store = PurchaseController(policy: .appStore)
        store.applyTestFixture(
            environment: ["HENGE_UITEST_TRIAL_CONSUMED": "900"])

        XCTAssertTrue(store.clock.hasExpired)
        XCTAssertTrue(store.access.isLocked)
        XCTAssertFalse(store.access.allows(.monument))
    }

    /// **Garbage is ignored rather than obeyed.** A malformed value must not
    /// throw and must not silently zero the clock somebody was relying on.
    func testTheFixtureIgnoresAValueItCannotRead() {
        let store = PurchaseController(policy: .appStore)
        store.advance(byRealSeconds: 1)
        let before = store.clock.consumed

        store.applyTestFixture(
            environment: ["HENGE_UITEST_TRIAL_CONSUMED": "not a number"])

        XCTAssertEqual(store.clock.consumed, before, accuracy: 1e-9)
    }

    /// **A direct-download build is unlocked before any of this matters.**
    /// Seeding a spent clock on the Mac policy must still leave the app whole
    /// — the clock is simply not what that build is gated on.
    func testSeedingASpentClockCannotLockTheMacBuild() {
        let store = PurchaseController(policy: .directDownload)
        store.applyTestFixture(
            environment: ["HENGE_UITEST_TRIAL_CONSUMED": "900"])

        XCTAssertFalse(store.access.isLocked)
        XCTAssertTrue(store.access.allows(.timeTravel))
    }
}
