import Foundation

/// The things worth knowing are coming.
///
/// Everything here is solved from position, not from a table of dates or a
/// mean-period approximation. That matters more than it sounds: a mean lunation
/// of 29.530588 days is right on average and wrong by up to fourteen hours for
/// any particular new moon, and the whole point of an eclipse season is that it
/// turns on a few degrees.
public enum EventKind: Sendable, Hashable {

    /// One of the eight stations of the year.
    case station(WheelStation)

    case newMoon, firstQuarter, fullMoon, lastQuarter

    /// A new or full moon close enough to a node that an eclipse is possible.
    /// `certain` distinguishes Meeus's two ecliptic limits — inside the tighter
    /// one an eclipse must occur, between them it may.
    case eclipsePossible(solar: Bool, certain: Bool)

    /// The moon's declination envelope reaches its widest or narrowest — the
    /// ends of the 18.61-year swing the Station Stones are argued to mark.
    case standstill(major: Bool)

    public var name: String {
        switch self {
        case .station(let station): station.name
        case .newMoon: "New moon"
        case .firstQuarter: "First quarter"
        case .fullMoon: "Full moon"
        case .lastQuarter: "Last quarter"
        case .eclipsePossible(let solar, let certain):
            (solar ? "Solar eclipse" : "Lunar eclipse") + (certain ? "" : " possible")
        case .standstill(let major): major ? "Major standstill" : "Minor standstill"
        }
    }

    /// The SF Symbol for the ribbon, or nil where a word reads better — the
    /// wheel stations are festivals with names, not phases with shapes. Kept
    /// beside `name` for the same reason `LunarPhase.symbolName` is: a glyph
    /// chosen in a view is a glyph no test can pin to its meaning.
    public var symbolName: String? {
        switch self {
        case .station: nil
        case .newMoon: "moonphase.new.moon"
        case .firstQuarter: "moonphase.first.quarter"
        case .fullMoon: "moonphase.full.moon"
        case .lastQuarter: "moonphase.last.quarter"
        case .eclipsePossible(let solar, _):
            solar ? "sun.max.circle.fill" : "moon.circle.fill"
        case .standstill(let major):
            major ? "arrow.up.to.line" : "arrow.down.to.line"
        }
    }

    /// Sorted so the calendar can show the important thing first when two land
    /// on the same day — an eclipse outranks the moon phase that carries it.
    public var priority: Int {
        switch self {
        case .eclipsePossible: 0
        case .standstill: 1
        case .station: 2
        case .newMoon, .fullMoon: 3
        case .firstQuarter, .lastQuarter: 4
        }
    }
}

public struct AstronomicalEvent: Sendable, Hashable, Identifiable {

    public let kind: EventKind
    /// Universal Time — what a clock at the site would read.
    public let instant: JulianDay

    public var id: String { "\(kind)@\(instant.value)" }

    public init(kind: EventKind, instant: JulianDay) {
        self.kind = kind
        self.instant = instant
    }
}

// ── the moon's phases, solved ───────────────────────────────────────────────

public extension Moon {

    /// Elongation in ecliptic longitude — moon minus sun. Zero at new, 180 at
    /// full. Longitude only, deliberately: the phases are *defined* by the
    /// longitude difference, not by the angular separation on the sky, which is
    /// never quite zero because the moon's path is tilted.
    static func elongation(at tt: JulianDay) -> Angle {
        (position(at: tt).longitude - Sun.position(at: tt).apparentLongitude).normalized
    }

    /// The first moment after `tt` that the moon reaches a given elongation.
    ///
    /// Terrestrial Time in, Terrestrial Time out — the ephemeris's own scale.
    /// Callers wanting a clock reading convert at the boundary, which is worth
    /// being strict about here: ΔT is a minute today and several hours in the
    /// builders' era, so a phase solved in the wrong scale is fine in testing
    /// and wrong in exactly the epoch this app exists for.
    ///
    /// Newton on the elongation. The moon gains on the sun at about 12.19° a
    /// day, and that rate is stable enough that six passes land within a
    /// second — the errors that matter are in the position, not in the
    /// root-finding.
    static func nextPhase(_ target: Angle, after tt: JulianDay) -> JulianDay {
        let meanRate = 360.0 / 29.530588   // degrees per day, moon relative to sun
        // Step forward to the first crossing strictly ahead, then refine.
        let ahead = (target - elongation(at: tt)).normalized.degrees
        var jd = tt + max(ahead, 0.05) / meanRate

        for _ in 0..<8 {
            let error = (target - elongation(at: jd)).signedNormalized.degrees
            jd = jd + error / meanRate
        }
        // Refinement can overshoot backwards past the start when the start was
        // within minutes of the phase; take the next one rather than a past one.
        if jd.value <= tt.value { return nextPhase(target, after: tt + 1) }
        return jd
    }

    /// How far the moon is from the nearer node, in longitude.
    ///
    /// This is the number an eclipse turns on. Zero means the moon is crossing
    /// the ecliptic; the further from zero, the further the shadow cone misses.
    static func distanceFromNode(at tt: JulianDay) -> Angle {
        let fromAscending = (position(at: tt).longitude - ascendingNode(at: tt)).normalized.degrees
        // Nearer of the two nodes, so the answer is 0…90 either way.
        let folded = fromAscending > 180 ? 360 - fromAscending : fromAscending
        return Angle(degrees: min(folded, 180 - folded))
    }

