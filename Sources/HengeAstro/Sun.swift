import Foundation

/// Nutation — the small nodding of Earth's axis, driven mostly by the Moon.
///
/// Under 20″, which sounds ignorable and is not: it is a tenth of the tolerance
/// this engine holds itself to.
public struct Nutation: Sendable, Hashable {
    public let longitude: Angle
    public let obliquity: Angle
}

public enum EarthOrientation {

    /// Meeus ch. 22, the abridged series. Good to about 0.5″.
    public static func nutation(at tt: JulianDay) -> Nutation {
        let t = tt.julianCenturies
        let omega = Angle(degrees: 125.04452 - 1934.136261 * t
                          + 0.0020708 * t * t + t * t * t / 450000.0)
        let lSun = Angle(degrees: 280.4665 + 36000.7698 * t)
        let lMoon = Angle(degrees: 218.3165 + 481267.8813 * t)

        // Bound to explicit Doubles rather than written as one expression: the
        // type-checker times out resolving a long chain of Angle operators.
        let sinOmega: Double = omega.sine
        let sin2Sun: Double = Angle(radians: 2 * lSun.radians).sine
        let sin2Moon: Double = Angle(radians: 2 * lMoon.radians).sine
        let sin2Omega: Double = Angle(radians: 2 * omega.radians).sine

        let cosOmega: Double = omega.cosine
        let cos2Sun: Double = Angle(radians: 2 * lSun.radians).cosine
        let cos2Moon: Double = Angle(radians: 2 * lMoon.radians).cosine
        let cos2Omega: Double = Angle(radians: 2 * omega.radians).cosine

        var dPsiArcsec: Double = -17.20 * sinOmega
        dPsiArcsec -= 1.32 * sin2Sun
        dPsiArcsec -= 0.23 * sin2Moon
        dPsiArcsec += 0.21 * sin2Omega

        var dEpsArcsec: Double = 9.20 * cosOmega
        dEpsArcsec += 0.57 * cos2Sun
        dEpsArcsec += 0.10 * cos2Moon
        dEpsArcsec -= 0.09 * cos2Omega

        let dPsi = dPsiArcsec / 3600.0
        let dEps = dEpsArcsec / 3600.0

        return Nutation(longitude: Angle(degrees: dPsi), obliquity: Angle(degrees: dEps))
    }

    /// Mean obliquity of the ecliptic — Laskar's polynomial (Meeus eq. 22.3).
    ///
    /// The ordinary short formula drifts badly outside a few centuries. This
    /// one holds to about 0.01″ over ±1000 years and stays usable to ±10,000,
    /// which is what lets Henge claim anything at all about 2500 BC. The tilt
    /// then was near 23.93° against today's 23.44°, and that half-degree is
    /// precisely why the monument's axis fits its own era better than ours.
    public static func meanObliquity(at tt: JulianDay) -> Angle {
        let u = tt.julianCenturies / 100.0
        let arcseconds = poly(u, [
            21.448, -4680.93, -1.55, 1999.25, -51.38, -249.67,
            -39.05, 7.12, 27.87, 5.79, 2.45
        ])
        return Angle(degrees: 23, arcminutes: 26, arcseconds: arcseconds)
    }

    /// True obliquity: mean, plus nutation in obliquity.
    public static func trueObliquity(at tt: JulianDay) -> Angle {
        meanObliquity(at: tt) + nutation(at: tt).obliquity
    }

    private static func poly(_ x: Double, _ c: [Double]) -> Double {
        c.reversed().reduce(0) { $0 * x + $1 }
    }
}

/// Where the sun is, and how big it looks.
public struct SolarPosition: Sendable, Hashable {

    /// Apparent geocentric equatorial coordinates, equinox of date.
    public let equatorial: EquatorialCoordinate
    /// Apparent ecliptic longitude — what the seasons are defined against.
    public let apparentLongitude: Angle
    /// Distance in astronomical units.
    public let radiusVector: Double
    /// True obliquity used for the conversion, kept for callers that need it.
    public let obliquity: Angle

    /// Apparent angular diameter. 0.533° at mean distance — the yardstick the
    /// brief's definition of done is measured in.
    public var angularDiameter: Angle {
        Angle(degrees: 2 * 959.63 / radiusVector / 3600.0)
    }
}

/// Solar ephemeris.
///
/// Meeus ch. 25. The series is the abridged one; its stated accuracy is about
/// 0.01° in longitude for the modern era, degrading gradually into deep time.
/// `HengeAstroTests` measures the real error against baked reference values
/// rather than trusting that claim — see MISSION.md invariant 1.
public enum Sun {

