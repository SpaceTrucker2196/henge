import Foundation
import simd
import HengeAstro

/// The animated switch between the monument's two labelled states.
///
/// Invariant 8's carve-out (MISSION.md, owner-authorised 2026-08-03) permits
/// the *transition* between "as it was" and "as it stands" to pass through
/// intermediate geometry, because erosion and construction are themselves the
/// archaeology; what stays forbidden is a stable blended view. Everything
/// that *decides* — how fast the ditch silts, in what order the stones rise,
/// what path the calendar takes through four millennia — lives here, where a
/// test can hold it, and the renderer only applies the numbers.
public enum MonumentTransition {

    /// Wall-clock seconds the switch takes. Long enough for the sun to arc
    /// across the sky twice and for a hundred-odd stones to arrive one at a
    /// time; short enough that the switch still feels like a switch.
    public static let duration: Double = 12

    /// Full day-cycles the sky sweeps during the transition. The clock spins
    /// forward while the calendar walks between the eras — the classic
    /// timelapse look, and every frame of it is a real astronomical
    /// computation for a real date.
    public static let dayCycles: Double = 2

    /// The year each state's era anchors to, astronomical year numbering.
    ///
    /// `asItWas` is the completed Stage-2 monument, c. 2200 BC (astronomical
    /// year −2199) — the same figure `Monument.State` documents. `asItStands`
    /// is the present, so it has no fixed year here; the caller supplies the
    /// year it is actually running in.
    public static func eraYear(of state: Monument.State,
                               presentYear: Int) -> Int {
        switch state {
        case .asItWas: -2199
        case .asItStands: presentYear
        }
    }

    // ── erosion pacing ──────────────────────────────────────────────────────

    /// How far the earthwork has eroded at animation progress `p`, headed
    /// toward `target`. Returns the erosion fraction `Earthwork` understands:
    /// 0 fresh chalk, 1 today's swell.
    ///
    /// The pace is a normalised exponential, fast early and slowing — the
    /// shape the excavations report: the ditch's primary silting was rapid,
    /// coarse chalk rubble off the fresh sides within decades, followed by
    /// millennia of slow loam (Cleal, Walker & Montague 1995, the ditch
    /// sections). Construction runs the same curve mirrored, so the bank
    /// rises quickly and settles.
    public static func erosion(atProgress p: Double,
                               toward target: Monument.State) -> Double {
        let s = silting(min(max(p, 0), 1))
        switch target {
        case .asItStands: return s
        case .asItWas: return 1 - s
        }
    }

    /// The normalised silting curve: 0 at 0, 1 at 1, most of the change in
    /// the first half. `k` sets how front-loaded it is; 4 puts about 86% of
    /// the movement in the first half of the animation.
    static func silting(_ p: Double) -> Double {
        let k = 4.0
        return (1 - exp(-k * p)) / (1 - exp(-k))
    }

    // ── stone cues ──────────────────────────────────────────────────────────

    /// One stone's part in the animation: when it moves, and how deep below
    /// grade it starts (rising) or ends (sinking).
    public struct StoneCue: Sendable, Hashable {
        public let window: ClosedRange<Double>
        public let sinkDepth: Double
    }

    /// A cue for every stone that differs between the two scenes, keyed by
    /// stone id. Stones present and identical in both scenes get no cue and
    /// never move. Deterministic: the same pair of scenes always yields the
    /// same schedule, because the shadow tests' guarantee — a stone is in
    /// exactly the same place every run — extends to *when* it arrives.
    public static func cues(from: MonumentScene,
                            to: MonumentScene) -> [String: StoneCue] {
        let fromByID = Dictionary(uniqueKeysWithValues: from.stones.map { ($0.id, $0) })
        let toByID = Dictionary(uniqueKeysWithValues: to.stones.map { ($0.id, $0) })

        // Every id whose geometry changes: appears, disappears, or differs.
        let changed = Set(fromByID.keys).union(toByID.keys).filter {
            fromByID[$0] != toByID[$0]
        }

        // The stone that defines the cue's depth and ordering is whichever
        // version exists in the *target* scene, falling back to the departing
        // one for stones that vanish outright.
        let ordered = changed
            .compactMap { toByID[$0] ?? fromByID[$0] }
            .sorted { order($0, raising: to.state == .asItWas)
                    < order($1, raising: to.state == .asItWas) }

        // Spread the windows evenly through the middle of the animation so
        // stones arrive at a steady rhythm; the width of each window is what
        // makes a single stone's rise readable rather than a pop.
        let lead = 0.06, tail = 0.97, width = 0.10
        let span = tail - lead - width
        let step = ordered.count > 1 ? span / Double(ordered.count - 1) : 0

        var cues: [String: StoneCue] = [:]
        for (index, stone) in ordered.enumerated() {
            let start = lead + step * Double(index)
            cues[stone.id] = StoneCue(
                window: start...(start + width),
                // Deep enough to bury the whole stone below grade wherever
                // it sits — a lintel starts underground and rises through
                // the uprights to its seat, which is not far from how the
                // real ones are thought to have gone up.
                sinkDepth: stone.position.y + stone.height + 0.3)
        }
        return cues
    }