    /// Whether an eclipse can happen at this syzygy, by Meeus's ecliptic limits.
    ///
    /// Solar: certain within 15.4° of a node, possible out to 18.5°.
    /// Lunar: certain within 9.5°, possible out to 12.2°.
    ///
    /// These are limits, not a prediction — a full eclipse calculation needs
    /// the moon's latitude and both bodies' apparent radii at the instant, and
    /// Besselian elements to say where on Earth it lands. What this gives is
    /// the *season*, which is the thing a calendar wants and the thing the
    /// Aubrey-hole hypothesis is about.
    ///
    /// — Meeus, *Astronomical Algorithms*, ch. 54.
    static func eclipseLimit(at tt: JulianDay, solar: Bool) -> (possible: Bool, certain: Bool) {
        let degrees = distanceFromNode(at: tt).degrees
        let certain = solar ? 15.4 : 9.5
        let possible = solar ? 18.5 : 12.2
        return (degrees <= possible, degrees <= certain)
    }
}

// ── the standstills ─────────────────────────────────────────────────────────

public extension Moon {

    /// The next end of the 18.61-year swing after a moment, and which end.
    ///
    /// The declination envelope is widest when the ascending node is at 0° and
    /// narrowest at 180°, so this searches the envelope itself rather than the
    /// node — the same answer by a route that stays right if the envelope's
    /// formula is ever refined.
    static func nextStandstill(after tt: JulianDay) -> AstronomicalEvent {
        // Coarse pass at a month's resolution over one full cycle, then a
        // golden-section-free bisection on the derivative's sign change.
        let step = 30.0
        var previous = standstillDeclination(at: tt).degrees
        var rising: Bool?
        var jd = tt + step

        while jd.value < tt.value + 18.61 * 365.25 {
            let current = standstillDeclination(at: jd).degrees
            let nowRising = current > previous
            if let was = rising, was != nowRising {
                // Turning point between jd - step and jd. Bisect on the slope.
                var low = jd - step, high = jd
                for _ in 0..<40 {
                    let mid = JulianDay((low.value + high.value) / 2)
                    let slope = standstillDeclination(at: mid + 0.5).degrees
                        - standstillDeclination(at: mid - 0.5).degrees
                    if (slope > 0) == was { low = mid } else { high = mid }
                }
                let peak = JulianDay((low.value + high.value) / 2)
                return AstronomicalEvent(kind: .standstill(major: was), instant: peak)
            }
            rising = nowRising
            previous = current
            jd = jd + step
        }
        // Unreachable for any real input: a turning point falls every 9.3 years.
        return AstronomicalEvent(kind: .standstill(major: true), instant: jd)
    }
}

// ── the calendar ────────────────────────────────────────────────────────────

public enum Events {

    /// Everything coming up, in order, from a moment.
    ///
    /// `days` bounds the window rather than the count, because "the next ten
    /// events" is a different question in a year with an eclipse season than in
    /// one without, and the calendar wants the honest density.
    public static func upcoming(from ut: JulianDay, days: Double = 120) -> [AstronomicalEvent] {
        let end = ut.value + days
        // The ephemeris works in Terrestrial Time; the calendar reads Universal.
        // Cross once, here, rather than in each solver.
        let startTT = ut.terrestrialTime
        var events: [AstronomicalEvent] = []

        // Stations of the year.
        var station = Wheel.nextStation(after: ut)
        while station.instant.value < end {
            events.append(AstronomicalEvent(kind: .station(station.station),
                                            instant: station.instant))
            station = Wheel.nextStation(after: station.instant + 0.5)
        }

        // Moon phases, and the eclipse seasons that ride on the syzygies.
        let phases: [(Angle, EventKind)] = [
            (Angle(degrees: 0), .newMoon),
            (Angle(degrees: 90), .firstQuarter),
            (Angle(degrees: 180), .fullMoon),
            (Angle(degrees: 270), .lastQuarter)
        ]
        for (target, kind) in phases {
            var moment = Moon.nextPhase(target, after: startTT)
            while moment.universalTime.value < end {
                let clock = moment.universalTime
                events.append(AstronomicalEvent(kind: kind, instant: clock))

                if kind == .newMoon || kind == .fullMoon {
                    let solar = (kind == .newMoon)
                    let limit = Moon.eclipseLimit(at: moment, solar: solar)
                    if limit.possible {
                        events.append(AstronomicalEvent(
                            kind: .eclipsePossible(solar: solar, certain: limit.certain),
                            instant: clock))
                    }
                }
                moment = Moon.nextPhase(target, after: moment + 1)
            }
        }

        // The standstill, if one falls inside the window. At most one can.
        let standstill = Moon.nextStandstill(after: startTT)
        let standstillUT = AstronomicalEvent(kind: standstill.kind,
                                             instant: standstill.instant.universalTime)
        if standstillUT.instant.value < end { events.append(standstillUT) }

        return events.sorted {
            $0.instant.value != $1.instant.value
                ? $0.instant.value < $1.instant.value
                : $0.kind.priority < $1.kind.priority
        }
    }

    /// The next single event, whatever it is.
    public static func next(after ut: JulianDay) -> AstronomicalEvent? {
        // A window of forty days always contains a moon phase, so one pass is
        // enough; the wider fallback is there for the pathological case only.
        upcoming(from: ut, days: 40).first ?? upcoming(from: ut, days: 400).first
    }
}
