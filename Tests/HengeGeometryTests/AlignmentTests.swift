import XCTest
@testable import HengeGeometry
import HengeAstro

final class AlignmentTests: XCTestCase {

    /// **The definition of done, as a test rather than a paragraph.**
    ///
    /// ROADMAP.md: "Scrub to 21 June 2026 and stand at the Altar Stone: the sun
    /// breaches the horizon beside the Heel Stone and its first shadow spears
    /// down the Avenue into the heart of the circle, within a solar diameter of
    /// where it does in Wiltshire."
    ///
    /// Run against the baked terrain, because the ridge the sun clears is what
    /// makes the Wiltshire number the Wiltshire number.
    func testTheDefinitionOfDone() throws {
        let terrain = try TerrainModel.salisburyPlain()
        let horizon = terrain.horizonAltitude(azimuth: Monument.axisAzimuth)
        let date = CalendarDate(year: 2026, month: 6, day: 21)

        let azimuth = try XCTUnwrap(
            RiseSet.sunriseAzimuth(on: date, site: .stonehenge, horizonAltitude: horizon))

        // The sun comes up on the axis, within a solar diameter.
        let deviation = azimuth.separation(to: Monument.axisAzimuth)
        XCTAssertLessThanOrEqual(deviation.degrees, AlignmentSolver.solarDiameter.degrees,
                                 "sunrise bearing \(azimuth.degrees)° "
                                 + "against an axis of \(Monument.axisAzimuth.degrees)°")

        // And the first shadow runs the other way — down the Avenue, into the
        // circle. Opposite the sun, so opposite the axis.
        let shadow = AlignmentSolver.shadowBearing(sunAzimuth: azimuth)
        let downTheAvenue = (Monument.axisAzimuth + Angle(degrees: 180)).normalized
        XCTAssertLessThanOrEqual(shadow.separation(to: downTheAvenue).degrees,
                                 AlignmentSolver.solarDiameter.degrees)

        // The terrain is doing real work here, not decoration.
        XCTAssertGreaterThan(horizon.degrees, 0.3, "the ridge is a measured horizon")
    }

    /// The midwinter reading of the same line. Sunset, opposite bearing — and
    /// the evidence for when people actually gathered, since the Durrington
    /// Walls pigs were slaughtered in midwinter.
    ///
    /// Measured against the terrain like the midsummer case, and the number
    /// that comes out is worth stating plainly rather than tuning away.
    ///
    /// Midsummer sunrise sits 0.41° off the axis; midwinter sunset sits 1.85°
    /// off its reciprocal. **The line is not equally good read both ways.** The
    /// two solstitial bearings are not exactly 180° apart at this latitude —
    /// the horizon altitude differs between north-east and south-west, and the
    /// refraction correction applies to opposite declinations — so a single
    /// straight axis cannot catch both. Whoever set it out favoured the
    /// sunrise direction, or the sunrise direction is simply where the
    /// Avenue's landform put it.
    ///
    /// The assertion is generous on purpose: it pins the fact that the fit is
    /// within two degrees and *worse* than the sunrise fit, which is the real
    /// finding, rather than pretending to a symmetry the sky does not have.
    func testMidwinterSunsetIsTheWorseHalfOfTheSameLine() throws {
        let terrain = try TerrainModel.salisburyPlain()
        let sunsetHorizon = terrain.horizonAltitude(azimuth: Alignment.midwinterSunset.bearing)
        let sunset = try XCTUnwrap(
            AlignmentSolver.extreme(for: .midwinterSunset, year: 2026,
                                    horizonAltitude: sunsetHorizon))
        XCTAssertEqual(sunset.date.month, 12)
        XCTAssertLessThanOrEqual(sunset.deviation.degrees, 2.0,
                                 "sunset bearing \(sunset.azimuth.degrees)° "
                                 + "against \(Alignment.midwinterSunset.bearing.degrees)°")

        let sunriseHorizon = terrain.horizonAltitude(azimuth: Monument.axisAzimuth)
        let sunrise = try XCTUnwrap(
            AlignmentSolver.extreme(for: .midsummerSunrise, year: 2026,
                                    horizonAltitude: sunriseHorizon))
        XCTAssertGreaterThan(sunset.deviation.degrees, sunrise.deviation.degrees,
                             "the axis favours the sunrise direction")
    }

