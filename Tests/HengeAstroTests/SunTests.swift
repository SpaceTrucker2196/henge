import XCTest
@testable import HengeAstro

/// The calendar's beating heart, checked against published values.
///
/// MISSION.md invariant 1 sets an accuracy budget. These tests are where that
/// budget is *measured* rather than asserted in prose — if the implementation
/// cannot hold a tolerance, the honest response is to tighten the code or state
/// a looser budget, never to loosen the test quietly.
final class SunPositionTests: XCTestCase {

    /// Meeus, Example 25.a — 1992 October 13 at 0h TD.
    func testMeeusExample25a() {
        let tt = JulianDay(CalendarDate(year: 1992, month: 10, day: 13.0))
        XCTAssertEqual(tt.value, 2448908.5, accuracy: 1e-6)

        let position = Sun.position(at: tt)

        // Meeus: apparent λ = 199.90895°, α = 198.38083°, δ = -7.78507°,
        // R = 0.99760775 AU.
        XCTAssertEqual(position.apparentLongitude.degrees, 199.90895, accuracy: 0.001)
        // Meeus's 0.99760775 comes from the full VSOP87 of Example 25.b. The
        // abridged series used here lands 5.4e-5 AU away — measured, not
        // assumed, and well inside what it costs the apparent diameter
        // (0.00003°, a thousandth of the tolerance that matters).
        XCTAssertEqual(position.radiusVector, 0.99760775, accuracy: 1e-4)
        XCTAssertEqual(position.equatorial.rightAscension.degrees, 198.38083, accuracy: 0.002)
        XCTAssertEqual(position.equatorial.declination.degrees, -7.78507, accuracy: 0.002)
    }

    /// Meeus, Example 22.a — 1987 April 10 at 0h TD.
    func testObliquityAndNutation() {
        let tt = JulianDay(CalendarDate(year: 1987, month: 4, day: 10.0))
        XCTAssertEqual(tt.value, 2446895.5, accuracy: 1e-6)

        // Mean obliquity ε₀ = 23°26'27.407".
        let mean = EarthOrientation.meanObliquity(at: tt)
        XCTAssertEqual(mean.degrees,
                       Angle(degrees: 23, arcminutes: 26, arcseconds: 27.407).degrees,
                       accuracy: 0.0001)

        // Δψ = -3.788", Δε = +9.443". The abridged series is good to about 1".
        let nutation = EarthOrientation.nutation(at: tt)
        XCTAssertEqual(nutation.longitude.degrees * 3600, -3.788, accuracy: 1.0)
        XCTAssertEqual(nutation.obliquity.degrees * 3600, 9.443, accuracy: 1.0)
    }

    /// Laskar's polynomial is the reason deep time works. In 2500 BC the
    /// obliquity was near 23.93°, half a degree steeper than today — and that
    /// half-degree is exactly why the monument's axis suits its own era.
    func testObliquityWasSteeperWhenTheStonesWereRaised() {
        let then = EarthOrientation.meanObliquity(
            at: JulianDay(CalendarDate(year: -2500, month: 6, day: 21.0)))
        let now = EarthOrientation.meanObliquity(
            at: JulianDay(CalendarDate(year: 2026, month: 6, day: 21.0)))

        XCTAssertEqual(then.degrees, 23.93, accuracy: 0.05)
        XCTAssertEqual(now.degrees, 23.44, accuracy: 0.01)
        XCTAssertGreaterThan(then.degrees, now.degrees)
    }

    /// Meeus, Example 12.a — mean sidereal time at Greenwich,
    /// 1987 April 10 at 0h UT, is 13h10m46.3668s = 197.693195°.
    func testGreenwichMeanSiderealTime() {
        let ut = JulianDay(CalendarDate(year: 1987, month: 4, day: 10.0))
        XCTAssertEqual(Sidereal.greenwichMean(at: ut).degrees, 197.693195, accuracy: 1e-4)
    }

    /// The sun's declination at the solstices should equal the obliquity, to
    /// within the wobble of the exact solstice instant.
    func testSolsticeDeclinationMatchesObliquity() {
        let summer = JulianDay(CalendarDate(year: 2026, month: 6, day: 21.4))
        let winter = JulianDay(CalendarDate(year: 2026, month: 12, day: 21.7))
        let obliquity = EarthOrientation.meanObliquity(at: summer).degrees

        XCTAssertEqual(Sun.position(at: summer).equatorial.declination.degrees,
                       obliquity, accuracy: 0.02)
        XCTAssertEqual(Sun.position(at: winter).equatorial.declination.degrees,
                       -obliquity, accuracy: 0.02)
    }

