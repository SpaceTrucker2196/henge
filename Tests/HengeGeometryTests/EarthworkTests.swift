import XCTest
@testable import HengeGeometry
import HengeAstro

/// The enclosure earthwork against Cleal, Walker & Montague (1995) — the
/// arrangement, the causeways, and the difference between the thing as dug
/// and the thing as it stands.
final class EarthworkTests: XCTestCase {

    // ── the arrangement ─────────────────────────────────────────────────────

    func testTheBankStandsInsideTheDitch() {
        // Stonehenge's famous reversal: main bank inside, ditch outside,
        // counterscarp outside that. By the strict typology this makes the
        // monument not a henge; the code should at least agree with the
        // ground.
        XCTAssertLessThan(Earthwork.bankCrest, Earthwork.ditchCentre)
        XCTAssertLessThan(Earthwork.ditchCentre, Earthwork.counterscarpCrest)
        // And the whole circuit sits around 110 m across.
        XCTAssertEqual(Earthwork.ditchCentre * 2, 110, accuracy: 5)
    }

    func testTheProfileStandsAndFallsWhereTheSurveySays() {
        // Sample away from both causeways (due west).
        let east = -Earthwork.bankCrest, south = 0.0
        let bankToday = Earthwork.heightDelta(east: east, south: south,
                                              state: .asItStands)
        XCTAssertGreaterThan(bankToday, 0.3, "today's bank is a real swell")
        XCTAssertLessThan(bankToday, 0.7, "but under a metre of it")

        let ditchEast = -Earthwork.ditchCentre
        let ditchToday = Earthwork.heightDelta(east: ditchEast, south: 0,
                                               state: .asItStands)
        XCTAssertLessThan(ditchToday, -0.3, "today's ditch is a real hollow")

        // Beyond the ring, nothing.
        XCTAssertEqual(Earthwork.heightDelta(east: -70, south: 0,
                                             state: .asItWas), 0)
        XCTAssertEqual(Earthwork.heightDelta(east: -30, south: 0,
                                             state: .asItWas), 0)
    }

    func testAsDugDwarfsAsStands() {
        for radius in [Earthwork.bankCrest, Earthwork.ditchCentre] {
            let fresh = Earthwork.heightDelta(east: -radius, south: 0,
                                              state: .asItWas)
            let now = Earthwork.heightDelta(east: -radius, south: 0,
                                            state: .asItStands)
            XCTAssertGreaterThan(abs(fresh), abs(now) * 2.5,
                                 "silt and erosion take most of the relief")
        }
    }

    // ── the causeways ───────────────────────────────────────────────────────

    func testTheMainEntranceIsLevelOnTheAxis() {
        // The Avenue meets the enclosure through the north-east causeway on
        // the monument's own axis — where the earthwork must vanish, or the
        // processional way climbs a bank that was never there.
        let axis = Monument.axisAzimuth.degrees * Double.pi / 180
        for state in [Monument.State.asItWas, .asItStands] {
            for radius in stride(from: 42.0, through: 62.0, by: 1.0) {
                let east = radius * sin(axis)
                let south = -radius * cos(axis)
                XCTAssertEqual(Earthwork.heightDelta(east: east, south: south,
                                                     state: state),
                               0, accuracy: 0.01,
                               "earthwork at r=\(radius) blocks the entrance")
                XCTAssertEqual(Earthwork.wear(east: east, south: south,
                                              state: state),
                               0, accuracy: 0.05)
            }
        }
    }

    func testTheSouthernCausewayExists() {
        let azimuth = 165.0 * Double.pi / 180
        let east = Earthwork.ditchCentre * sin(azimuth)
        let south = -Earthwork.ditchCentre * cos(azimuth)
        XCTAssertEqual(Earthwork.heightDelta(east: east, south: south,
                                             state: .asItStands),
                       0, accuracy: 0.01)
    }

    // ── the surface ─────────────────────────────────────────────────────────

    func testWearStaysNormalisedAndFollowsTheState() {
        var maxToday = 0.0, maxFresh = 0.0
        for azimuth in stride(from: 0.0, to: 360.0, by: 7.0) {
            for radius in stride(from: 40.0, to: 64.0, by: 0.5) {
                let a = azimuth * Double.pi / 180
                let east = radius * sin(a), south = -radius * cos(a)
                for state in [Monument.State.asItWas, .asItStands] {
                    let wear = Earthwork.wear(east: east, south: south,
                                              state: state)
                    XCTAssertTrue(wear >= 0 && wear <= 1)
                    if state == .asItWas { maxFresh = max(maxFresh, wear) }
                    else { maxToday = max(maxToday, wear) }
                }
            }
        }
        XCTAssertGreaterThan(maxFresh, 0.8, "a new bank is bare chalk")
        XCTAssertLessThan(maxToday, 0.5, "today's ring is grassed over, "
                          + "reading pale rather than bare")
    }

    // ── the mesh ────────────────────────────────────────────────────────────

    func testTheRingMeshIsSoundGeometry() {
        let mesh = Earthwork.build(state: .asItStands) { _, _ in 0 }
        XCTAssertFalse(mesh.positions.isEmpty)
        XCTAssertEqual(mesh.positions.count, mesh.blends.count)
        XCTAssertEqual(mesh.indices.count % 3, 0)
        for position in mesh.positions {
            let radius = (position.x * position.x + position.z * position.z)
                .squareRoot()
            XCTAssertTrue((39...65).contains(radius),
                          "ring vertex strayed to r=\(radius)")
            XCTAssertFalse(position.y.isNaN)
        }
        for blend in mesh.blends {
            XCTAssertTrue((0...1).contains(blend))
        }
        for index in mesh.indices {
            XCTAssertLessThan(Int(index), mesh.positions.count)
        }
    }
}
