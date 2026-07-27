import Foundation

/// An angle that knows its own units.
///
/// Degree/radian confusion is the classic silent error in ephemeris code — it
/// does not crash, it just puts the sun in the wrong place. Making the unit
/// part of the type means the compiler catches what a test might not.
public struct Angle: Sendable, Hashable, Comparable, CustomStringConvertible {

    /// Canonical storage. Radians, because every trig call wants them.
    public let radians: Double

    public var degrees: Double { radians * 180.0 / .pi }

    public init(radians: Double) { self.radians = radians }
    public init(degrees: Double) { self.radians = degrees * .pi / 180.0 }

    /// Degrees, arcminutes, arcseconds — the form survey and catalogue data
    /// arrives in.
    public init(degrees d: Int, arcminutes m: Double, arcseconds s: Double = 0) {
        let magnitude = Double(abs(d)) + m / 60.0 + s / 3600.0
        self.init(degrees: d < 0 ? -magnitude : magnitude)
    }

    public static let zero = Angle(radians: 0)

    /// Wrapped into [0, 360). Right for azimuths, longitudes, hour angles.
    public var normalized: Angle {
        let full = 2 * Double.pi
        var r = radians.truncatingRemainder(dividingBy: full)
        if r < 0 { r += full }
        return Angle(radians: r)
    }

    /// Wrapped into (-180, +180]. Right for differences and hour angles that
    /// need a sign — an hour angle of 359° is really -1°.
    public var signedNormalized: Angle {
        var d = normalized.degrees
        if d > 180 { d -= 360 }
        return Angle(degrees: d)
    }

    public var sine: Double { sin(radians) }
    public var cosine: Double { cos(radians) }
    public var tangent: Double { tan(radians) }

    public var description: String { String(format: "%.6f°", degrees) }

    public static func < (a: Angle, b: Angle) -> Bool { a.radians < b.radians }
    public static func + (a: Angle, b: Angle) -> Angle { Angle(radians: a.radians + b.radians) }
    public static func - (a: Angle, b: Angle) -> Angle { Angle(radians: a.radians - b.radians) }
    public static func * (a: Angle, s: Double) -> Angle { Angle(radians: a.radians * s) }
    public static func * (s: Double, a: Angle) -> Angle { Angle(radians: a.radians * s) }
    public static prefix func - (a: Angle) -> Angle { Angle(radians: -a.radians) }

    /// Shortest separation between two angles, always in [0, 180].
    public func separation(to other: Angle) -> Angle {
        Angle(degrees: abs((self - other).signedNormalized.degrees))
    }
}

public extension Double {
    var degrees: Angle { Angle(degrees: self) }
    var radians: Angle { Angle(radians: self) }
}
