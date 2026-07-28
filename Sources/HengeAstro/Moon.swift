import Foundation

/// Where the moon is, how far, and how much of it is lit.
///
/// Meeus ch. 47, which is a truncation of ELP-2000/82. The series here keeps
/// the larger periodic terms rather than all sixty of each — enough for a sky
/// and for the standstill geometry the monument is about, and the tests measure
/// what it actually achieves rather than repeating a claim.
///
/// The moon matters here more than it does in most sky apps. The Station Stone
/// rectangle's long sides point at the major standstill moonrise and moonset,
/// and that is the strongest evidence the builders were watching the moon at
/// all — so the 18.6-year nodal cycle has to fall out of the arithmetic rather
/// than be scripted.
public struct LunarPosition: Sendable, Hashable {

    /// Apparent geocentric equatorial coordinates, equinox of date.
    public let equatorial: EquatorialCoordinate
    /// Apparent ecliptic longitude and latitude.
    public let longitude: Angle
    public let latitude: Angle
    /// Distance from Earth's centre, in kilometres.
    public let distance: Double

    /// Apparent angular diameter. Between about 29.4′ and 33.5′ — the swing
    /// that makes one eclipse total and the next annular.
    public var angularDiameter: Angle {
        Angle(radians: 2 * asin(1737.4 / distance))
    }
}

/// Illuminated fraction and the direction of the terminator.
public struct LunarPhase: Sendable, Hashable {
    /// 0 at new moon, 1 at full.
    public let illuminatedFraction: Double
    /// Elongation from the sun. Grows through the month.
    public let phaseAngle: Angle
    /// Age in days since the last new moon, near enough for a readout.
    public let age: Double

    public var name: String {
        switch age {
        case ..<1.85: "New"
        case ..<5.5: "Waxing crescent"
        case ..<9.2: "First quarter"
        case ..<12.9: "Waxing gibbous"
        case ..<16.6: "Full"
        case ..<20.3: "Waning gibbous"
        case ..<24.0: "Last quarter"
        case ..<27.7: "Waning crescent"
        default: "New"
        }
    }

    /// The SF Symbol for this phase, keyed off the same age bands as `name`
    /// so the glyph and the word can never disagree. It lives here rather
    /// than in the view for the usual reason: a mapping in SwiftUI is a
    /// mapping no test reaches, and a waxing moon drawn waning is exactly
    /// the kind of quiet wrongness this app exists to not commit.
    ///
    /// These are the northern-hemisphere glyphs, which is the sky the
    /// monument stands under.
    public var symbolName: String {
        switch age {
        case ..<1.85: "moonphase.new.moon"
        case ..<5.5: "moonphase.waxing.crescent"
        case ..<9.2: "moonphase.first.quarter"
        case ..<12.9: "moonphase.waxing.gibbous"
        case ..<16.6: "moonphase.full.moon"
        case ..<20.3: "moonphase.waning.gibbous"
        case ..<24.0: "moonphase.last.quarter"
        case ..<27.7: "moonphase.waning.crescent"
        default: "moonphase.new.moon"
        }
    }
}

public enum Moon {

    /// One periodic term: coefficient, then the multiples of D, M, M′ and F.
    private struct Term {
        let coefficient: Double
        let d: Double, m: Double, mPrime: Double, f: Double
        init(_ c: Double, _ d: Double, _ m: Double, _ mp: Double, _ f: Double) {
            coefficient = c; self.d = d; self.m = m; mPrime = mp; self.f = f
        }
    }

