import Foundation

/// Solstices and equinoxes, solved rather than looked up.
///
/// The calendar date of a solstice is not fixed. The Julian year runs about 11
/// minutes long, so across the five millennia Henge covers the June solstice
/// drifts by more than a month: in 2500 BC it falls in what the proleptic
/// Julian calendar calls July. Any code that assumed "21 June" would measure
/// the wrong morning in exactly the era the monument was built — which is why
/// this solves for the sun's longitude instead.
public enum Season: Sendable, CaseIterable {

    case marchEquinox, juneSolstice, septemberEquinox, decemberSolstice

    /// Apparent solar longitude that defines the season.
    public var solarLongitude: Angle {
        switch self {
        case .marchEquinox: Angle(degrees: 0)
        case .juneSolstice: Angle(degrees: 90)
        case .septemberEquinox: Angle(degrees: 180)
        case .decemberSolstice: Angle(degrees: 270)
        }
    }

    public var name: String {
        switch self {
        case .marchEquinox: "March equinox"
        case .juneSolstice: "June solstice"
        case .septemberEquinox: "September equinox"
        case .decemberSolstice: "December solstice"
        }
    }

    /// The eightfold wheel names these two; M4 adds the cross-quarter days.
    public var druidicName: String? {
        switch self {
        case .juneSolstice: "Alban Hefin"
        case .decemberSolstice: "Alban Arthan"
        case .marchEquinox: "Alban Eilir"
        case .septemberEquinox: "Alban Elfed"
        }
    }
}

public enum Seasons {

    /// The instant of a season, in Terrestrial Time.
    ///
    /// Newton's method on the sun's apparent longitude. The sun moves about a
    /// degree a day, so each pass cuts the error by roughly that factor and
    /// six are plenty from a start anywhere in the right year.
    public static func instant(of season: Season, year: Int) -> JulianDay {
        // Start from the mean position within the year rather than a calendar
        // date, so this behaves the same in any calendar and any epoch.
        let yearStart = JulianDay(CalendarDate(year: year, month: 1, day: 1.0))
        let target = season.solarLongitude
        var jd = yearStart + (target.normalized.degrees / 360.0) * 365.25

        for _ in 0..<8 {
            let longitude = Sun.position(at: jd).apparentLongitude
            let error = (target - longitude).signedNormalized.degrees
            // 365.2422 days per 360° of longitude, near enough for a step.
            jd = jd + error * (365.2422 / 360.0)
        }
        return jd
    }

    /// The same instant in Universal Time — what a clock at the site would read.
    public static func universalInstant(of season: Season, year: Int) -> JulianDay {
        instant(of: season, year: year).universalTime
    }
}

public extension RiseSet {

    /// Sunrise bearing on the morning of a solstice or equinox.
    ///
    /// Takes the extreme over the days bracketing the instant, because the
    /// solstice rarely falls at dawn and the neighbouring sunrise can be a
    /// fraction further north.
    static func seasonalSunriseAzimuth(_ season: Season, year: Int,
                                       site: GeographicSite,
                                       horizonAltitude: Angle = .zero) -> Angle? {
        let instant = Seasons.universalInstant(of: season, year: year)
        let northerly = (season == .juneSolstice)
        var extreme: Angle?

        for offset in -1...1 {
            let date = (instant + Double(offset)).calendarDate
            guard let azimuth = sunriseAzimuth(on: date, site: site,
                                               horizonAltitude: horizonAltitude) else { continue }
            if extreme == nil
                || (northerly && azimuth.degrees < extreme!.degrees)
                || (!northerly && azimuth.degrees > extreme!.degrees) {
                extreme = azimuth
            }
        }
        return extreme
    }

    /// Sunset bearing on the evening of a solstice or equinox.
    static func seasonalSunsetAzimuth(_ season: Season, year: Int,
                                      site: GeographicSite,
                                      horizonAltitude: Angle = .zero) -> Angle? {
        let instant = Seasons.universalInstant(of: season, year: year)
        // Midwinter sunset is the southernmost, so it is the *smallest*
        // azimuth in the western half; midsummer sunset the largest.
        let southerly = (season == .decemberSolstice)
        var extreme: Angle?

        for offset in -1...1 {
            let date = (instant + Double(offset)).calendarDate
            guard let azimuth = sunsetAzimuth(on: date, site: site,
                                              horizonAltitude: horizonAltitude) else { continue }
            if extreme == nil
                || (southerly && azimuth.degrees < extreme!.degrees)
                || (!southerly && azimuth.degrees > extreme!.degrees) {
                extreme = azimuth
            }
        }
        return extreme
    }
}
