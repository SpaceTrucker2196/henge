import Foundation

/// The free session's fifteen minutes, and what is left of them.
///
/// The budget refills at every launch rather than burning down once for all
/// time. That is a deliberate choice about what the app is: someone who opens
/// Henge to see where the sun is standing this morning should get their
/// answer, today and tomorrow, without paying — what the purchase buys is the
/// long sitting and the freedom of the calendar, not admission.
///
/// Two properties matter enough to be tested rather than assumed, and both
/// exist because a clock is a hostile input:
///
/// 1. **Time never runs backwards.** The system clock is the user's to set,
///    and a trial that refunds itself when the phone crosses a timezone is a
///    trial with a workaround printed on it.
/// 2. **A suspended app is not a spent app.** `Date()` keeps counting while
///    iOS has the process parked in the background; a delta measured across
///    that gap is an hour the user never saw. `maximumStep` is what stops a
///    single resume from swallowing the whole budget.
public struct TrialClock: Sendable, Equatable {

    /// Fifteen minutes, in seconds.
    public static let budget: TimeInterval = 15 * 60

    /// The most one `advance(by:)` may charge, however long the wall clock
    /// says it has been. The caller ticks about sixty times a second, so any
    /// step near this ceiling is a resume from suspension rather than honest
    /// elapsed use, and is charged as a single second instead of as the gap.
    ///
    /// Undercounting is the safe direction to be wrong in: it spends the
    /// error on the user's side.
    public static let maximumStep: TimeInterval = 1

    /// Seconds spent, never above `budget` and never below zero.
    public private(set) var consumed: TimeInterval

    public init(consumed: TimeInterval = 0) {
        self.consumed = Self.clamp(consumed)
    }

    /// Spend part of the budget.
    ///
    /// Refuses anything that is not a positive, finite number of seconds:
    /// a NaN delta out of a stalled clock would otherwise poison `consumed`
    /// permanently, and every comparison against it would then be false.
    public mutating func advance(by seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
        consumed = Self.clamp(consumed + min(seconds, Self.maximumStep))
    }

    /// Seconds left in the session; never negative.
    public var remaining: TimeInterval { Self.budget - consumed }

    public var hasExpired: Bool { remaining <= 0 }

    /// The countdown as it is read aloud: `m:ss`, rounded up so the last
    /// second reads "0:01" rather than sitting on "0:00" while still running.
    public var formattedRemaining: String {
        let whole = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private static func clamp(_ seconds: TimeInterval) -> TimeInterval {
        guard seconds.isFinite else { return 0 }
        return min(max(seconds, 0), budget)
    }
}