    // Longitude, in units of 1e-6 degrees (Meeus table 47.A, leading terms).
    private static let longitudeTerms: [Term] = [
        Term(6288774, 0, 0, 1, 0), Term(1274027, 2, 0, -1, 0),
        Term(658314, 2, 0, 0, 0), Term(213618, 0, 0, 2, 0),
        Term(-185116, 0, 1, 0, 0), Term(-114332, 0, 0, 0, 2),
        Term(58793, 2, 0, -2, 0), Term(57066, 2, -1, -1, 0),
        Term(53322, 2, 0, 1, 0), Term(45758, 2, -1, 0, 0),
        Term(-40923, 0, 1, -1, 0), Term(-34720, 1, 0, 0, 0),
        Term(-30383, 0, 1, 1, 0), Term(15327, 2, 0, 0, -2),
        Term(-12528, 0, 0, 1, 2), Term(10980, 0, 0, 1, -2),
        Term(10675, 4, 0, -1, 0), Term(10034, 0, 0, 3, 0),
        Term(8548, 4, 0, -2, 0), Term(-7888, 2, 1, -1, 0),
        Term(-6766, 2, 1, 0, 0), Term(-5163, 1, 0, -1, 0),
        Term(4987, 1, 1, 0, 0), Term(4036, 2, -1, 1, 0),
        Term(3994, 2, 0, 2, 0), Term(3861, 4, 0, 0, 0),
        Term(3665, 2, 0, -3, 0), Term(-2689, 0, 1, -2, 0),
        Term(-2602, 2, 0, -1, 2), Term(2390, 2, -1, -2, 0),
        Term(-2348, 1, 0, 1, 0), Term(2236, 2, -2, 0, 0),
        Term(-2120, 0, 1, 2, 0), Term(-2069, 0, 2, 0, 0),
        Term(2048, 2, -2, -1, 0), Term(-1773, 2, 0, 1, -2),
        Term(-1595, 2, 0, 0, 2), Term(1215, 4, -1, -1, 0),
        Term(-1110, 0, 0, 2, 2), Term(-892, 3, 0, -1, 0),
        Term(-810, 2, 1, 1, 0), Term(759, 4, -1, -2, 0),
        Term(-713, 0, 2, -1, 0), Term(-700, 2, 2, -1, 0),
        Term(691, 2, 1, -2, 0), Term(596, 2, -1, 0, -2),
        Term(549, 4, 0, 1, 0), Term(537, 0, 0, 4, 0),
        Term(520, 4, -1, 0, 0), Term(-487, 1, 0, -2, 0)
    ]

    // Distance, in units of 0.001 km.
    private static let distanceTerms: [Term] = [
        Term(-20905355, 0, 0, 1, 0), Term(-3699111, 2, 0, -1, 0),
        Term(-2955968, 2, 0, 0, 0), Term(-569925, 0, 0, 2, 0),
        Term(48888, 0, 1, 0, 0), Term(-3149, 0, 0, 0, 2),
        Term(246158, 2, 0, -2, 0), Term(-152138, 2, -1, -1, 0),
        Term(-170733, 2, 0, 1, 0), Term(-204586, 2, -1, 0, 0),
        Term(-129620, 0, 1, -1, 0), Term(108743, 1, 0, 0, 0),
        Term(104755, 0, 1, 1, 0), Term(10321, 2, 0, 0, -2),
        Term(79661, 0, 0, 1, -2), Term(-34782, 4, 0, -1, 0),
        Term(-23210, 0, 0, 3, 0), Term(-21636, 4, 0, -2, 0),
        Term(24208, 2, 1, -1, 0), Term(30824, 2, 1, 0, 0),
        Term(-8379, 1, 0, -1, 0), Term(-16675, 1, 1, 0, 0),
        Term(-12831, 2, -1, 1, 0), Term(-10445, 2, 0, 2, 0),
        Term(-11650, 4, 0, 0, 0), Term(14403, 2, 0, -3, 0),
        Term(-7003, 0, 1, -2, 0), Term(10056, 2, -1, -2, 0),
        Term(6322, 1, 0, 1, 0), Term(-9884, 2, -2, 0, 0),
        Term(5751, 0, 1, 2, 0), Term(-4950, 2, -2, -1, 0),
        Term(4130, 2, 0, 1, -2), Term(-3958, 4, -1, -1, 0),
        Term(3258, 3, 0, -1, 0), Term(2616, 2, 1, 1, 0),
        Term(-1897, 4, -1, -2, 0), Term(-2117, 0, 2, -1, 0),
        Term(2354, 2, 2, -1, 0), Term(-1423, 4, 0, 1, 0),
        Term(-1117, 0, 0, 4, 0), Term(-1571, 4, -1, 0, 0),
        Term(-1739, 1, 0, -2, 0), Term(-4421, 0, 0, 2, -2),
        Term(1165, 0, 2, 1, 0), Term(8752, 2, 0, -1, -2)
    ]

    // Latitude, in units of 1e-6 degrees (table 47.B).
    private static let latitudeTerms: [Term] = [
        Term(5128122, 0, 0, 0, 1), Term(280602, 0, 0, 1, 1),
        Term(277693, 0, 0, 1, -1), Term(173237, 2, 0, 0, -1),
        Term(55413, 2, 0, -1, 1), Term(46271, 2, 0, -1, -1),
        Term(32573, 2, 0, 0, 1), Term(17198, 0, 0, 2, 1),
        Term(9266, 2, 0, 1, -1), Term(8822, 0, 0, 2, -1),
        Term(8216, 2, -1, 0, -1), Term(4324, 2, 0, -2, -1),
        Term(4200, 2, 0, 1, 1), Term(-3359, 2, 1, 0, -1),
        Term(2463, 2, -1, -1, 1), Term(2211, 2, -1, 0, 1),
        Term(2065, 2, -1, -1, -1), Term(-1870, 0, 1, -1, -1),
        Term(1828, 4, 0, -1, -1), Term(-1794, 0, 1, 0, 1),
        Term(-1749, 0, 0, 0, 3), Term(-1565, 0, 1, -1, 1),
        Term(-1491, 1, 0, 0, 1), Term(-1475, 0, 1, 1, 1),
        Term(-1410, 0, 1, 1, -1), Term(-1344, 0, 1, 0, -1),
        Term(-1335, 1, 0, 0, -1), Term(1107, 0, 0, 3, 1),
        Term(1021, 4, 0, 0, -1), Term(833, 4, 0, -1, 1)
    ]

