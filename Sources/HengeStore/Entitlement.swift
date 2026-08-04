import Foundation

/// What the person at the screen has paid for.
public enum Entitlement: String, Sendable, Equatable, CaseIterable {

    /// Not purchased. The session clock is running.
    case trial

    /// The full version, bought once and owned.
    case full
}

/// The things access can be asked about.
///
/// An enum rather than a scatter of booleans so that adding a gated feature
/// forces every decision site to say what it thinks about it — the compiler
/// asks, instead of a missing check shipping quietly.
public enum Feature: String, Sendable, Equatable, CaseIterable {

    /// The monument, the sky and the day's scrubbing — everything the free
    /// fifteen minutes buy.
    case monument

    /// Setting the sky to an arbitrary date: the time machine. Premium from
    /// the first launch rather than after the timer, because it is the thing
    /// the purchase is *for* and a feature that vanishes mid-session teaches
    /// the wrong lesson about what was bought.
    case timeTravel
}

/// Whether this build sells anything at all.
///
/// StoreKit can only validate a purchase in an App Store–distributed app, and
/// Henge for Mac ships as a Developer ID disk image from river.io. A paywall
/// there would be a lock with no key: nothing could ever open it. So the Mac
/// build carries `directDownload` and is simply whole.
///
/// This is a value rather than a `#if os(macOS)` buried in the controller so
/// that both branches are reachable from a test. A compile-time switch is a
/// branch the oracle can only ever see one side of.
public struct StorePolicy: Sendable, Equatable {

    public let isPaywalled: Bool

    public init(isPaywalled: Bool) {
        self.isPaywalled = isPaywalled
    }

    /// iOS: sold through the App Store, so the paywall can be honoured.
    public static let appStore = StorePolicy(isPaywalled: true)

    /// macOS: direct download, no StoreKit, nothing to unlock.
    public static let directDownload = StorePolicy(isPaywalled: false)
}

/// The single place that answers "may they?".
///
/// Every gate in the UI reads this one value type, so the rules cannot drift
/// between the sheet that offers the purchase and the button that needs it.
public struct Access: Sendable, Equatable {

    public let policy: StorePolicy
    public let entitlement: Entitlement
    public let clock: TrialClock

    public init(policy: StorePolicy,
                entitlement: Entitlement,
                clock: TrialClock) {
        self.policy = policy
        self.entitlement = entitlement
        self.clock = clock
    }

    /// True when this build sells nothing, or the full version is owned.
    public var isUnlocked: Bool {
        !policy.isPaywalled || entitlement == .full
    }

    public func allows(_ feature: Feature) -> Bool {
        if isUnlocked { return true }
        switch feature {
        case .timeTravel:
            // Premium from the start; the countdown never buys it.
            return false
        case .monument:
            return !clock.hasExpired
        }
    }

    /// The paywall covers the scene: the session's fifteen minutes are gone.
    public var isLocked: Bool {
        !isUnlocked && clock.hasExpired
    }

    /// Whether to show the remaining time. Only while it is both running and
    /// meaningful — an owner should never be reminded of a clock they bought
    /// their way out of.
    public var showsCountdown: Bool {
        !isUnlocked && !clock.hasExpired
    }
}
