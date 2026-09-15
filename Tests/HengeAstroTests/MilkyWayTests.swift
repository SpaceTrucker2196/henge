import XCTest
import simd
@testable import HengeAstro

/// The star map's geometry against published places, not against the code
/// that reads it.
final class MilkyWayTests: XCTestCase {

    private func direction(ra: Double, dec: Double) -> SIMD3<Double> {
        StarField.unitVector(rightAscension: Angle(degrees: ra), declination: Angle(degrees: dec))
    }

    // ── the picture ─────────────────────────────────────────────────────────

    func testTheEquinoxSitsAtTheCentreOfTheMap() {
        let uv = MilkyWay.textureCoordinate(direction: direction(ra: 0, dec: 0))
        XCTAssertEqual(uv.x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(uv.y, 0.5, accuracy: 1e-9)
    }

    func testRightAscensionIncreasesToTheLeft() {
        // 6h sits a quarter of the way in from the left edge, not the right —
        // the map is seen from inside the sphere. Get this backwards and the
        // whole sky is mirrored: Orion would draw his sword left-handed.
        let uv = MilkyWay.textureCoordinate(direction: direction(ra: 90, dec: 0))
        XCTAssertEqual(uv.x, 0.25, accuracy: 1e-9)
        let far = MilkyWay.textureCoordinate(direction: direction(ra: 270, dec: 0))
        XCTAssertEqual(far.x, 0.75, accuracy: 1e-9)
    }

    func testThePolesAreTheTopAndBottomEdges() {
        XCTAssertEqual(MilkyWay.textureCoordinate(direction: SIMD3(0, 0, 1)).y, 0, accuracy: 1e-9)
        XCTAssertEqual(MilkyWay.textureCoordinate(direction: SIMD3(0, 0, -1)).y, 1, accuracy: 1e-9)
    }

    /// Sagittarius A*, J2000 17h45m40.04s −29°00′28.1″ (Reid & Brunthaler
    /// 2004). The bulge in the picture is lower right of centre; this is why.
    func testTheGalacticCentreLandsOnTheBulge() {
        let uv = MilkyWay.textureCoordinate(direction: direction(ra: 266.41683, dec: -29.00781))
        XCTAssertEqual(uv.x, 0.5 - 266.41683 / 360 + 1, accuracy: 1e-6)
        XCTAssertEqual(uv.y, 0.5 + 29.00781 / 180, accuracy: 1e-6)
        XCTAssertGreaterThan(uv.x, 0.7)
        XCTAssertLessThan(uv.x, 0.8)
        XCTAssertGreaterThan(uv.y, 0.6)
    }

    /// The Large Magellanic Cloud, J2000 05h23m34s −69°45′ — the smudge at
    /// the bottom left of the picture.
    func testTheMagellanicCloudSitsBottomLeft() {
        let uv = MilkyWay.textureCoordinate(direction: direction(ra: 80.894, dec: -69.756))
        XCTAssertLessThan(uv.x, 0.35)
        XCTAssertGreaterThan(uv.y, 0.85)
    }

    // ── the frame ───────────────────────────────────────────────────────────

    func testTheFrameIsTheIdentityAtJ2000() {
        let rows = MilkyWay.j2000Rows(at: JulianDay(2_451_545.0))
        for (row, axis) in [(rows.x, SIMD3<Double>(1, 0, 0)),
                            (rows.y, SIMD3<Double>(0, 1, 0)),
                            (rows.z, SIMD3<Double>(0, 0, 1))] {
            XCTAssertEqual(simd_length(row - axis), 0, accuracy: 1e-6)
        }
    }

    func testTheFrameStaysARotationInDeepTime() {
        let rows = MilkyWay.j2000Rows(at: JulianDay(2_451_545.0 - 4500 * 365.25))
        for row in [rows.x, rows.y, rows.z] {
            XCTAssertEqual(simd_length(row), 1, accuracy: 1e-9)
        }
        XCTAssertEqual(simd_dot(rows.x, rows.y), 0, accuracy: 1e-8)
        XCTAssertEqual(simd_dot(rows.y, rows.z), 0, accuracy: 1e-8)
        XCTAssertEqual(simd_dot(rows.z, rows.x), 0, accuracy: 1e-8)
        // Right-handed, or the map would be mirrored.
        XCTAssertEqual(simd_dot(simd_cross(rows.x, rows.y), rows.z), 1, accuracy: 1e-8)
    }

    /// The pole of 2800 BC, carried back to J2000, must be Thuban — the same
    /// datum `StarFieldTests` pins from the other side, and the same
    /// tolerance: the in-repo precession is about half a degree out that far
    /// back, and the claim is "Thuban held the pole", not a modern ephemeris.
    func testThePoleOfTheSarsenEraComesBackAsThuban() {
        let rows = MilkyWay.j2000Rows(at: JulianDay(2_451_545.0 - 4799 * 365.25))
        // (0, 0, 1) in the frame of date: its J2000 components are the third
        // component of each row.
        let poleInJ2000 = SIMD3(rows.x.z, rows.y.z, rows.z.z)
        let thuban = direction(ra: 211.0976, dec: 64.3758)
        let separation = acos(min(1, simd_dot(poleInJ2000, thuban))) * 180 / .pi
        XCTAssertLessThan(separation, 0.7,
                          "the pole of 2800 BC sits \(separation)° from Thuban")
    }

    // ── twilight ────────────────────────────────────────────────────────────

    func testTheBandKeepsTheStarsHours() {
        XCTAssertEqual(MilkyWay.visibility(sunAltitude: Angle(degrees: -3)), 0)
        XCTAssertEqual(MilkyWay.visibility(sunAltitude: Angle(degrees: -12)), 1)
        XCTAssertEqual(MilkyWay.visibility(sunAltitude: Angle(degrees: -8)),
                       StarField.visibility(sunAltitude: Angle(degrees: -8), magnitude: 4),
                       accuracy: 1e-12)
    }
}
