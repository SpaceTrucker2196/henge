import Foundation
import HengeAstro

/// The moments the monument was built to catch.
///
/// An alignment is not a fact about a day, it is a fact about a *moment*, and
/// the difference is the whole reason this type exists. "The sun rises on the
/// axis at midsummer" is true to about a degree for a week either side of the
/// solstice, because the sun's declination barely moves at the turn — that is
/// what a solstice *is*. So the app must be able to say how close, right now,
/// rather than merely which day is the right one.
public enum Alignment: Sendable, CaseIterable, Hashable, Identifiable {

    /// Midsummer sunrise up the Avenue, over the Heel Stone.
    case midsummerSunrise
    /// Midwinter sunset down the axis, between the uprights of the Great
    /// Trilithon — the same line read the other way.
    case midwinterSunset
    /// The southernmost moonrise of the major standstill, which the long sides
    /// of the Station Stone rectangle are argued to mark.
    case majorStandstillMoonrise

    public var id: Self { self }

    public var name: String {
        switch self {
        case .midsummerSunrise: "Midsummer sunrise"
        case .midwinterSunset: "Midwinter sunset"
        case .majorStandstillMoonrise: "Standstill moonrise"
        }
    }

    /// The bearing the monument offers, measured from north through east.
    ///
    /// Derived from `Monument.axisAzimuth` rather than written down twice, so
    /// a correction to the survey moves both ends of the line together.
    public var bearing: HengeAstro.Angle {
        switch self {
        case .midsummerSunrise:
            Monument.axisAzimuth
        case .midwinterSunset:
            (Monument.axisAzimuth + HengeAstro.Angle(degrees: 180)).normalized
        case .majorStandstillMoonrise:
            // The rectangle's long side, perpendicular to the axis and running
            // to the south-east. Debated as an intention; the geometry is not.
            (Monument.axisAzimuth + HengeAstro.Angle(degrees: 90)).normalized
        }
    }

    /// Whether the body is rising or setting when this alignment happens.
    public var isRising: Bool {
        switch self {
        case .midsummerSunrise, .majorStandstillMoonrise: true
        case .midwinterSunset: false
        }
    }

    /// What the app is prepared to claim. The solar pair are `established` as
    /// alignments; the lunar one is not.
    public var tier: LoreTier {
        switch self {
        case .midsummerSunrise, .midwinterSunset: .established
        case .majorStandstillMoonrise: .debated
        }
    }
}

public enum AlignmentSolver {

    /// One solar diameter — the tolerance the definition of done is stated in,
    /// and a natural unit: inside this, the sun is visibly *on* the line rather
    /// than near it.
    public static let solarDiameter = HengeAstro.Angle(degrees: 0.53)

    /// How far off the alignment the sun currently is, in bearing.
    ///
    /// Returns nil when the body is below the horizon or does not rise that
    /// day — an alignment you cannot see is not an alignment.
    public static func deviation(of alignment: Alignment,
                                 on date: CalendarDate,
                                 site: GeographicSite = .stonehenge,
                                 horizonAltitude: HengeAstro.Angle = .zero) -> HengeAstro.Angle? {
        let azimuth = alignment.isRising
            ? RiseSet.sunriseAzimuth(on: date, site: site, horizonAltitude: horizonAltitude)
            : RiseSet.sunsetAzimuth(on: date, site: site, horizonAltitude: horizonAltitude)
        guard let azimuth else { return nil }
        return azimuth.separation(to: alignment.bearing)
    }

    /// The morning (or evening) of the year the sun reaches its extreme, and
    /// where it rises when it does.
    ///
    /// **This is the extreme, not the closest approach to the axis, and the
    /// distinction is the whole design.** The sunrise bearing at Stonehenge
    /// never quite equals the surveyed axis in either epoch — it comes within
    /// about half a degree and turns back. Searching for "the day it lines up
    /// best" therefore walks to the edge of whatever window it is given and
    /// returns a fortnight before the solstice, which is nonsense. What the
    /// monument marks is where the sun *stops*, and that is a turning point in
    /// declination, so that is what gets solved for.
    ///
    /// Searched rather than assumed: the solstice is an instant, sunrise is a
    /// different instant, and which morning wins depends on where in the day
    /// the turn falls. In the builders' era the whole thing sits in July by the
    /// proleptic Julian calendar.
    public static func extreme(for alignment: Alignment, year: Int,
                               site: GeographicSite = .stonehenge,
                               horizonAltitude: HengeAstro.Angle = .zero)
        -> (date: CalendarDate, azimuth: HengeAstro.Angle, deviation: HengeAstro.Angle)? {

        let season: Season = alignment == .midwinterSunset ? .decemberSolstice : .juneSolstice
        let centre = Seasons.universalInstant(of: season, year: year)
        // Midsummer sunrise and midwinter sunset are both the *northerly* and
        // *southerly* extremes of their own arc — one reaches the smallest
        // azimuth of the year, the other the largest.
        let wantsSmallest = (alignment == .midsummerSunrise)

        var best: (CalendarDate, HengeAstro.Angle)?
        for offset in -7...7 {
            let moment = centre + Double(offset)
            let date = CalendarDate(year: moment.calendarDate.year,
                                    month: moment.calendarDate.month,
                                    day: moment.calendarDate.day.rounded(.down))
            let azimuth = alignment.isRising
                ? RiseSet.sunriseAzimuth(on: date, site: site, horizonAltitude: horizonAltitude)
                : RiseSet.sunsetAzimuth(on: date, site: site, horizonAltitude: horizonAltitude)
            guard let azimuth else { continue }
            if best == nil
                || (wantsSmallest && azimuth.degrees < best!.1.degrees)
                || (!wantsSmallest && azimuth.degrees > best!.1.degrees) {
                best = (date, azimuth)
            }
        }
        guard let best else { return nil }
        return (best.0, best.1, best.1.separation(to: alignment.bearing))
    }

    /// Is the sun on the line right now, to within a solar diameter?
    public static func isAligned(_ alignment: Alignment,
                                 on date: CalendarDate,
                                 site: GeographicSite = .stonehenge,
                                 horizonAltitude: HengeAstro.Angle = .zero,
                                 tolerance: HengeAstro.Angle = solarDiameter) -> Bool {
        guard let deviation = deviation(of: alignment, on: date, site: site,
                                        horizonAltitude: horizonAltitude) else { return false }
        return deviation.degrees <= tolerance.degrees
    }

    /// Which way the shadow runs at the moment of an alignment.
    ///
    /// Directly opposite the sun, which is the whole of it — but worth having
    /// as a named thing, because "the first shadow spears down the Avenue" is
    /// the demo, and a demo should be a computation rather than a description.
    public static func shadowBearing(sunAzimuth: HengeAstro.Angle) -> HengeAstro.Angle {
        (sunAzimuth + HengeAstro.Angle(degrees: 180)).normalized
    }
}
