import XCTest
@testable import HengeAstro

/// The haze curve is what decides when the light shafts exist. The fixtures
/// are independent arithmetic a reader can redo: a Hermite smoothstep passes
/// exactly through ½ at the midpoint of its ramp, and is 0 and 1 at the ends.
final class HazeTests: XCTestCase {

    private func boost(_ degrees: Double) -> Double {
        Haze.twilightBoost(sunAltitude: Angle(degrees: degrees))
    }

    func testHighSunHasNoExtraHaze() {
        XCTAssertEqual(boost(90), 0)
        XCTAssertEqual(boost(45), 0)
        XCTAssertEqual(boost(18), 0)
    }

    func testGoldenHourRampPassesThroughItsMidpoint() {
        // The ramp runs 18° → 3°, so its midpoint is 10.5° and smoothstep
        // gives exactly one half there.
        XCTAssertEqual(boost(10.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(boost(3), 1, accuracy: 1e-12)
    }

    func testTheDiscOnTheHorizonGetsFullBeams() {
        XCTAssertEqual(boost(2), 1)
        XCTAssertEqual(boost(1.5), 1)
        XCTAssertEqual(boost(1.2), 1)
    }

    func testBeamsAreGoneBeforeTheCascadeGate() {
        // The set ramp runs 1.2° → 0.2°; midpoint 0.7°.
        XCTAssertEqual(boost(0.7), 0.5, accuracy: 1e-12)
        XCTAssertEqual(boost(0.2), 0)
        // The renderer stops fitting sun cascades — and may hand the shadow
        // map to the moon — at ~0.011° apparent altitude. The curve must be
        // hard zero at and below that line, or the beams march against
        // identity matrices or the wrong light's shadows. 0.011° is the
        // renderer's threshold restated here, not a derived value: if it
        // moves there, this fixture is the alarm.
        XCTAssertEqual(boost(0.012), 0)
        XCTAssertEqual(boost(0), 0)
        XCTAssertEqual(boost(-6), 0, "no sun, no beams")
    }

    func testTheCurveIsMonotoneOnEachRamp() {
        var previous = boost(18)
        for tenth in stride(from: 17.9, through: 3.0, by: -0.1) {
            let value = boost(tenth)
            XCTAssertGreaterThanOrEqual(value, previous,
                                        "rising ramp dipped at \(tenth)°")
            previous = value
        }
        previous = boost(1.2)
        for tenth in stride(from: 1.1, through: 0.1, by: -0.1) {
            let value = boost(tenth)
            XCTAssertLessThanOrEqual(value, previous,
                                     "setting ramp rose at \(tenth)°")
            previous = value
        }
    }

    func testTheCurveStaysInRange() {
        for degrees in stride(from: -10.0, through: 90.0, by: 0.25) {
            let value = boost(degrees)
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
        }
    }
}
