import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The Milky Way in pixels: light on a dark night, nothing at noon, and gone
/// when its own switch says so. The stars are drawn in every frame here and
/// only the band's switch moves, so the difference weighed is the band alone.
@MainActor
final class MilkyWayRenderTests: XCTestCase {

    static let size = 256

    /// 2026-09-20 21:00 UT: Cygnus near the zenith over Stonehenge, the
    /// summer band standing up the sky where a camera looking up will see it.
    static let septemberNight = JulianDay(CalendarDate(year: 2026, month: 9, day: 20, hour: 21))

    private func skyMean(sunAltitude: Double, milkyWay: Bool,
                         epoch: JulianDay = septemberNight,
                         target: SIMD3<Float> = SIMD3(0, 60, -40)) throws -> Double {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the band is unverified here.")
        }
        let camera = Camera(position: SIMD3(0, 1.7, 0), target: target)
        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                                         azimuth: Angle(degrees: 0)),
                               camera: camera, grassBlades: false, epoch: epoch)
        state.stars = true
        state.milkyWay = milkyWay
        let renderer = try HengeRenderer(device: device, state: state,
                                         shadowResolution: 512)
        try renderer.load(scene: MonumentScene(stones: []))
        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                             mipmapLevel: 0)
        }
        var total = 0.0
        for i in 0..<(Self.size * Self.size) {
            total += 0.2126 * Double(pixels[i * 4 + 2])
                + 0.7152 * Double(pixels[i * 4 + 1])
                + 0.0722 * Double(pixels[i * 4])
        }
        return total / Double(Self.size * Self.size)
    }

    func testTheBandLightsADarkSky() throws {
        let with = try skyMean(sunAltitude: -30, milkyWay: true)
        let without = try skyMean(sunAltitude: -30, milkyWay: false)
        XCTAssertGreaterThan(with, without + 0.5,
                             "band \(with) against bare sky \(without)")
        // And it is a band, not a wash: the mean must stay a small fraction
        // of the 8-bit range, or the night is grey rather than dark.
        XCTAssertLessThan(with, 40)
    }

    func testTheBandIsGoneAtNoon() throws {
        let with = try skyMean(sunAltitude: 40, milkyWay: true)
        let without = try skyMean(sunAltitude: 40, milkyWay: false)
        XCTAssertEqual(with, without, accuracy: 1e-9)
    }

    /// The band stands where the galaxy is. Pointed at Sagittarius A* the
    /// sky gains far more from the map than pointed at the galactic north
    /// pole in Coma, which is as empty as the sky gets. Measured as the
    /// band's own contribution (map on minus map off) in each direction, so
    /// the richer star field of Sagittarius cannot carry the assertion. The
    /// epoch is mid-July at 23:00 UT, when the centre culminates ten degrees
    /// up in the south from Stonehenge and the pole stands in the west.
    func testTheBandIsBrightestTowardTheGalacticCentre() throws {
        let epoch = JulianDay(CalendarDate(year: 2026, month: 7, day: 15, hour: 23))
        func worldDirection(ra: Double, dec: Double) -> SIMD3<Float> {
            let dated = StarField.equatorialOfDate(rightAscension: Angle(degrees: ra),
                                                   declination: Angle(degrees: dec), at: epoch.terrestrialTime)
            let v = StarField.unitVector(rightAscension: dated.rightAscension,
                                         declination: dated.declination)
            let rows = StarField.worldRows(siderealTime: Sidereal.greenwichMean(at: epoch),
                                           site: .stonehenge)
            func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
            return SIMD3<Float>(Float(dot(v, rows.east)), Float(dot(v, rows.up)), Float(dot(v, rows.south)))
        }
        let centre = worldDirection(ra: 266.41683, dec: -29.00781)
        let pole = worldDirection(ra: 192.85948, dec: 27.12825)
        XCTAssertGreaterThan(centre.y, 0.05, "the galactic centre must be up for this to mean anything")
        XCTAssertGreaterThan(pole.y, 0.2)

        func gain(toward d: SIMD3<Float>) throws -> Double {
            let target = SIMD3<Float>(0, 1.7, 0) + d * 100
            return try skyMean(sunAltitude: -30, milkyWay: true, epoch: epoch, target: target)
                 - skyMean(sunAltitude: -30, milkyWay: false, epoch: epoch, target: target)
        }
        let towardCentre = try gain(toward: centre)
        let towardPole = try gain(toward: pole)
        XCTAssertGreaterThan(towardCentre, 1.0, "centre gain \(towardCentre)")
        XCTAssertGreaterThan(towardCentre, towardPole * 3,
                             "centre \(towardCentre) against pole \(towardPole)")
    }

    /// The band rides the sky, not the dome. The same camera, aimed where
    /// the galactic centre stands at 23:00 UT in mid-July, gains far less
    /// from the map twelve hours earlier, when that patch of sky holds the
    /// thin side of the galaxy instead. A picture pasted to the dome would
    /// give the same gain at any hour.
    func testTheBandTurnsWithTheSky() throws {
        let evening = JulianDay(CalendarDate(year: 2026, month: 7, day: 15, hour: 23))
        let dated = StarField.equatorialOfDate(rightAscension: Angle(degrees: 266.41683),
                                               declination: Angle(degrees: -29.00781),
                                               at: evening.terrestrialTime)
        let v = StarField.unitVector(rightAscension: dated.rightAscension,
                                     declination: dated.declination)
        let rows = StarField.worldRows(siderealTime: Sidereal.greenwichMean(at: evening),
                                       site: .stonehenge)
        func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
        let target = SIMD3<Float>(0, 1.7, 0)
            + SIMD3<Float>(Float(dot(v, rows.east)), Float(dot(v, rows.up)), Float(dot(v, rows.south))) * 100

        func gain(at epoch: JulianDay) throws -> Double {
            try skyMean(sunAltitude: -30, milkyWay: true, epoch: epoch, target: target)
                - skyMean(sunAltitude: -30, milkyWay: false, epoch: epoch, target: target)
        }
        let withCentre = try gain(at: evening)
        let without = try gain(at: evening - 0.5)
        XCTAssertGreaterThan(withCentre, without * 3,
                             "gain \(withCentre) with the centre in frame, \(without) without")
    }
}
