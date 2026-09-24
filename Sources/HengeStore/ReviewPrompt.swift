import Foundation

/// When to ask for an App Store rating, and whether we already have.
///
/// The system review sheet is Apple's to show or withhold — it rate-limits
/// itself to three prompts a year and shows nothing at all once the person
/// has rated — so the only decision that is ours is *when to ask*. That
/// decision is a value type here, in the module a test can build by hand,
/// rather than a counter buried in a view (AGENTS.md rule 4).
///
/// The rule: ask on the third launch, once per version. Three because the
/// first launch is curiosity and the second is a return, and it is the
/// third that says the app has earned a place. Once per version because a
/// person who has said no has said no; a new version is the only honest
/// reason to ask again, and Apple's own throttle sits behind that anyway.
///
/// Only the App Store build asks. The Mac disk image is not sold through
/// the store, so a prompt there would point at a listing that copy did not
/// come from. Same value that turns the paywall on and off: `StorePolicy`.
public struct ReviewPrompt: Sendable, Equatable {

    /// Launches before the first ask. The product decision, pinned by test.
    public static let threshold = 3

    /// Seconds into the qualifying launch before the sheet is requested.
    /// Long enough for the stones to be on screen and the person to be
    /// looking at them; a dialog over a still-loading scene is an ambush.
    public static let settleSeconds: TimeInterval = 20

    /// Launches recorded so far, this one included once `recordLaunch()`
    /// has run. Never negative.
    public private(set) var launches: Int

    /// The version string the prompt was last requested for, or nil if it
    /// never has been.
    public private(set) var askedVersion: String?

    public init(launches: Int = 0, askedVersion: String? = nil) {
        self.launches = max(0, launches)
        self.askedVersion = askedVersion
    }

    /// Count this launch.
    public mutating func recordLaunch() {
        launches += 1
    }

    /// Whether this launch is the one to ask on.
    ///
    /// - Parameters:
    ///   - policy: which build this is; only `.appStore` ever asks.
    ///   - version: the running app's version, for the once-per-version rule.
    public func shouldAsk(policy: StorePolicy, version: String) -> Bool {
        guard policy.isPaywalled else { return false }
        guard launches >= Self.threshold else { return false }
        return askedVersion != version
    }

    /// Remember that the request went out for this version. Recorded when
    /// we *ask*, not when Apple *shows*: the API gives no signal either way,
    /// and asking again on the next launch would be nagging.
    public mutating func markAsked(version: String) {
        askedVersion = version
    }

    // ── persistence ─────────────────────────────────────────────────────────

    /// The two keys, namespaced so a stray default cannot collide.
    static let launchesKey = "henge.review.launches"
    static let askedVersionKey = "henge.review.askedVersion"

    /// Read the state back. A fresh install reads as zero launches and no
    /// ask, which is exactly the state `init()` produces.
    public static func load(from defaults: UserDefaults) -> ReviewPrompt {
        ReviewPrompt(launches: defaults.integer(forKey: launchesKey),
                     askedVersion: defaults.string(forKey: askedVersionKey))
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(launches, forKey: Self.launchesKey)
        defaults.set(askedVersion, forKey: Self.askedVersionKey)
    }

    /// Test-harness support, same channel as the other `HENGE_UITEST_*`
    /// fixtures: a UI test or a screenshot run must never have the system
    /// sheet land on top of the thing it came to photograph.
    public static func isSuppressed(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["HENGE_UITEST_SUPPRESS_REVIEW"] != nil
    }
}
