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
    /// - 3° down to 1.2°: 1. Full beams while the disc stands on the horizon.
    /// - 1.2° down to 0.2°: falls 1 → 0, and 0.2° is a *contract*, not taste.
    ///   The renderer fits its shadow cascades only while the sun stands
    ///   above ~0.011° apparent altitude, and hands the shadow map to the
    ///   moon at the same threshold when a bright moon is up. Beams marched
    ///   below that line would sample identity matrices or the wrong light's
    ///   shadows — so this curve must be exactly zero before the sun reaches
    ///   it, with margin. The first version faded to −1.5° instead, and the
    ///   review caught both consequences: an unshadowed golden veil in the
    ///   window below 0.011°, and a one-frame pop at the moon handover on
    ///   every bright-moon evening.
    ///
    /// `sunAltitude` is the *apparent* (refracted) altitude, the same one the
    /// sky is drawn with.
    public static func twilightBoost(sunAltitude: Angle) -> Double {
        let a = sunAltitude.degrees
        if a >= 18 { return 0 }
        if a >= 3 { return smoothstep((18 - a) / 15) }
        if a >= 1.2 { return 1 }
        if a >= 0.2 { return smoothstep((a - 0.2) / 1.0) }
        return 0
    }

    /// The standard Hermite fade: 0 at 0, 1 at 1, flat at both ends.
    private static func smoothstep(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }
}