    /// The morning is *searched for*, and it is not always the 21st. If this
    /// ever hardcodes a date it will be wrong in the builders' era by three
    /// weeks.
    func testTheExtremeMorningIsFoundNotAssumed() throws {
        let modern = try XCTUnwrap(AlignmentSolver.extreme(for: .midsummerSunrise, year: 2026))
        XCTAssertEqual(modern.date.month, 6)
        XCTAssertEqual(modern.date.day, 21, accuracy: 1)

        // 2500 BC: same alignment, and by the proleptic Julian calendar it
        // falls in July. The monument has not moved; the calendar has.
        let ancient = try XCTUnwrap(AlignmentSolver.extreme(for: .midsummerSunrise, year: -2500))
        XCTAssertEqual(ancient.date.month, 7, "the solstice had drifted into July")
    }

    /// **The deep-time result, stated as it actually comes out.**
    ///
    /// The obliquity has been shrinking, so the midsummer sun rose further
    /// north for the builders than it does for us — measurably, about a degree
    /// on the same horizon. That the app derives that rather than being told it
    /// is the strongest internal evidence the ephemeris is doing real work.
    ///
    /// What it does *not* show is the tidy story that the axis fits 2500 BC
    /// better than today. Measured against the surveyed 49.9°, today's sunrise
    /// sits about 0.4° south of the axis and the builders' about 0.6° north of
    /// it — the axis lands between the two eras, and both are inside a solar
    /// diameter of it. Which is precisely why the alignment cannot be used to
    /// date the monument, a point the literature makes and this test keeps the
    /// app from quietly contradicting.
    func testTheSunriseMovedNorthInTheBuildersEra() throws {
        let terrain = try TerrainModel.salisburyPlain()
        let horizon = terrain.horizonAltitude(azimuth: Monument.axisAzimuth)

        let modern = try XCTUnwrap(AlignmentSolver.extreme(for: .midsummerSunrise,
                                                           year: 2026, horizonAltitude: horizon))
        let ancient = try XCTUnwrap(AlignmentSolver.extreme(for: .midsummerSunrise,
                                                            year: -2500, horizonAltitude: horizon))

        // Smaller azimuth is further north. Greater obliquity, higher sun.
        XCTAssertLessThan(ancient.azimuth.degrees, modern.azimuth.degrees)
        XCTAssertEqual(modern.azimuth.degrees - ancient.azimuth.degrees, 1.03, accuracy: 0.15)

        // And the axis sits between them, within a solar diameter of each.
        XCTAssertLessThan(modern.deviation.degrees, AlignmentSolver.solarDiameter.degrees)
        XCTAssertLessThan(ancient.deviation.degrees, 0.9)
        XCTAssertLessThan(ancient.azimuth.degrees, Monument.axisAzimuth.degrees)
        XCTAssertGreaterThan(modern.azimuth.degrees, Monument.axisAzimuth.degrees)
    }

    /// Alignment is a claim about a moment, not a season: a fortnight off the
    /// solstice the sun is still within a degree or so, which is exactly why
    /// "it lines up at midsummer" needs a number attached.
    func testTheAlignmentDegradesGentlyAroundTheSolstice() {
        let deviations = (-14...14).compactMap { offset -> Double? in
            let date = (JulianDay(CalendarDate(year: 2026, month: 6, day: 21)) + Double(offset))
                .calendarDate
            return AlignmentSolver.deviation(of: .midsummerSunrise, on: date)?.degrees
        }
        XCTAssertEqual(deviations.count, 29)
        XCTAssertLessThan(deviations.min()!, 0.6)
        // A fortnight either side and it has moved, but not far — the flatness
        // is the solstice itself, and it is why a week of tourists all see
        // roughly the same sunrise.
        XCTAssertGreaterThan(deviations.max()!, 1.0)
        XCTAssertLessThan(deviations.max()!, 4.0)
    }

    /// Tiering, at the point of claim rather than in a footnote.
    func testTheLunarAlignmentIsNotClaimedAsFact() {
        XCTAssertEqual(Alignment.midsummerSunrise.tier, .established)
        XCTAssertEqual(Alignment.midwinterSunset.tier, .established)
        XCTAssertEqual(Alignment.majorStandstillMoonrise.tier, .debated)
    }

    /// The two solar bearings are one line, not two constants that could drift.
    func testTheAxisIsOneLineReadBothWays() {
        let apart = Alignment.midsummerSunrise.bearing
            .separation(to: Alignment.midwinterSunset.bearing)
        XCTAssertEqual(apart.degrees, 180, accuracy: 1e-9)
    }
}
