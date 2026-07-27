import Foundation

/// A place on Earth.
///
/// Longitude is positive **east**. Meeus uses positive west throughout; the
/// conversion happens once, in `hourAngle`, rather than being remembered at
/// every call site.
public struct GeographicSite: Sendable, Hashable {

    public let latitude: Angle
    public let longitude: Angle
    /// Metres above mean sea level.
    public let elevation: Double
    public let name: String

    public init(latitude: Angle, longitude: Angle, elevation: Double = 0, name: String = "") {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.name = name
    }

    /// Stonehenge, Salisbury Plain, Wiltshire.
    ///
    /// Everything in Henge is computed for this point unless the user moves it.
    /// Established: the monument's coordinates are surveyed fact.
    public static let stonehenge = GeographicSite(
        latitude: Angle(degrees: 51.1789),
        longitude: Angle(degrees: -1.8262),
        elevation: 101,
        name: "Stonehenge"
    )

    /// The dip of the sea-level horizon from an elevated eye, in degrees.
    /// At 101 m this is only about 0.3°, but it is the difference between a
    /// sunrise that is right and one that is a minute late.
    public var horizonDip: Angle {
        guard elevation > 0 else { return .zero }
        return Angle(degrees: 0.0293 * sqrt(elevation))
    }
}

/// Right ascension and declination, referred to the equator of date.
public struct EquatorialCoordinate: Sendable, Hashable {
    public let rightAscension: Angle
    public let declination: Angle
    /// Distance in astronomical units, where the body has one.
    public let distance: Double?

    public init(rightAscension: Angle, declination: Angle, distance: Double? = nil) {
        self.rightAscension = rightAscension
        self.declination = declination
        self.distance = distance
    }
}

/// Altitude above the horizon and azimuth measured **from north, through east**.
///
/// That convention is not arbitrary here: the monument's axis is quoted as
/// azimuth ≈ 49.9°, and the whole calendar is read against those bearings.
/// Meeus measures azimuth from south; converting once, here, avoids a class of
/// 180° errors that look plausible on screen.
public struct HorizontalCoordinate: Sendable, Hashable {
    public let altitude: Angle
    public let azimuth: Angle

    public init(altitude: Angle, azimuth: Angle) {
        self.altitude = altitude
        self.azimuth = azimuth.normalized
    }

    public var isAboveHorizon: Bool { altitude.radians > 0 }

    /// Unit vector toward the body in Henge's world axes:
    /// +X east, +Y up, +Z south.
    public var unitVector: (x: Double, y: Double, z: Double) {
        let ca = altitude.cosine
        return (x: ca * azimuth.sine,
                y: altitude.sine,
                z: -ca * azimuth.cosine)
    }
}

/// Atmospheric refraction.
public enum Refraction {

    /// Bennett's formula: apparent minus true altitude, for a body seen at
    /// *true* altitude `h`. Accurate to about 0.07′ over the whole range.
    ///
    /// This is what lifts the rising sun visibly above where geometry alone
    /// would put it — roughly its own diameter at the horizon, which is why
    /// the rise-set condition below sits at −0.833° rather than zero.
    public static func bennett(trueAltitude h: Angle) -> Angle {
        let hDeg = h.degrees
        let arcminutes = 1.0 / tan(Angle(degrees: hDeg + 7.31 / (hDeg + 4.4)).radians)
        return Angle(degrees: arcminutes / 60.0)
    }

    /// Apparent altitude for a true altitude, refraction included.
    public static func apparentAltitude(trueAltitude h: Angle) -> Angle {
        h + bennett(trueAltitude: h)
    }

    /// Standard altitude of the sun's centre at rise and set: refraction at the
    /// horizon (about 34′) plus the sun's semi-diameter (about 16′).
    public static let sunriseAltitude = Angle(degrees: -0.833)
}

public enum Sidereal {

    /// Greenwich mean sidereal time as an angle (Meeus ch. 12, eq. 12.4).
    /// Takes UT, not TT — sidereal time tracks Earth's actual rotation.
    public static func greenwichMean(at ut: JulianDay) -> Angle {
        let t = ut.julianCenturies
        let theta = 280.46061837
            + 360.98564736629 * (ut.value - 2451545.0)
            + 0.000387933 * t * t
            - (t * t * t) / 38710000.0
        return Angle(degrees: theta).normalized
    }

    /// Apparent sidereal time — mean, plus the equation of the equinoxes.
    public static func greenwichApparent(at ut: JulianDay, nutation: Nutation, obliquity: Angle) -> Angle {
        let correction = nutation.longitude.degrees * obliquity.cosine
        return (greenwichMean(at: ut) + Angle(degrees: correction)).normalized
    }
}

public extension EquatorialCoordinate {

    /// Local hour angle: how far west of the meridian the body has turned.
    /// Negative before transit, positive after.
    func hourAngle(at site: GeographicSite, siderealTime: Angle) -> Angle {
        (siderealTime + site.longitude - rightAscension).signedNormalized
    }

    /// Convert to the observer's horizon.
    ///
    /// `refracted` applies Bennett's correction; leave it off when comparing
    /// against geometric reference values.
    func horizontal(at site: GeographicSite, siderealTime: Angle,
                    refracted: Bool = true) -> HorizontalCoordinate {
        let h = hourAngle(at: site, siderealTime: siderealTime)
        let phi = site.latitude
        let dec = declination

        let sinAlt = phi.sine * dec.sine + phi.cosine * dec.cosine * h.cosine
        var altitude = Angle(radians: asin(min(1, max(-1, sinAlt))))

        // Azimuth from north through east. Verified by construction: a body on
        // the meridian south of the zenith gives 180°, and one rising due east
        // gives 90°.
        let y = -dec.cosine * h.sine
        let x = dec.sine * phi.cosine - dec.cosine * phi.sine * h.cosine
        let azimuth = Angle(radians: atan2(y, x)).normalized

        if refracted {
            altitude = Refraction.apparentAltitude(trueAltitude: altitude)
        }
        return HorizontalCoordinate(altitude: altitude, azimuth: azimuth)
    }
}
