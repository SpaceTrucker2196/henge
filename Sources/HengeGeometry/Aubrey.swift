import Foundation
import HengeAstro

/// The 56 Aubrey Holes as an eclipse counter.
///
/// **This is the modern hypothesis, and it ships badged as one.** Fred Hoyle
/// proposed in 1966 that markers moved around the fifty-six holes could track
/// the sun, moon and nodes well enough to predict eclipses. The arithmetic is
/// genuinely striking — 56 divides neatly into all three periods — but nothing
/// excavated from the holes supports it, they held cremated human bone, and
/// Ruggles' assessment is that the case was never made.
///
/// So this does not simulate Hoyle's marker-shuffling, which would be a
/// simulation of an argument rather than of anything. It projects the *real*
/// computed positions onto the ring and lets you see the alignment arrive.
/// That is testable against the ephemeris, which the marker game is not, and it
/// makes the honest point better: the ring works because 56 happens to fit,
/// not because the holes remember anything.
///
/// The three periods, and why 56:
///
/// - The sun goes round the ecliptic in 365.24 days. 56 holes at 2 holes per
///   13 days is 364 days — a fortnight's marker step, wrong by a day a year.
/// - The moon goes round in 27.32 days. 2 holes a day is 28 days.
/// - The nodes regress once in 18.61 years. 3 holes a year is 18.67 years.
///
/// Hoyle, 'Stonehenge — an eclipse predictor', *Nature* 211 (1966).
/// Ruggles, *Astronomy in Prehistoric Britain and Ireland*, ch. 3.
public enum AubreyRing {

    /// The holes, as everyone counts them.
    public static let holeCount = 56

    /// Where a longitude falls on the ring, as a fractional hole index.
    ///
    /// Hole 0 sits at the monument's axis, so the ring is oriented to the
    /// building rather than to the equinox — which is the only orientation the
    /// hypothesis could have had.
    public static func hole(for longitude: HengeAstro.Angle) -> Double {
        longitude.normalized.degrees / 360 * Double(holeCount)
    }

    /// Whole-hole index, for placing a marker.
    public static func marker(for longitude: HengeAstro.Angle) -> Int {
        Int(hole(for: longitude).rounded()) % holeCount
    }

    /// Where the sun, moon and ascending node sit on the ring at a moment.
    public struct Markers: Sendable, Hashable {
        public let sun: Double
        public let moon: Double
        public let node: Double

        /// Holes between the sun and the nearer node — either of them, since
        /// the nodes are half a ring apart and an eclipse season arrives at
        /// both. Runs 0 to 14, and an eclipse season is when it closes to
        /// about three.
        ///
        /// Measuring to the ascending node alone reads 28 when the sun is at
        /// the descending one, which silently halves the seasons the ring can
        /// find. That the counter must see *both* nodes is the reason Hoyle's
        /// third marker moves on the ring at all rather than being a number
        /// someone remembers.
        public var sunToNode: Double {
            min(AubreyRing.separation(sun, node),
                AubreyRing.separation(sun, node + Double(AubreyRing.holeCount) / 2))
        }
        /// Holes between the moon and the sun — zero at new, 28 at full.
        public var moonToSun: Double { AubreyRing.separation(moon, sun) }
    }

    public static func markers(at tt: JulianDay) -> Markers {
        Markers(sun: hole(for: Sun.position(at: tt).apparentLongitude),
                moon: hole(for: Moon.position(at: tt).longitude),
                node: hole(for: Moon.ascendingNode(at: tt)))
    }

    /// Distance around the ring the short way, in holes: 0 to 28.
    public static func separation(_ a: Double, _ b: Double) -> Double {
        let count = Double(holeCount)
        let gap = abs(a - b).truncatingRemainder(dividingBy: count)
        return min(gap, count - gap)
    }

    /// What the ring says about eclipse risk, in the ring's own units.
    ///
    /// Meeus's solar ecliptic limit of 18.5° is 2.9 holes and the lunar limit
    /// of 12.2° is 1.9 — so "within three holes of a node at a syzygy" is the
    /// counter's whole rule, and it is not far off. Reported in holes on
    /// purpose: this is what the ring can say, not what the ephemeris knows.
    public static func isEclipseSeason(at tt: JulianDay, holes: Double = 3) -> Bool {
        markers(at: tt).sunToNode <= holes
    }

    /// The note that must accompany any presentation of this.
    public static var note: LoreNote {
        Lore.monument.first { $0.id == "monument.aubrey" }!
    }
}