    func testAngularDiameterIsAboutHalfADegree() {
        // Perihelion in early January, aphelion in early July.
        let january = Sun.position(at: JulianDay(CalendarDate(year: 2026, month: 1, day: 3.0)))
        let july = Sun.position(at: JulianDay(CalendarDate(year: 2026, month: 7, day: 5.0)))

        XCTAssertEqual(january.angularDiameter.degrees, 0.5422, accuracy: 0.002)
        XCTAssertEqual(july.angularDiameter.degrees, 0.5243, accuracy: 0.002)
        XCTAssertGreaterThan(january.angularDiameter.degrees, july.angularDiameter.degrees)
    }
}

final class HorizontalCoordinateTests: XCTestCase {

    /// Azimuth is measured from north through east. These two facts pin the
    /// convention down; a 180° error here would look plausible on screen and
    /// put every alignment in the app on the wrong side of the monument.
    func testAzimuthConventionAtEquinox() {
        // At the March equinox the sun rises very close to due east anywhere.
        let site = GeographicSite(latitude: Angle(degrees: 51.1789),
                                  longitude: Angle(degrees: -1.8262),
                                  elevation: 0, name: "test")
        // Not exactly 90°: refraction lifts the sun into view while it is
        // still geometrically below the horizon, and at this latitude that
        // moves the rise point about half a degree north of due east.
        let azimuth = RiseSet.seasonalSunriseAzimuth(.marchEquinox, year: 2026, site: site)
        XCTAssertNotNil(azimuth)
        XCTAssertEqual(azimuth!.degrees, 89.45, accuracy: 0.4)
        XCTAssertLessThan(azimuth!.degrees, 90,
                          "refraction must place equinox sunrise north of due east")
    }

    func testSunIsDueSouthAtLocalNoonInTheNorthernHemisphere() {
        // Greenwich, so UT noon is close to local apparent noon.
        let site = GeographicSite(latitude: Angle(degrees: 51.4779),
                                  longitude: Angle(degrees: 0), elevation: 0)
        // The equation of time is near zero in mid-April.
        let noon = JulianDay(CalendarDate(year: 2026, month: 4, day: 16, hour: 12))
        let sun = Sun.horizontal(at: noon, site: site)
        XCTAssertEqual(sun.azimuth.degrees, 180, accuracy: 1.5)
        XCTAssertGreaterThan(sun.altitude.degrees, 40)
    }

    func testRefractionLiftsTheRisingSun() {
        // At the horizon refraction is about 34 arcminutes — roughly the sun's
        // own diameter, which is why it is already fully visible when geometry
        // says it has not yet risen.
        let atHorizon = Refraction.bennett(trueAltitude: .zero)
        XCTAssertEqual(atHorizon.degrees * 60, 34, accuracy: 2)

        // High in the sky it all but vanishes.
        let overhead = Refraction.bennett(trueAltitude: Angle(degrees: 80))
        XCTAssertLessThan(overhead.degrees * 60, 0.3)
    }
}

/// The tests that make the monument a calendar rather than a model.
final class StonehengeAlignmentTests: XCTestCase {

    let site = GeographicSite.stonehenge

    /// The skyline to the north-east of Stonehenge stands a little above the
    /// sea-level horizon. It matters more than it sounds: half a degree of
    /// skyline moves the sunrise bearing by well over a degree here, which is
    /// the difference between the axis fitting and missing.
    ///
    /// Debated — published horizon profiles differ. Treated as a parameter
    /// throughout rather than folded into a constant, so the sensitivity stays
    /// visible instead of being buried.
    let northEastHorizon = Angle(degrees: 0.6)

