import XCTest
import HengeAstro
@testable import HengeGeometry

/// The vendored Hipparcos subset against the published catalogue — the point
/// of these fixtures is that a reader can check every number on VizieR
/// without running this code.
final class StarCatalogTests: XCTestCase {

    static let catalog = StarCatalog.load()

    private func entries() throws -> [StarCatalog.Entry] {
        try XCTUnwrap(Self.catalog, "the bundled catalogue failed to load").entries
    }

    func testTheNakedEyeSkyIsAllThere() throws {
        // 8,870 Hipparcos entries survive the V ≤ 6.5 cut. Pinned exactly:
        // a regenerated file that quietly gained or lost stars should fail
        // loudly, not drift.
        XCTAssertEqual(try entries().count, 8870)
    }

    func testTheFamousStarsMatchTheirPublishedPlaces() throws {
        let byHip = Dictionary(uniqueKeysWithValues: try entries().map { ($0.hip, $0) })

        // Published Hipparcos values: HIP, V magnitude, RA and Dec (ICRS,
        // epoch J1991.25), from CDS I/239.
        let fixtures: [(name: String, hip: Int, v: Double, ra: Double, dec: Double)] = [
            ("Sirius", 32349, -1.44, 101.2885, -16.7131),
            ("Vega", 91262, 0.03, 279.2341, 38.7830),
            ("Polaris", 11767, 1.97, 37.9461, 89.2641),
            ("Thuban", 68756, 3.67, 211.0976, 64.3758),
            ("Arcturus", 69673, -0.05, 213.9181, 19.1873)
        ]
        for fixture in fixtures {
            let star = try XCTUnwrap(byHip[fixture.hip], "\(fixture.name) is missing")
            XCTAssertEqual(star.magnitude, fixture.v, accuracy: 0.02, fixture.name)
            XCTAssertEqual(star.rightAscension.degrees, fixture.ra, accuracy: 0.001,
                           fixture.name)
            XCTAssertEqual(star.declination.degrees, fixture.dec, accuracy: 0.001,
                           fixture.name)
        }
    }

    func testSiriusIsTheBrightestStarInTheSky() throws {
        let brightest = try XCTUnwrap(try entries().min { $0.magnitude < $1.magnitude })
        XCTAssertEqual(brightest.hip, 32349, "the brightest star is Sirius, "
                       + "and has been for the whole span this app draws")
    }

    func testEveryEntryIsAPlausibleStar() throws {
        for star in try entries() {
            XCTAssertGreaterThanOrEqual(star.rightAscension.degrees, 0)
            XCTAssertLessThan(star.rightAscension.degrees, 360)
            XCTAssertGreaterThanOrEqual(star.declination.degrees, -90)
            XCTAssertLessThanOrEqual(star.declination.degrees, 90)
            XCTAssertLessThanOrEqual(star.magnitude, 6.5, "past the naked-eye cut")
            XCTAssertGreaterThan(star.magnitude, -2, "brighter than Sirius is not a star")
        }
    }

    func testHotStarsRenderBlueAndCoolStarsEmber() {
        let rigel = StarCatalog.colour(forIndex: -0.03)
        let betelgeuse = StarCatalog.colour(forIndex: 1.85)
        XCTAssertGreaterThan(rigel.z, rigel.x, "a B−V near zero leans blue")
        XCTAssertGreaterThan(betelgeuse.x, betelgeuse.z * 2,
                             "a red supergiant's index leans strongly warm")
    }

    func testInstancesCarryTheWholeCatalogueAsUnitVectors() throws {
        let catalog = try XCTUnwrap(Self.catalog)
        let instances = catalog.instances(at: JulianDay(2_451_545.0))
        XCTAssertEqual(instances.count, try entries().count)
        for instance in instances.prefix(500) {
            let length = (instance.direction.x * instance.direction.x
                          + instance.direction.y * instance.direction.y
                          + instance.direction.z * instance.direction.z).squareRoot()
            XCTAssertEqual(length, 1, accuracy: 1e-9)
        }
    }
}