    /// The fundamental arguments, all in degrees.
    private struct Arguments {
        let lPrime: Angle, d: Angle, m: Angle, mPrime: Angle, f: Angle
        let a1: Angle, a2: Angle, a3: Angle
        /// Eccentricity correction: terms involving the sun's anomaly are
        /// scaled by it, because Earth's orbit is not a circle and has been
        /// slowly rounding off.
        let e: Double
    }

    private static func arguments(at tt: JulianDay) -> Arguments {
        let t = tt.julianCenturies
        let t2 = t * t, t3 = t2 * t, t4 = t3 * t

        var lp = 218.3164477 + 481267.88123421 * t
        lp -= 0.0015786 * t2
        lp += t3 / 538841 - t4 / 65194000

        var d = 297.8501921 + 445267.1114034 * t
        d -= 0.0018819 * t2
        d += t3 / 545868 - t4 / 113065000

        var m = 357.5291092 + 35999.0502909 * t
        m -= 0.0001536 * t2
        m += t3 / 24490000

        var mp = 134.9633964 + 477198.8675055 * t
        mp += 0.0087414 * t2
        mp += t3 / 69699 - t4 / 14712000

        var f = 93.2720950 + 483202.0175233 * t
        f -= 0.0036539 * t2
        f -= t3 / 3526000
        f += t4 / 863310000

        return Arguments(
            lPrime: Angle(degrees: lp).normalized,
            d: Angle(degrees: d).normalized,
            m: Angle(degrees: m).normalized,
            mPrime: Angle(degrees: mp).normalized,
            f: Angle(degrees: f).normalized,
            a1: Angle(degrees: 119.75 + 131.849 * t).normalized,
            a2: Angle(degrees: 53.09 + 479264.290 * t).normalized,
            a3: Angle(degrees: 313.45 + 481266.484 * t).normalized,
            e: 1 - 0.002516 * t - 0.0000074 * t2
        )
    }

    private static func sum(_ terms: [Term], _ a: Arguments, sine: Bool) -> Double {
        var total = 0.0
        for term in terms {
            var argument = term.d * a.d.degrees + term.m * a.m.degrees
            argument += term.mPrime * a.mPrime.degrees + term.f * a.f.degrees
            let angle = Angle(degrees: argument)

            // Terms in the sun's anomaly are scaled by the eccentricity, once
            // per power of M.
            var coefficient = term.coefficient
            if abs(term.m) == 1 { coefficient *= a.e }
            if abs(term.m) == 2 { coefficient *= a.e * a.e }

            total += coefficient * (sine ? angle.sine : angle.cosine)
        }
        return total
    }

    /// - Parameter tt: Terrestrial Time.
    public static func position(at tt: JulianDay) -> LunarPosition {
        let a = arguments(at: tt)

        var sigmaL = sum(longitudeTerms, a, sine: true)
        var sigmaB = sum(latitudeTerms, a, sine: true)
        let sigmaR = sum(distanceTerms, a, sine: false)

        // Additive terms for Venus, Jupiter and the flattening of the Earth.
        sigmaL += 3958 * a.a1.sine
        sigmaL += 1962 * (a.lPrime - a.f).sine
        sigmaL += 318 * a.a2.sine

        sigmaB += -2235 * a.lPrime.sine
        sigmaB += 382 * a.a3.sine
        sigmaB += 175 * (a.a1 - a.f).sine
        sigmaB += 175 * (a.a1 + a.f).sine
        sigmaB += 127 * (a.lPrime - a.mPrime).sine
        sigmaB += -115 * (a.lPrime + a.mPrime).sine

        let longitude = (a.lPrime + Angle(degrees: sigmaL / 1e6)).normalized
        let latitude = Angle(degrees: sigmaB / 1e6)
        let distance = 385000.56 + sigmaR / 1000

        // Apparent longitude: add the nutation in longitude.
        let nutation = EarthOrientation.nutation(at: tt)
        let apparent = longitude + nutation.longitude
        let obliquity = EarthOrientation.trueObliquity(at: tt)

        // Ecliptic to equatorial.
        let sinL = apparent.sine, cosL = apparent.cosine
        let sinB = latitude.sine, cosB = latitude.cosine
        let sinE = obliquity.sine, cosE = obliquity.cosine

        let ra = Angle(radians: atan2(sinL * cosE - (sinB / cosB) * sinE, cosL)).normalized
        let dec = Angle(radians: asin(sinB * cosE + cosB * sinE * sinL))

        return LunarPosition(
            equatorial: EquatorialCoordinate(rightAscension: ra, declination: dec),
            longitude: apparent,
            latitude: latitude,
            distance: distance
        )
    }

