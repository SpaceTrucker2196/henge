import Foundation

/// Atmospheric haze, as a function of where the sun is.
///
/// The renderer draws crepuscular beams — light shafts through the stones —
/// by marching each view ray through a thin ground haze and asking the shadow
/// cascades, at every step, whether the sun can see that piece of air. The
/// *decision* of how much haze an hour deserves is made here, in plain
/// arithmetic, rather than in the shader: a curve in MSL is a curve no test
/// can reach, and this one shapes the most-photographed minutes of the day.
///
/// The physical claim is modest and worth stating. Low sun really does read
/// through more atmosphere (the beams exist because forward scattering peaks
/// when you look toward the light), and radiation mist really does form in
/// the first metres above a chalk plain at dawn. But the *amount* drawn here
/// is an artistic choice tuned for legibility, not a transmittance model —
/// the honest label is "weather dressing", and it makes no archaeological
/// claim at all.
public enum Haze {

    /// How much extra haze the hour deserves: 0 at a clear noon, 1 through
    /// the golden hour, back to 0 once the disc has set.
    ///
    /// Piecewise, with Hermite ramps so the fade is invisible in a time-lapse:
    ///
    /// - 18° and above: 0. High sun, clear air.
    /// - 18° down to 3°: rises 0 → 1. The golden hour approaches.
    /// - 3° down to 0.5°: 1. Full beams while the disc stands on the horizon.
    /// - 0.5° down to −1.5°: falls 1 → 0. The disc is gone; beams need a sun
    ///   to cast them. (The moon-lit night fits its cascades to the moon, and
    ///   sun beams from a sun below the horizon would be sampling the wrong
    ///   light's shadow map — the curve reaching zero before the handover is
    ///   what keeps those two regimes from ever overlapping.)
    ///
    /// `sunAltitude` is the *apparent* (refracted) altitude, the same one the
    /// sky is drawn with.
    public static func twilightBoost(sunAltitude: Angle) -> Double {
        let a = sunAltitude.degrees
        if a >= 18 { return 0 }
        if a >= 3 { return smoothstep((18 - a) / 15) }
        if a >= 0.5 { return 1 }
        if a >= -1.5 { return smoothstep((a + 1.5) / 2) }
        return 0
    }

    /// The standard Hermite fade: 0 at 0, 1 at 1, flat at both ends.
    private static func smoothstep(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }
}