    /// Sort key for the animation order.
    ///
    /// Raising follows the build sequence the archaeology gives: the Aubrey
    /// holes and their cremations first (the site was a cemetery before it
    /// was anything else), then the outlying sarsens, then the trilithons and
    /// circle uprights, lintels after the uprights that carry them, and the
    /// bluestones — the Stage-2 rearrangement — last. Within a phase, stones
    /// go up clockwise from north, walking the ring the way the numbering
    /// does. Ruin runs the same order backwards with the lintels first,
    /// which is how gravity actually took them: a lintel falls before its
    /// uprights lean.
    static func order(_ stone: Stone, raising: Bool) -> (Int, Int, Double) {
        let radius = (stone.position.x * stone.position.x
                      + stone.position.z * stone.position.z).squareRoot()
        let isLintel = stone.position.y > 2
        let azimuth = WorldAxes.azimuth(
            of: SIMD3(stone.position.x, 0, stone.position.z)).degrees

        let phase: Int
        switch stone.material {
        case .chalk: phase = 0
        case .sarsen: phase = radius > 20 ? 1 : (radius > 11 ? 3 : 2)
        case .bluestone: phase = 5
        }
        // Lintels ride one sub-phase behind their uprights when raising,
        // one ahead when falling.
        let lintelRank = isLintel ? 1 : 0
        if raising {
            return (phase, lintelRank, azimuth)
        }
        // Ruin: reverse the phases, lintels first within each.
        return (5 - phase, 1 - lintelRank, azimuth)
    }

    /// Which side of the switch a drawn stone is on.
    public enum Role: Sendable {
        /// Belongs to the scene being left; sinks away during its window.
        case outgoing
        /// Belongs to the scene being entered; rises during its window.
        case incoming
    }

    /// Where a cued stone stands at animation progress `p`: whether it is
    /// drawn at all, and how far below grade it sits. The rise and sink use
    /// a smoothstep so a stone settles rather than stopping dead — and the
    /// renderer applies these numbers without recomputing them, so this is
    /// the function the tests hold.
    public static func placement(cue: StoneCue, progress p: Double,
                                 role: Role) -> (visible: Bool, sink: Double) {
        let window = cue.window
        let width = window.upperBound - window.lowerBound
        let raised = width > 0
            ? smoothstep(min(max((p - window.lowerBound) / width, 0), 1))
            : (p >= window.lowerBound ? 1.0 : 0.0)
        switch role {
        case .outgoing:
            // Fully present before the window, gone after it.
            if p >= window.upperBound { return (false, 0) }
            return (true, cue.sinkDepth * raised)
        case .incoming:
            // Absent before the window, seated after it.
            if p <= window.lowerBound { return (false, cue.sinkDepth) }
            return (true, cue.sinkDepth * (1 - raised))
        }
    }

    static func smoothstep(_ t: Double) -> Double {
        t * t * (3 - 2 * t)
    }

    // ── the path through time ───────────────────────────────────────────────

    /// The sweep the calendar makes between the eras.
    ///
    /// The problem with a straight interpolation across four millennia is
    /// aliasing: sampled sixty times a second, both the time of day and the
    /// season would land pseudo-randomly frame to frame and the sky would
    /// strobe. So the path is composed instead: the *year* walks smoothly
    /// from era to era in whole-year steps rounded to whole days (which
    /// pins the time of day exactly and holds the season to within half a
    /// day), while a separate fractional-day term carries the sun through
    /// `dayCycles` full arcs. Obliquity and precession drift underneath at
    /// their real rates, computed per frame by `HengeAstro`.
    public struct EraTimeline: Sendable {

        /// Mean tropical year in days (Meeus). The step that keeps the
        /// season fixed while the years pass.
        static let tropicalYear = 365.24219

        public let start: JulianDay
        public let end: JulianDay
        private let yearSpan: Double

        /// From the moment on screen to the same date and time of day in
        /// the target era. February 29 clamps to the 28th rather than
        /// asking what a leap year meant to the builders.
        public init(from start: JulianDay, toYear year: Int) {
            self.start = start
            var date = start.calendarDate
            date.year = year
            if date.month == 2, date.day >= 29 {
                date.day = 28 + date.day.truncatingRemainder(dividingBy: 1)
            }
            self.end = JulianDay(date)
            self.yearSpan = (end - start) / Self.tropicalYear
        }

        /// Where the calendar stands at progress `p`.
        public func julianDay(at p: Double) -> JulianDay {
            guard p > 0 else { return start }
            guard p < 1 else { return end }

            let years = (yearSpan * p).rounded()
            let shift = (years * Self.tropicalYear).rounded()
            var value = start.value + shift + MonumentTransition.dayCycles * p

            // The whole-year, whole-day walk cannot land exactly on the
            // target date; feather the small residual in over the last
            // tenth so the hand-off is seamless.
            let residual = end.value
                - (start.value + (yearSpan.rounded() * Self.tropicalYear).rounded()
                   + MonumentTransition.dayCycles)
            if p > 0.9 {
                value += residual * (p - 0.9) / 0.1
            }
            return JulianDay(value)
        }
    }
}

/// The per-frame numbers the renderer needs — computed by the model layer
/// from the structures above, applied by the engine without further thought.
public struct TransitionFrame: Sendable, Equatable {
    /// Animation progress, 0 to 1.
    public var progress: Double
    /// The earthwork's erosion fraction at this instant.
    public var erosion: Double

    public init(progress: Double, erosion: Double) {
        self.progress = progress
        self.erosion = erosion
    }
}
