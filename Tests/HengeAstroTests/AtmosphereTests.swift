import XCTest
@testable import HengeAstro

/// The sun's transmittance is three published formulae; each is held to a
/// number from its own paper, so a slip in a coefficient shows up as a
/// table mismatch rather than as a sunrise that is subtly the wrong red.
final class AtmosphereTests: XCTestCase {

    private func airMass(_ degrees: Double) -> Double {
        Atmosphere.airMass(apparentAltitude: Angle(degrees: degrees))
    }

    /// Kasten & Young 1989, Table — their formula reproduces the tabulated
    /// relative optical air mass: 1.000 at the zenith, 1.994 at 30°, 5.60 at
    /// 10°, and 37.92 with the sun on the horizon.
    func testAirMassMatchesKastenAndYoungsTable() {
        XCTAssertEqual(airMass(90), 1.000, accuracy: 0.001)
        XCTAssertEqual(airMass(30), 1.994, accuracy: 0.005)
        XCTAssertEqual(airMass(10), 5.60, accuracy: 0.02)
        XCTAssertEqual(airMass(0), 37.92, accuracy: 0.05)
    }

    /// Below the horizon the path is the horizon's; the formula must not run
    /// off into negative degrees and a complex power.
    func testAirMassBelowTheHorizonIsTheHorizons() {
        XCTAssertEqual(airMass(-2), airMass(0), accuracy: 1e-9)
    }

    /// Bodhaine, Wood, Dutton & Slusser 1999 give the sea-level Rayleigh
    /// optical depth at 550 nm as 0.0973 (their Table 4, standard
    /// atmosphere); Bucholtz's four-term form lands within a thousandth.
    func testRayleighDepthAt550nmMatchesBodhaine() {
        XCTAssertEqual(Atmosphere.rayleighOpticalDepth(wavelengthMicrons: 0.55),
                       0.0973, accuracy: 0.001)
    }

    /// Rayleigh goes as λ⁻⁴: halving the wavelength from 0.8 to 0.4 µm
    /// multiplies the depth by sixteen times the ratio of the dispersion
    /// corrections, (1 + 0.0113·6.25 + 0.00013·39.06) / (1 + 0.0113·1.5625
    /// + 0.00013·2.441) = 1.0757 / 1.0180, so 16.91 by hand.
    func testRayleighDepthScalesAsTheInverseFourthPower() {
        let long = Atmosphere.rayleighOpticalDepth(wavelengthMicrons: 0.8)
        let short = Atmosphere.rayleighOpticalDepth(wavelengthMicrons: 0.4)
        XCTAssertEqual(short / long, 16.91, accuracy: 0.02)
    }

    /// Preetham's relation at the renderer's default turbidity 2.4:
    /// β = 0.04608 · 2.4 − 0.04586 = 0.06473, so τ_A(550 nm) =
    /// 0.06473 · 0.55^−1.3 = 0.1408 by hand.
    func testAerosolDepthFollowsAngstromWithPreethamsBeta() {
        XCTAssertEqual(Atmosphere.aerosolOpticalDepth(turbidity: 2.4, wavelengthMicrons: 0.55),
                       0.1408, accuracy: 0.001)
        // Turbidity 1 is Preetham's pure molecular atmosphere: no aerosol.
        XCTAssertEqual(Atmosphere.aerosolOpticalDepth(turbidity: 1, wavelengthMicrons: 0.55),
                       0, accuracy: 0.001)
    }

    /// Zenith transmittance by hand at turbidity 2.4: per channel
    /// τ = τ_R + τ_A = (0.0638 + 0.1230, 0.0973 + 0.1408, 0.1934 + 0.1751),
    /// so exp(−τ) = (0.830, 0.788, 0.692).
    func testZenithTransmittanceByHand() {
        let t = Atmosphere.transmittance(apparentAltitude: Angle(degrees: 90), turbidity: 2.4)
        XCTAssertEqual(t.x, 0.830, accuracy: 0.005)
        XCTAssertEqual(t.y, 0.788, accuracy: 0.005)
        XCTAssertEqual(t.z, 0.692, accuracy: 0.005)
    }

    /// On the horizon the path is 38 atmospheres long and the blue is gone:
    /// red over blue is in the hundreds, and every channel is monotone in
    /// altitude on the way there.
    func testTheHorizonSunIsRedAndTheDescentIsMonotone() {
        let horizon = Atmosphere.transmittance(apparentAltitude: .zero, turbidity: 2.4)
        XCTAssertGreaterThan(horizon.x / horizon.z, 20)
        var previous = Atmosphere.transmittance(apparentAltitude: Angle(degrees: 90), turbidity: 2.4)
        for degrees in stride(from: 85.0, through: 0, by: -5) {
            let t = Atmosphere.transmittance(apparentAltitude: Angle(degrees: degrees), turbidity: 2.4)
            for channel in 0..<3 {
                XCTAssertLessThan(t[channel], previous[channel], "at \(degrees)°, channel \(channel)")
            }
            previous = t
        }
    }

    /// Hazier air dims the sun at every altitude.
    func testMoreTurbidityMeansLessSun() {
        let clear = Atmosphere.transmittance(apparentAltitude: Angle(degrees: 45), turbidity: 2)
        let hazy = Atmosphere.transmittance(apparentAltitude: Angle(degrees: 45), turbidity: 6)
        for channel in 0..<3 {
            XCTAssertLessThan(hazy[channel], clear[channel])
        }
    }
}