    /// - Parameter tt: Terrestrial Time. Convert from UT with `.terrestrialTime`.
    public static func position(at tt: JulianDay) -> SolarPosition {
        let t = tt.julianCenturies

        // Geometric mean longitude and mean anomaly.
        let l0 = Angle(degrees: 280.46646 + 36000.76983 * t + 0.0003032 * t * t)
        let m = Angle(degrees: 357.52911 + 35999.05029 * t - 0.0001537 * t * t)
        let e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t

        // Equation of the centre — the correction for Earth's elliptical orbit.
        let sinM: Double = m.sine
        let sin2M: Double = Angle(radians: 2 * m.radians).sine
        let sin3M: Double = Angle(radians: 3 * m.radians).sine
        var centre: Double = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sinM
        centre += (0.019993 - 0.000101 * t) * sin2M
        centre += 0.000289 * sin3M
        let c = Angle(degrees: centre)

        let trueLongitude = l0 + c
        let trueAnomaly = m + c
        let radiusVector = 1.000001018 * (1 - e * e) / (1 + e * trueAnomaly.cosine)

        // Apparent longitude: correct for nutation and aberration.
        let omega = Angle(degrees: 125.04 - 1934.136 * t)
        let apparentLongitude = trueLongitude
            - Angle(degrees: 0.00569)
            - Angle(degrees: 0.00478 * omega.sine)

        // Obliquity, with the small correction that pairs with apparent
        // longitude (Meeus, note to eq. 25.8).
        let obliquity = EarthOrientation.meanObliquity(at: tt)
            + Angle(degrees: 0.00256 * omega.cosine)

        let ra = Angle(radians: atan2(obliquity.cosine * apparentLongitude.sine,
                                      apparentLongitude.cosine)).normalized
        let dec = Angle(radians: asin(obliquity.sine * apparentLongitude.sine))

        return SolarPosition(
            equatorial: EquatorialCoordinate(rightAscension: ra, declination: dec,
                                             distance: radiusVector),
            apparentLongitude: apparentLongitude.normalized,
            radiusVector: radiusVector,
            obliquity: obliquity
        )
    }

    /// The sun as seen from a place on Earth at a moment of Universal Time.
    ///
    /// This is the call the renderer makes every frame, and the one the whole
    /// calendar rests on.
    public static func horizontal(at ut: JulianDay, site: GeographicSite,
                                  refracted: Bool = true) -> HorizontalCoordinate {
        let tt = ut.terrestrialTime
        let position = position(at: tt)
        let nutation = EarthOrientation.nutation(at: tt)
        let sidereal = Sidereal.greenwichApparent(at: ut, nutation: nutation,
                                                  obliquity: position.obliquity)
        return position.equatorial.horizontal(at: site, siderealTime: sidereal,
                                              refracted: refracted)
    }
}

public extension Sun {

    /// The sun's local hour angle: how far west of the meridian it has turned.
    /// Zero at local apparent noon, negative before it.
    static func hourAngle(at ut: JulianDay, site: GeographicSite) -> Angle {
        let tt = ut.terrestrialTime
        let position = position(at: tt)
        let nutation = EarthOrientation.nutation(at: tt)
        let sidereal = Sidereal.greenwichApparent(at: ut, nutation: nutation,
                                                  obliquity: position.obliquity)
        return position.equatorial.hourAngle(at: site, siderealTime: sidereal)
    }

    /// Local **apparent solar time** — what a sundial reads, in hours.
    ///
    /// This is the time the monument itself keeps. Noon is when the sun crosses
    /// the meridian, not when a clock in another country says so, and it is
    /// the only clock that means anything in 2500 BC.
    static func apparentSolarTime(at ut: JulianDay, site: GeographicSite) -> Double {
        var hours = hourAngle(at: ut, site: site).degrees / 15.0 + 12.0
        hours.formTruncatingRemainder(dividingBy: 24)
        if hours < 0 { hours += 24 }
        return hours
    }
}

/// Rising, setting, and the bearings that make the monument a calendar.
public enum RiseSet {

    public enum Event: Sendable {
        case rise, set
    }