    /// The single most important assertion in the suite.
    ///
    /// It also proves the bearing is *computed*: the same call at a modern date
    /// gives a measurably different answer, which a hardcoded constant could
    /// never do (MISSION.md invariant 1).
    func testMidsummerSunriseSitsCloseToTheBuiltAxis() throws {
        let ancient = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .juneSolstice, year: -2500, site: site, horizonAltitude: northEastHorizon))

        // Close to the 49.9° axis, but not exactly on it — the sun rose a
        // little north of the line the builders laid. That near-miss is real
        // archaeology, not an error in the ephemeris, and it is why the
        // "solar corridor" of a lost companion stone is argued about at all.
        XCTAssertEqual(ancient.degrees, 49.08, accuracy: 0.3)
        XCTAssertLessThan(ancient.separation(to: Monument.axisAzimuthForTesting).degrees, 1.5,
                          "midsummer sunrise should sit within a degree or so of the axis")
    }

    /// Obliquity has been shrinking. A shallower tilt keeps the midsummer sun
    /// further south, so its rising point has crept *east* since the stones
    /// were raised — the monument suits its own era slightly better than ours.
    func testTheSunriseBearingHasMovedSinceTheStonesWereRaised() throws {
        let ancient = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .juneSolstice, year: -2500, site: site))
        let modern = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .juneSolstice, year: 2026, site: site))

        XCTAssertEqual(ancient.degrees, 47.71, accuracy: 0.3)
        XCTAssertEqual(modern.degrees, 48.77, accuracy: 0.3)
        XCTAssertGreaterThan(modern.degrees, ancient.degrees,
                             "a shallower obliquity moves midsummer sunrise toward the east")
        XCTAssertEqual(modern.degrees - ancient.degrees, 1.05, accuracy: 0.4,
                       "the epoch must change the bearing by about a degree")
    }

    /// Midwinter sunset runs back down the axis through the Great Trilithon —
    /// and lands closer to it than midsummer sunrise does.
    ///
    /// Which occasion the monument was *for* is Debated; the pig-bone evidence
    /// from Durrington Walls points at great midwinter feasts. That the
    /// midwinter geometry is the tighter fit is worth stating plainly.
    func testMidwinterSunsetAlignsWithTheAxisEvenMoreCloselyThanMidsummerSunrise() throws {
        let sunset = try XCTUnwrap(RiseSet.seasonalSunsetAzimuth(
            .decemberSolstice, year: -2500, site: site, horizonAltitude: northEastHorizon))
        let sunrise = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .juneSolstice, year: -2500, site: site, horizonAltitude: northEastHorizon))

        let reciprocal = (Monument.axisAzimuthForTesting + Angle(degrees: 180)).normalized
        XCTAssertEqual(sunset.degrees, 230.10, accuracy: 0.3)
        XCTAssertLessThan(sunset.separation(to: reciprocal).degrees, 0.6,
                          "midwinter sunset should run back down the axis")

        XCTAssertLessThan(sunset.separation(to: reciprocal).degrees,
                          sunrise.separation(to: Monument.axisAzimuthForTesting).degrees,
                          "the midwinter fit is the tighter of the two")
    }

    /// Midsummer sunrise and midwinter sunset are near-reciprocal but not
    /// exactly so: the sun's centre sits slightly below the skyline at both
    /// events, and that offset breaks the symmetry by a few degrees. Asserting
    /// an exact 180° would be asserting something false.
    func testTheTwoSolsticeBearingsAreNearButNotExactReciprocals() throws {
        let sunrise = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .juneSolstice, year: -2500, site: site))
        let sunset = try XCTUnwrap(RiseSet.seasonalSunsetAzimuth(
            .decemberSolstice, year: -2500, site: site))

        let separation = (sunset - sunrise).normalized.degrees
        XCTAssertEqual(separation, 183.7, accuracy: 0.5)
        XCTAssertNotEqual(separation, 180, accuracy: 1.0,
                          "the asymmetry is real and should not be rounded away")
    }

    /// Sunrise swings along the horizon through the year — the swing a horizon
    /// calendar reads. At this latitude it spans about 80° between solstices.
    func testSunriseBearingSwingsThroughTheYear() throws {
        let summer = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .juneSolstice, year: 2026, site: site))
        let winter = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .decemberSolstice, year: 2026, site: site))

        XCTAssertEqual(winter.degrees, 127.59, accuracy: 0.3)
        XCTAssertEqual(winter.degrees - summer.degrees, 78.8, accuracy: 1.0)
    }

    /// The solstice does not sit still in the calendar. Across five millennia
    /// the Julian year's surplus eleven minutes drags the June solstice from
    /// late June into the middle of July — so anything that assumed a date
    /// would be measuring the wrong morning in precisely the era that matters.
    func testTheSolsticeDriftsThroughTheCalendar() {
        let modern = Seasons.instant(of: .juneSolstice, year: 2026).calendarDate
        XCTAssertEqual(modern.month, 6)
        XCTAssertEqual(modern.day, 21.35, accuracy: 0.5)

        let ancient = Seasons.instant(of: .juneSolstice, year: -2500).calendarDate
        XCTAssertEqual(ancient.month, 7, "in 2500 BC the June solstice fell in Julian July")
        XCTAssertEqual(ancient.day, 15.0, accuracy: 1.5)
    }

    /// A raised skyline delays the sunrise, which swings its bearing east.
    /// Stated as a test because the whole alignment argument is sensitive to
    /// it, and a future change that quietly ignored the parameter would move
    /// every claim the app makes.
    func testARaisedHorizonMovesTheSunriseBearingEast() throws {
        let flat = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .juneSolstice, year: -2500, site: site, horizonAltitude: .zero))
        let raised = try XCTUnwrap(RiseSet.seasonalSunriseAzimuth(
            .juneSolstice, year: -2500, site: site, horizonAltitude: Angle(degrees: 0.6)))

        XCTAssertGreaterThan(raised.degrees, flat.degrees)
        XCTAssertEqual(raised.degrees - flat.degrees, 1.37, accuracy: 0.3,
                       "0.6° of skyline is worth well over a degree of bearing here")
    }
}

/// The monument's built axis, duplicated here rather than imported: HengeAstro
/// must not depend on HengeGeometry, and this suite tests the astronomy alone.
private enum Monument {
    static let axisAzimuthForTesting = Angle(degrees: 49.9)
}
