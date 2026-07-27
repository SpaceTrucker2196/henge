import Foundation

/// The eight stations of the year, by where the sun actually is.
///
/// Four of them are the solstices and equinoxes and need no defending: they are
/// moments in the sun's motion, and the monument is built on two of them. The
/// other four — the cross-quarter days — are the midpoints between, and they
/// are where honesty gets interesting.
///
/// Modern druidry and modern paganism keep the cross-quarters on fixed calendar
/// dates: 1 February, 1 May, 1 August, 1 November. Those dates are inherited
/// from the medieval Irish quarter days and they are not astronomical. The
/// sun reaches the true midpoint three to seven days later. Henge computes the
/// astronomical station and *also* reports the traditional date, because
/// pretending the customary date is the solar one would be exactly the kind of
/// tidy-up this project has a rule against.
///
/// What the builders marked is a third question again, and the answer is: the
/// solstices, demonstrably, and nothing else that survives argument.
public enum WheelStation: Int, Sendable, CaseIterable, Identifiable, Hashable {

    case imbolc = 0             // 315°
    case marchEquinox           // 0°
    case beltane                // 45°
    case juneSolstice           // 90°
    case lughnasadh             // 135°
    case septemberEquinox       // 180°
    case samhain                // 225°
    case decemberSolstice       // 270°

    public var id: Int { rawValue }

    /// Apparent solar longitude that defines the station.
    ///
    /// The wheel starts at Imbolc because that is where the agricultural year
    /// was reckoned to turn, but the longitudes run in the sun's own order from
    /// the March equinox at zero.
    public var solarLongitude: Angle {
        switch self {
        case .marchEquinox: Angle(degrees: 0)
        case .beltane: Angle(degrees: 45)
        case .juneSolstice: Angle(degrees: 90)
        case .lughnasadh: Angle(degrees: 135)
        case .septemberEquinox: Angle(degrees: 180)
        case .samhain: Angle(degrees: 225)
        case .decemberSolstice: Angle(degrees: 270)
        case .imbolc: Angle(degrees: 315)
        }
    }

    /// The four solar stations — the ones that are moments rather than customs.
    public var season: Season? {
        switch self {
        case .marchEquinox: .marchEquinox
        case .juneSolstice: .juneSolstice
        case .septemberEquinox: .septemberEquinox
        case .decemberSolstice: .decemberSolstice
        default: nil
        }
    }

    public var isCrossQuarter: Bool { season == nil }

    /// The name in common use.
    public var name: String {
        switch self {
        case .imbolc: "Imbolc"
        case .marchEquinox: "Spring equinox"
        case .beltane: "Beltane"
        case .juneSolstice: "Midsummer"
        case .lughnasadh: "Lughnasadh"
        case .septemberEquinox: "Autumn equinox"
        case .samhain: "Samhain"
        case .decemberSolstice: "Midwinter"
        }
    }

    /// The name modern druidry uses. The *Alban* names are Iolo Morganwg's,
    /// eighteenth century, and the cross-quarter names are Gaelic and older —
    /// a mixed inheritance, which the lore notes say out loud.
    public var druidicName: String {
        switch self {
        case .imbolc: "Imbolc"
        case .marchEquinox: "Alban Eilir"
        case .beltane: "Beltane"
        case .juneSolstice: "Alban Hefin"
        case .lughnasadh: "Gŵyl Awst"
        case .septemberEquinox: "Alban Elfed"
        case .samhain: "Samhain"
        case .decemberSolstice: "Alban Arthan"
        }
    }

    /// The customary fixed date, where one exists: month and day, in the
    /// Gregorian calendar of the modern observance. Nil for the four solar
    /// stations, which have no fixed date and never did.
    public var traditionalDate: (month: Int, day: Int)? {
        switch self {
        case .imbolc: (2, 1)
        case .beltane: (5, 1)
        case .lughnasadh: (8, 1)
        case .samhain: (11, 1)
        default: nil
        }
    }