    /// The moon as seen from a place on Earth at a moment of Universal Time.
    ///
    /// Topocentric parallax matters here in a way it does not for the sun: the
    /// moon is close enough that an observer on the surface sees it up to a
    /// degree from where a geocentric ephemeris puts it — twice its own width.
    public static func horizontal(at ut: JulianDay, site: GeographicSite,
                                  refracted: Bool = true) -> HorizontalCoordinate {
        let tt = ut.terrestrialTime
        let position = position(at: tt)
        let nutation = EarthOrientation.nutation(at: tt)
        let obliquity = EarthOrientation.trueObliquity(at: tt)
        let sidereal = Sidereal.greenwichApparent(at: ut, nutation: nutation,
                                                  obliquity: obliquity)

        var coordinate = position.equatorial.horizontal(at: site, siderealTime: sidereal,
                                                        refracted: false)

        // Parallax: an observer on the surface is one Earth radius off centre,
        // which pushes the moon *down* toward the horizon.
        let parallax = Angle(radians: asin(6378.14 / position.distance))
        let sinAltitude = coordinate.altitude.sine
        let correction = Angle(radians: -parallax.radians * sqrt(max(0, 1 - sinAltitude * sinAltitude)))
        coordinate = HorizontalCoordinate(
            altitude: refracted
                ? Refraction.apparentAltitude(trueAltitude: coordinate.altitude + correction)
                : coordinate.altitude + correction,
            azimuth: coordinate.azimuth)
        return coordinate
    }

    /// How much of the disc is lit, and how far through the month it is.
    public static func phase(at tt: JulianDay) -> LunarPhase {
        let moon = position(at: tt)
        let sun = Sun.position(at: tt)

        // Elongation between the two, on the sky.
        let cosElongation = moon.latitude.cosine * (moon.longitude - sun.apparentLongitude).cosine
        let elongation = Angle(radians: acos(min(1, max(-1, cosElongation))))

        // Phase angle at the moon, between Earth and the sun. The sun's
        // distance in km, so the geometry is in one unit.
        let sunDistance = sun.radiusVector * 149_597_870.7
        let phaseAngle = Angle(radians: atan2(
            sunDistance * elongation.sine,
            moon.distance - sunDistance * elongation.cosine))

        let illuminated = (1 + phaseAngle.cosine) / 2

        // Age from the elongation, which runs 0 to 360 through the month.
        let difference = (moon.longitude - sun.apparentLongitude).normalized
        let age = difference.degrees / 360 * 29.530588

        return LunarPhase(illuminatedFraction: illuminated,
                          phaseAngle: phaseAngle,
                          age: age)
    }

    /// Longitude of the ascending node of the moon's orbit.
    ///
    /// This is the hand that turns the 18.6-year cycle. The moon's path is
    /// tilted about 5.15° to the ecliptic, and the node's slow regression
    /// swings the extremes of moonrise wider than the sun's, then narrower,
    /// then wider again. At the wide end — a **major standstill** — the
    /// moonrise reaches beyond anything the sun ever does, and the long sides
    /// of the Station Stone rectangle point at it.
    public static func ascendingNode(at tt: JulianDay) -> Angle {
        let t = tt.julianCenturies
        var omega = 125.0445479 - 1934.1362891 * t
        omega += 0.0020754 * t * t
        omega += t * t * t / 467441 - t * t * t * t / 60616000
        return Angle(degrees: omega).normalized
    }

    /// The moon's greatest possible declination at a moment — the envelope the
    /// standstills trace.
    ///
    /// At a major standstill this reaches about 28.7°, well beyond the sun's
    /// 23.4°; at a minor standstill only about 18.1°. The swing between them is
    /// the 18.61-year cycle, and it falls out of the node's regression rather
    /// than being written down anywhere.
    public static func standstillDeclination(at tt: JulianDay) -> Angle {
        let obliquity = EarthOrientation.meanObliquity(at: tt)
        let inclination = Angle(degrees: 5.145)
        let node = ascendingNode(at: tt)
        // The orbital plane's tilt to the equator varies as the node regresses.
        return Angle(degrees: abs(obliquity.degrees + inclination.degrees * node.cosine))
    }
}
