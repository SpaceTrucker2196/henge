import XCTest
@testable import HengeStore

/// When the app asks for a rating.
///
/// Apple decides whether the sheet appears; we only decide whether to ask.
/// Each rule below is stated against a launch count a reader can tally on
/// their fingers, never against the implementation's own opinion.
final class ReviewPromptTests: XCTestCase {

    private let version = "1.2"

    /// **The threshold is three launches.** The product decision, pinned so
    /// a refactor cannot quietly make the app pushier or shyer.
    func testTheThresholdIsThreeLaunches() {
        XCTAssertEqual(ReviewPrompt.threshold, 3)
    }

    /// **Launches one and two never ask; the third does.**
    func testAsksOnTheThirdLaunchAndNotBefore() {
        var prompt = ReviewPrompt()

        prompt.recordLaunch()
        XCTAssertFalse(prompt.shouldAsk(policy: .appStore, version: version),
                       "first launch is curiosity")
        prompt.recordLaunch()
        XCTAssertFalse(prompt.shouldAsk(policy: .appStore, version: version),
                       "second launch is a return")
        prompt.recordLaunch()
        XCTAssertTrue(prompt.shouldAsk(policy: .appStore, version: version),
                      "third launch is the ask")
    }

    /// **Once asked, the same version never asks again**, however many
    /// launches follow. A no is a no.
    func testAsksOncePerVersion() {
        var prompt = ReviewPrompt(launches: 3)
        XCTAssertTrue(prompt.shouldAsk(policy: .appStore, version: version))

        prompt.markAsked(version: version)
        XCTAssertFalse(prompt.shouldAsk(policy: .appStore, version: version))

        for _ in 0..<20 { prompt.recordLaunch() }
        XCTAssertFalse(prompt.shouldAsk(policy: .appStore, version: version),
                       "twenty more launches of the same version stay quiet")
    }

    /// **A new version may ask again.** The only honest reason to; Apple's
    /// own three-a-year throttle sits behind it.
    func testANewVersionMayAskAgain() {
        var prompt = ReviewPrompt(launches: 3)
        prompt.markAsked(version: "1.2")

        XCTAssertTrue(prompt.shouldAsk(policy: .appStore, version: "1.3"))
    }

    /// **The direct-download build never asks.** No storefront, nothing to
    /// rate, and the Mac disk image did not come from the listing the sheet
    /// would point at.
    func testDirectDownloadNeverAsks() {
        let prompt = ReviewPrompt(launches: 30)
        XCTAssertFalse(prompt.shouldAsk(policy: .directDownload,
                                        version: version))
    }

    /// **State survives a relaunch.** Written to defaults and read back
    /// equal; a fresh suite reads as a fresh install.
    func testRoundTripsThroughDefaults() throws {
        let suite = "henge.tests.review.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(ReviewPrompt.load(from: defaults), ReviewPrompt(),
                       "a fresh install is zero launches, never asked")

        var prompt = ReviewPrompt()
        prompt.recordLaunch()
        prompt.recordLaunch()
        prompt.markAsked(version: version)
        prompt.save(to: defaults)

        XCTAssertEqual(ReviewPrompt.load(from: defaults), prompt)
    }

    /// **The harness can silence it.** Same environment channel as the
    /// other fixtures; inert unless named.
    func testHarnessSuppression() {
        XCTAssertFalse(ReviewPrompt.isSuppressed(environment: [:]))
        XCTAssertTrue(ReviewPrompt.isSuppressed(
            environment: ["HENGE_UITEST_SUPPRESS_REVIEW": "1"]))
    }
}