    public var next: WheelStation {
        WheelStation(rawValue: (rawValue + 1) % WheelStation.allCases.count)!
    }
}

public enum Wheel {

    /// The instant the sun reaches a given apparent longitude, near a starting
    /// guess. Newton on solar longitude, same as `Seasons` — the sun moves
    /// about a degree a day, so each pass cuts the error by that factor.
    public static func instant(ofSolarLongitude target: Angle,
                               near guess: JulianDay) -> JulianDay {
        var jd = guess
        for _ in 0..<8 {
            let longitude = Sun.position(at: jd).apparentLongitude
            let error = (target - longitude).signedNormalized.degrees
            jd = jd + error * (365.2422 / 360.0)
        }
        return jd
    }

    /// The instant of a station in a given year, in Terrestrial Time.
    ///
    /// "In a given year" is doing quiet work. Solar longitude zero is the March
    /// equinox, not New Year, so mapping longitude straight onto the year lands
    /// the guess about eighty days early — harmless for the four solar stations
    /// but not for Imbolc, whose 315° guesses into November and whose nearest
    /// solution from there is the *following* February. Newton has no opinion
    /// about which year you meant.
    ///
    /// So: solve, then walk whole tropical years until the answer lands in the
    /// year asked for, and re-solve from there. Costs one extra pass in one case
    /// out of eight and cannot drift, which a hand-tuned seasonal offset could.
    public static func instant(of station: WheelStation, year: Int) -> JulianDay {
        let yearStart = JulianDay(CalendarDate(year: year, month: 1, day: 1.0))
        let target = station.solarLongitude
        var jd = instant(ofSolarLongitude: target,
                         near: yearStart + (target.normalized.degrees / 360.0) * 365.25)

        // At most one step in practice; bounded anyway rather than `while true`.
        for _ in 0..<3 where jd.calendarDate.year != year {
            let drift = Double(year - jd.calendarDate.year) * 365.2422
            jd = instant(ofSolarLongitude: target, near: jd + drift)
        }
        return jd
    }

    /// The same instant in Universal Time — what a clock at the site reads.
    public static func universalInstant(of station: WheelStation, year: Int) -> JulianDay {
        instant(of: station, year: year).universalTime
    }

    /// Every station of a year, in the order the sun reaches them.
    public static func stations(inYear year: Int) -> [(station: WheelStation, instant: JulianDay)] {
        WheelStation.allCases
            .map { ($0, universalInstant(of: $0, year: year)) }
            .sorted { $0.1.value < $1.1.value }
    }

    /// The next station strictly after a moment, and when.
    ///
    /// Searches this year and the next, because Imbolc's longitude of 315° puts
    /// it early in the calendar year while the wheel treats it as the first
    /// station — so the answer for late December lives in the following year.
    public static func nextStation(after ut: JulianDay)
        -> (station: WheelStation, instant: JulianDay) {
        let year = ut.calendarDate.year
        let candidates = stations(inYear: year) + stations(inYear: year + 1)
        return candidates.first { $0.instant.value > ut.value }
            // Cannot fail in practice: the next year's stations all lie ahead.
            ?? candidates[candidates.count - 1]
    }

    /// How far the customary date sits from the sun's own, in days.
    ///
    /// Positive means the sun arrives *after* the tradition celebrates. This is
    /// the number the lore panel shows rather than hides: for the cross-quarters
    /// it runs three to seven days, and it is not an error in either direction —
    /// they are two different calendars answering two different questions.
    public static func traditionalOffset(of station: WheelStation, year: Int) -> Double? {
        guard let fixed = station.traditionalDate else { return nil }
        let customary = JulianDay(CalendarDate(year: year, month: fixed.month,
                                               day: Double(fixed.day)))
        return universalInstant(of: station, year: year).value - customary.value
    }
}
