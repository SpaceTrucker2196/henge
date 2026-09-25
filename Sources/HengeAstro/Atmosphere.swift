import Foundation

/// How much of the sun's light gets through the air, as a function of how
/// low the sun stands and how hazy the day is.
///
/// This replaces a hand-tuned "reddening and dimming" curve in the renderer
/// with three published pieces of physics, so that the sun the stones are
/// lit by at the midsummer sunrise — the minutes the whole app is measured
/// against — is a computed quantity rather than a taste. Everything here is
/// Foundation-only arithmetic that a test can hold to a table.
///
/// The model is Rayleigh scattering plus aerosol extinction, per channel,
/// along a path of `airMass` atmospheres. Ozone, water vapour and the
/// molecular absorption bands are left out: at the three wavelengths used
/// they are a few per cent at most, and modelling them would add data
/// tables without moving anything a viewer could see.
public enum Atmosphere {

    /// Relative optical air mass for a sun at an apparent altitude —
    /// Kasten & Young, "Revised optical air mass tables and approximation
    /// formula", Applied Optics 28 (1989):
    ///
    ///     m = 1 / (sin h + 0.50572 · (h° + 6.07995)^−1.6364)
    ///
    /// One atmosphere at the zenith, about 38 with the sun on the horizon.
    /// Takes the *apparent* (refracted) altitude, which is what the formula
    /// was fitted against and what the renderer's sun already carries.
    public static func airMass(apparentAltitude h: Angle) -> Double {
        let degrees = max(h.degrees, 0)
        return 1 / (sin(max(h.radians, 0)) + 0.50572 * pow(degrees + 6.07995, -1.6364))
    }

    /// Rayleigh optical depth of one atmosphere at sea level, at a
    /// wavelength in micrometres — Bucholtz, "Rayleigh-scattering
    /// calculations for the terrestrial atmosphere", Applied Optics 34
    /// (1995), in the four-term form:
    ///
    ///     τ_R = 0.008569 · λ⁻⁴ · (1 + 0.0113 λ⁻² + 0.00013 λ⁻⁴)
    ///
    /// The λ⁻⁴ is why the sky is blue and the low sun red; the correction
    /// terms are the dispersion of air's refractive index.
    public static func rayleighOpticalDepth(wavelengthMicrons λ: Double) -> Double {
        let λ2 = 1 / (λ * λ)
        let λ4 = λ2 * λ2
        return 0.008569 * λ4 * (1 + 0.0113 * λ2 + 0.00013 * λ4)
    }

    /// Aerosol optical depth by Ångström's law, `β · λ^−α`, with the
    /// exponent 1.3 of a continental aerosol and the turbidity coefficient
    /// β tied to Preetham's turbidity by his own relation,
    /// β = 0.04608 · T − 0.04586 (Preetham, Shirley & Smits 1999, §A.2).
    /// One turbidity therefore drives both the sky's colour and the sun's,
    /// and there is no second haze knob to fall out of step with the first.
    public static func aerosolOpticalDepth(turbidity: Double,
                                           wavelengthMicrons λ: Double) -> Double {
        let β = max(0.04608 * turbidity - 0.04586, 0)
        return β * pow(λ, -1.3)
    }

    /// The dominant wavelengths of the sRGB primaries, in micrometres —
    /// the three points at which the spectrum is sampled for a red, green
    /// and blue transmittance. Red 610 nm, green 550 nm, blue 465 nm.
    public static let channelWavelengths = SIMD3<Double>(0.610, 0.550, 0.465)

    /// Fraction of the sun's light reaching the ground in each of red,
    /// green and blue, for a sun at an apparent altitude under a given
    /// turbidity: `exp(−m · (τ_R + τ_A))` per channel.
    ///
    /// At the zenith on a clear day about (0.83, 0.79, 0.69) — a noon sun
    /// slightly warmer than it left space. On the horizon the red is a
    /// thousand times the blue, which is the whole of the sunrise.
    public static func transmittance(apparentAltitude h: Angle,
                                     turbidity: Double) -> SIMD3<Double> {
        let m = airMass(apparentAltitude: h)
        var result = SIMD3<Double>()
        for channel in 0..<3 {
            let λ = channelWavelengths[channel]
            let depth = rayleighOpticalDepth(wavelengthMicrons: λ)
                      + aerosolOpticalDepth(turbidity: turbidity, wavelengthMicrons: λ)
            result[channel] = exp(-m * depth)
        }
        return result
    }

    /// Illuminance of the sun above the atmosphere, in kilolux: the solar
    /// constant of 1361 W/m² (Kopp & Lean 2011) at the 98 lm/W luminous
    /// efficacy of the extraterrestrial solar spectrum. Ground-level noon
    /// sunlight is this times the transmittance — about 105 klux, the
    /// familiar "bright sun" figure.
    public static let solarIlluminanceAboveAtmosphere: Double = 133
}
