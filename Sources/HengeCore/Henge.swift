import Foundation

/// Identity of the product, in one place, so the apps and the tests agree.
///
/// SCAFFOLD: this is the whole of HengeCore right now. It exists so the
/// oracle (`make test`) is real and green from the first commit rather than
/// asserting nothing. The first domain type replaces it — see MISSION.md,
/// which is deliberately unwritten until the owner sets the mission.
public enum Henge {

    /// Display name. The bundle carries its own copy for the Info.plist; this
    /// is the one the engine and any generated output should use.
    public static let name = "Henge"

    /// Marketing version. `project.yml` sets MARKETING_VERSION for the app
    /// targets; keep the two in step — `HengeCoreTests` checks the shape, not
    /// the value, so bumping one without the other will not fail the suite.
    public static let version = SemanticVersion(major: 0, minor: 0, patch: 1)
}

/// A three-component version, comparable, with a lossless string form.
///
/// Small enough to be obviously correct and real enough to carry assertions —
/// the point is that the suite exercises behaviour, not that it counts files.
public struct SemanticVersion: Sendable, Hashable, Comparable, CustomStringConvertible {

    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parses `"1.4.2"`. Returns nil for anything that is not exactly three
    /// non-negative integers — a partial parse would be a worse answer than
    /// no answer, because callers would ship the wrong version silently.
    public init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        guard let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2]),
              major >= 0, minor >= 0, patch >= 0 else { return nil }
        self.init(major: major, minor: minor, patch: patch)
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
