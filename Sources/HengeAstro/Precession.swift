import Foundation

/// The slow wandering of the celestial pole.
///
/// Earth's axis traces a cone once every twenty-six thousand years, and over
/// the five millennia this app covers that carries the pole most of a quarter
/// of the way round. It is the reason the sky of 2500 BC is not the sky of
/// tonight with the dates changed: the builders had a different pole star, and
/// the constellations sat at different heights on their horizon.
///
/// Nothing here needs a catalogue or a licence. The pole's path is geometry.
public enum Precession {

    /// Accumulated general precession in longitude since J2000, in arcseconds.
    ///
    /// Capitaine et al. (2003), the IAU 2006 series. Fitted for the modern era
    /// and used well beyond it here; the error at 2500 BC is minutes of arc,
    /// which is invisible against a pole star and is stated rather than hidden.
    public static func generalPrecession(at tt: JulianDay) -> Angle {
        let t = tt.julianCenturies
        var arcseconds = 5028.796195 * t
        arcseconds += 1.1054348 * t * t
        arcseconds += 0.00007964 * t * t * t
        arcseconds -= 0.000023857 * t * t * t * t
        return Angle(degrees: arcseconds / 3600)
    }

    /// Where the north celestial pole lies, in ecliptic coordinates.
    ///
    /// The pole sits one obliquity away from the ecliptic pole and swings
    /// around it as precession accumulates. Both quantities are already
    /// computed elsewhere, so the pole comes almost free.
    public static func northCelestialPole(at tt: JulianDay) -> (longitude: Angle, latitude: Angle) {
        let obliquity = EarthOrientation.meanObliquity(at: tt)
        // At J2000 the pole lies toward ecliptic longitude 90° from the
        // equinox, and precession carries it westward from there.
        let longitude = (Angle(degrees: 90) - generalPrecession(at: tt)).normalized
        return (longitude, Angle(degrees: 90) - obliquity)
    }

    /// Angular distance from a star to the celestial pole at a given epoch.
    ///
    /// Positions are J2000 mean places precessed forward or back. Proper motion
    /// is ignored — a known simplification, listed in MISSION.md's non-goals.
    /// Over five millennia it moves the brightest stars by up to a degree,
    /// which is enough to matter for a close call and not enough to change
    /// which star is nearest the pole.
    public static func separationFromPole(_ star: Star, at tt: JulianDay) -> Angle {
        let pole = northCelestialPole(at: tt)

        // Both in ecliptic coordinates; the star's is fixed, the pole's moves.
        let starEcliptic = star.eclipticJ2000
        let sinLat = pole.latitude.sine * starEcliptic.latitude.sine
        let cosLat = pole.latitude.cosine * starEcliptic.latitude.cosine
        let cosSeparation = sinLat + cosLat * (pole.longitude - starEcliptic.longitude).cosine
        return Angle(radians: acos(min(1, max(-1, cosSeparation))))
    }

    /// Which of the candidates is nearest the pole, and how near.
    public static func poleStar(at tt: JulianDay,
                                from candidates: [Star] = Star.poleStarCandidates)
        -> (star: Star, separation: Angle)? {
        candidates
            .map { ($0, separationFromPole($0, at: tt)) }
            .min { $0.1 < $1.1 }
            .map { (star: $0.0, separation: $0.1) }
    }
}

/// A star, by name and J2000 position.
///
/// This is not a catalogue and is not trying to be. It is the handful of stars
/// that have held, or will hold, the pole — a few published coordinates cited
/// like any other constant, the way `Monument` cites surveyed dimensions.
/// The Hipparcos catalogue arrives when the full sky does.
public struct Star: Sendable, Hashable {

    public let name: String
    /// Bayer or common designation.
    public let designation: String
    /// Mean equatorial place at J2000.
    public let rightAscension: Angle
    public let declination: Angle
    public let magnitude: Double

    public init(name: String, designation: String,
                rightAscension: Angle, declination: Angle, magnitude: Double) {
        self.name = name
        self.designation = designation
        self.rightAscension = rightAscension
        self.declination = declination
        self.magnitude = magnitude
    }

    /// J2000 ecliptic coordinates, converted once from the equatorial place.
    public var eclipticJ2000: (longitude: Angle, latitude: Angle) {
        // Obliquity at J2000 exactly.
        let obliquity = Angle(degrees: 23.4392911)
        let sinDec = declination.sine, cosDec = declination.cosine
        let sinRA = rightAscension.sine, cosRA = rightAscension.cosine

        let longitude = Angle(radians: atan2(sinRA * obliquity.cosine
                                             + (sinDec / cosDec) * obliquity.sine,
                                             cosRA)).normalized
        let latitude = Angle(radians: asin(sinDec * obliquity.cosine
                                           - cosDec * obliquity.sine * sinRA))
        return (longitude, latitude)
    }

    /// The stars the pole visits. Positions are J2000 mean places.
    ///
    /// Thuban is the one that matters here: it held the pole around 2800 BC,
    /// within a few centuries of the sarsens going up, and it is what the
    /// builders would have seen the sky turn about.
    public static let poleStarCandidates: [Star] = [
        Star(name: "Polaris", designation: "α Ursae Minoris",
             rightAscension: Angle(degrees: 37.9529), declination: Angle(degrees: 89.2641),
             magnitude: 1.98),
        Star(name: "Thuban", designation: "α Draconis",
             rightAscension: Angle(degrees: 211.0973), declination: Angle(degrees: 64.3758),
             magnitude: 3.65),
        Star(name: "Kochab", designation: "β Ursae Minoris",
             rightAscension: Angle(degrees: 222.6764), declination: Angle(degrees: 74.1555),
             magnitude: 2.08),
        Star(name: "Vega", designation: "α Lyrae",
             rightAscension: Angle(degrees: 279.2347), declination: Angle(degrees: 38.7837),
             magnitude: 0.03),
        Star(name: "Deneb", designation: "α Cygni",
             rightAscension: Angle(degrees: 310.3580), declination: Angle(degrees: 45.2803),
             magnitude: 1.25),
        Star(name: "Alderamin", designation: "α Cephei",
             rightAscension: Angle(degrees: 319.6449), declination: Angle(degrees: 62.5856),
             magnitude: 2.45),
        Star(name: "Errai", designation: "γ Cephei",
             rightAscension: Angle(degrees: 354.8367), declination: Angle(degrees: 77.6323),
             magnitude: 3.21)
    ]
}
