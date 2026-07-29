import Foundation

/// The machinery that turns a catalogue place into a point in tonight's sky —
/// or the sky of 2500 BC, which is the reason half of this exists.
///
/// Three pieces, all pure arithmetic. **Proper motion**: stars move, and over
/// this app's five millennia that is not pedantry — Arcturus covers nearly
/// three degrees, six moon-widths. **Precession**: the equinox the catalogue
/// measures from swings most of a quarter of the way round the ecliptic,
/// using the same `Precession` series the pole star already trusts, so the
/// two can never disagree about which star the sky turns about. **The world
/// frame**: one rotation built from sidereal time and latitude, handed to the
/// GPU so nine thousand stars cost three dot products each, not a transcendental
/// per frame per star.
public enum StarField {

    /// The Hipparcos catalogue epoch, J1991.25, as a Julian day.
    /// J2000.0 − 8.75 years of 365.25 days exactly.
    public static let hipparcosEpoch = JulianDay(2_448_349.0625)

    /// A catalogue place carried forward (or back) by proper motion alone.
    ///
    /// Linear, which is the honest model at this precision: `pmRACosDec` is
    /// the catalogue's μα★ (already times cos δ), in mas/yr, so the RA rate
    /// recovers the 1/cos δ the catalogue folded in. Stars within a tenth of
    /// a degree of the pole keep their catalogued RA rather than divide by
    /// a vanishing cosine — none of the bright sky lives there.
    public static func properMotionApplied(rightAscension: Angle, declination: Angle,
                                           pmRACosDec: Double, pmDeclination: Double,
                                           at tt: JulianDay)
        -> (rightAscension: Angle, declination: Angle) {
        let years = (tt.value - hipparcosEpoch.value) / 365.25
        let cosDec = declination.cosine
        let ra = abs(cosDec) > 0.002
            ? rightAscension + Angle(degrees: pmRACosDec * years / 3_600_000 / cosDec)
            : rightAscension
        let dec = declination + Angle(degrees: pmDeclination * years / 3_600_000)
        return (ra.normalized, Angle(degrees: min(max(dec.degrees, -90), 90)))
    }

    /// A J2000-frame place expressed against the equator and equinox of date.
    ///
    /// The route runs through the ecliptic because that is where the repo's
    /// precession model lives: equatorial → ecliptic at the fixed J2000
    /// obliquity, longitude advanced by the accumulated general precession,
    /// then back to equatorial at the obliquity *of date*. The same
    /// convention `Precession.northCelestialPole` uses, with the frame
    /// rotating instead of the pole — the two are one geometry, and
    /// `StarFieldTests` pins Thuban to the pole of 2800 BC to prove they
    /// stayed that way.
    public static func equatorialOfDate(rightAscension: Angle, declination: Angle,
                                        at tt: JulianDay)
        -> (rightAscension: Angle, declination: Angle) {
        let obliquityJ2000 = Angle(degrees: 23.4392911)

        // Equatorial → ecliptic, J2000.
        let sinDec = declination.sine, cosDec = declination.cosine
        let longitude = Angle(radians: atan2(
            rightAscension.sine * obliquityJ2000.cosine
                + (sinDec / max(cosDec, 1e-9)) * obliquityJ2000.sine,
            rightAscension.cosine))
        let latitude = Angle(radians: asin(
            min(1, max(-1, sinDec * obliquityJ2000.cosine
                           - cosDec * obliquityJ2000.sine * rightAscension.sine))))

        // The equinox of date sits at ecliptic longitude −p(t) of the J2000
        // frame, so longitudes measured from it grow by p(t).
        let advanced = (longitude + Precession.generalPrecession(at: tt)).normalized

        // Ecliptic → equatorial, obliquity of date.
        let obliquity = EarthOrientation.meanObliquity(at: tt)
        let ra = Angle(radians: atan2(
            advanced.sine * obliquity.cosine - latitude.tangent * obliquity.sine,
            advanced.cosine)).normalized
        let dec = Angle(radians: asin(
            min(1, max(-1, latitude.sine * obliquity.cosine
                           + latitude.cosine * obliquity.sine * advanced.sine))))
        return (ra, dec)
    }

    /// The rotation from the equatorial frame of date into world axes
    /// (+X east, +Y up, +Z south), as three rows.
    ///
    /// A star's equatorial unit vector dotted with each row gives its world
    /// direction, which is all the GPU needs. Built from the local sidereal
    /// angle (Greenwich sidereal time plus east longitude) and the latitude;
    /// the fixtures are old navigation: the pole stands at the latitude's
    /// altitude, and a star on the equator crosses the meridian at 90° minus
    /// latitude, due south.
    public static func worldRows(siderealTime: Angle, site: GeographicSite)
        -> (east: SIMD3<Double>, up: SIMD3<Double>, south: SIMD3<Double>) {
        let theta = (siderealTime + site.longitude).normalized
        let phi = site.latitude
        let east = SIMD3(-theta.sine, theta.cosine, 0)
        let up = SIMD3(phi.cosine * theta.cosine, phi.cosine * theta.sine, phi.sine)
        let south = SIMD3(phi.sine * theta.cosine, phi.sine * theta.sine, -phi.cosine)
        return (east, up, south)
    }

    /// A star's equatorial unit vector: x toward the equinox, z the pole.
    public static func unitVector(rightAscension: Angle, declination: Angle)
        -> SIMD3<Double> {
        SIMD3(declination.cosine * rightAscension.cosine,
              declination.cosine * rightAscension.sine,
              declination.sine)
    }

    /// Whether the moon's disc hides a star.
    ///
    /// The occlusion cone is 1.6 lunar radii — the disc plus the glare the
    /// renderer draws around it; a star vanishing exactly at the limb would
    /// reappear inside the glow and look like a rendering fault. A moon
    /// below the horizon hides nothing. The star shader restates this test
    /// by hand (MSL cannot import it) — change here, change there.
    public static func hiddenByMoon(starDirection: SIMD3<Double>,
                                    moonDirection: SIMD3<Double>,
                                    moonAngularRadius: Double) -> Bool {
        guard moonDirection.y > -0.1 else { return false }
        let cosSeparation = starDirection.x * moonDirection.x
            + starDirection.y * moonDirection.y
            + starDirection.z * moonDirection.z
        return cosSeparation > cos(moonAngularRadius * 1.6)
    }

    /// How visible a star of a given magnitude is against the twilight.
    ///
    /// The bright stars come out first — Sirius in civil twilight, the
    /// sixth-magnitude sky only once the sun is well below −12°. Modelled as
    /// a Hermite fade whose onset slides one degree of sun altitude per
    /// magnitude: zero above the threshold, full two degrees below it. The
    /// slope is an artistic reading of a real progression, not photometry,
    /// and the label matters more than the constant.
    public static func visibility(sunAltitude: Angle, magnitude: Double) -> Double {
        let threshold = -3.0 - max(magnitude, 0)
        let t = min(max((threshold - sunAltitude.degrees) / 2, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