    /// Solve for the moment the sun's upper limb touches the horizon.
    ///
    /// Sampling then bisecting rather than using Meeus's closed form, because
    /// the closed form assumes the sun's declination barely moves within the
    /// day. That is fine at Salisbury; it is not fine everywhere, and this
    /// version stays honest at high latitude and in deep time where the
    /// obliquity differs. It costs a few hundred evaluations of a cheap series.
    ///
    /// - Parameter horizonAltitude: apparent altitude of the skyline in the
    ///   direction of rising or setting. Zero is the sea-level horizon. It is a
    ///   parameter rather than a constant because it moves the answer by more
    ///   than a degree of azimuth at Stonehenge's latitude, which is the
    ///   difference between the axis fitting and not fitting.
    ///
    /// Returns nil when the sun never crosses the horizon that day.
    public static func time(of event: Event, on date: CalendarDate,
                            site: GeographicSite,
                            horizonAltitude: Angle = .zero) -> JulianDay? {

        let midnight = JulianDay(CalendarDate(year: date.year, month: date.month,
                                              day: floor(date.day)))

        // The altitudes compared here are *apparent* — refraction already
        // applied — so the target carries only the sun's semi-diameter, the
        // amount its centre sits below the skyline when its upper limb first
        // shows. Folding the usual −0.833° in here as well would count
        // refraction twice and put sunrise minutes early, which at this
        // latitude drags the solstice bearing a degree north of the truth.
        let semiDiameter = Angle(degrees: 0.267)
        let target = (horizonAltitude - semiDiameter).degrees

        func altitude(_ fractionOfDay: Double) -> Double {
            Sun.horizontal(at: midnight + fractionOfDay, site: site,
                           refracted: true).altitude.degrees - target
        }

        // Sample at four-minute steps and take the first crossing in the
        // required direction.
        let steps = 360
        var previousT = 0.0
        var previousValue = altitude(previousT)

        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let value = altitude(t)
            let rising = previousValue < 0 && value >= 0
            let setting = previousValue > 0 && value <= 0

            if (event == .rise && rising) || (event == .set && setting) {
                // Bisect the bracket to about a tenth of a second.
                var lo = previousT, hi = t
                var loValue = previousValue
                for _ in 0..<40 {
                    let mid = (lo + hi) / 2
                    let midValue = altitude(mid)
                    if (loValue < 0) == (midValue < 0) {
                        lo = mid; loValue = midValue
                    } else {
                        hi = mid
                    }
                }
                return midnight + (lo + hi) / 2
            }
            previousT = t
            previousValue = value
        }
        return nil
    }

    /// The bearing of sunrise at a site on a given day.
    ///
    /// This is the number the monument was built around, and it is *computed* —
    /// it moves with the obliquity of its epoch, so the axis that fits 2500 BC
    /// does not quite fit today. MISSION.md invariant 1 forbids hardcoding it.
    public static func sunriseAzimuth(on date: CalendarDate, site: GeographicSite,
                                      horizonAltitude: Angle = .zero) -> Angle? {
        guard let t = time(of: .rise, on: date, site: site,
                           horizonAltitude: horizonAltitude) else { return nil }
        return Sun.horizontal(at: t, site: site).azimuth
    }

    public static func sunsetAzimuth(on date: CalendarDate, site: GeographicSite,
                                     horizonAltitude: Angle = .zero) -> Angle? {
        guard let t = time(of: .set, on: date, site: site,
                           horizonAltitude: horizonAltitude) else { return nil }
        return Sun.horizontal(at: t, site: site).azimuth
    }

    /// Extreme sunrise bearing in a year — the northernmost in June, the
    /// southernmost in December.
    ///
    /// Searched rather than read off a fixed date, because the calendar date of
    /// the solstice drifts by weeks across five millennia and between the
    /// Julian and Gregorian calendars. Assuming "21 June" would quietly measure
    /// the wrong morning in 2500 BC.
    public static func solsticeSunriseAzimuth(year: Int, site: GeographicSite,
                                              month: Int = 6,
                                              horizonAltitude: Angle = .zero) -> Angle? {
        var extreme: Angle?
        for day in 10...31 {
            guard let azimuth = sunriseAzimuth(on: CalendarDate(year: year, month: month, day: day),
                                               site: site,
                                               horizonAltitude: horizonAltitude) else { continue }
            if extreme == nil
                || (month == 6 && azimuth.degrees < extreme!.degrees)
                || (month != 6 && azimuth.degrees > extreme!.degrees) {
                extreme = azimuth
            }
        }
        return extreme
    }

    /// The matching sunset bearing at the opposite solstice.
    public static func solsticeSunsetAzimuth(year: Int, site: GeographicSite,
                                             month: Int = 12,
                                             horizonAltitude: Angle = .zero) -> Angle? {
        var extreme: Angle?
        for day in 10...31 {
            guard let azimuth = sunsetAzimuth(on: CalendarDate(year: year, month: month, day: day),
                                              site: site,
                                              horizonAltitude: horizonAltitude) else { continue }
            if extreme == nil
                || (month == 12 && azimuth.degrees < extreme!.degrees)
                || (month != 12 && azimuth.degrees > extreme!.degrees) {
                extreme = azimuth
            }
        }
        return extreme
    }
}
