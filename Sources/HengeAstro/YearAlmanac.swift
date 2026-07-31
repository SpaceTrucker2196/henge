import Foundation

/// One civil year, solved as a strip of time: the eight stations of the
/// wheel, every new and full moon, and where any instant falls along it.
///
/// This exists for the year bar. The solvers are all elsewhere — the wheel's
/// stations from apparent solar longitude, the syzygies from elongation —
/// and each carries its own fixtures; what this adds is the *window*: one
/// calendar year, everything inside it, in order. Keyed to the civil year
/// deliberately: "this year" on a calendar strip means January to December
/// to the person reading it, and the wheel's own year (Imbolc to Imbolc)
/// would put the strip's edges mid-season.
public enum YearAlmanac {

    public struct Year: Sendable {
        public let year: Int
        /// Midnight UT opening 1 January.
        public let start: JulianDay
        /// Midnight UT opening the next 1 January.
        public let end: JulianDay
        /// The wheel's eight, in the order the sun reaches them (UT).
        public let stations: [(station: WheelStation, instant: JulianDay)]
        /// Syzygies within the year (UT), ascending.
        public let newMoons: [JulianDay]
        public let fullMoons: [JulianDay]

        /// Where an instant falls along the strip, 0 at the year's opening
        /// midnight and 1 at the next. Not clamped: the caller decides what
        /// to do with a moment outside the year.
        public func fraction(of instant: JulianDay) -> Double {
            (instant.value - start.value) / (end.value - start.value)
        }
    }

    public static func solve(year: Int) -> Year {
        let start = JulianDay(CalendarDate(year: year, month: 1, day: 1.0))
        let end = JulianDay(CalendarDate(year: year + 1, month: 1, day: 1.0))

        func syzygies(at target: Angle) -> [JulianDay] {
            var moments: [JulianDay] = []
            // Start the search just before the year opens so a syzygy in the
            // first hours of January is not skipped over.
            var cursor = (start + -1).terrestrialTime
            for _ in 0..<16 {
                let next = Moon.nextPhase(target, after: cursor).universalTime
                if next.value >= end.value { break }
                if next.value >= start.value { moments.append(next) }
                cursor = next.terrestrialTime + 1
            }
            return moments
        }

        return Year(year: year,
                    start: start,
                    end: end,
                    stations: Wheel.stations(inYear: year),
                    newMoons: syzygies(at: .zero),
                    fullMoons: syzygies(at: Angle(degrees: 180)))
    }
}
