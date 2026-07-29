import Foundation
import simd
import HengeAstro

/// The colour of a night, and the colour of a season.
///
/// Both are palettes rather than formulae because both are perceptual. The
/// physics of moonlight is settled — it is sunlight, reflected, about 400,000
/// times fainter at full — but what a person *sees* at night is the result of
/// dark adaptation and the Purkinje shift, and no radiometric quantity
/// describes that. So: two authored end points and an interpolation, with the
/// astronomy deciding where between them we are.
public enum NightPalette {

    /// A night lit by a full moon.
    ///
    /// Silver-blue, and brighter than people expect: a full moon at zenith
    /// gives about 0.25 lux, enough to read a headline by and enough to cast a
    /// shadow with a visible edge. The blue is not in the light — moonlight is
    /// very slightly *warmer* than sunlight — it is the Purkinje shift, the eye
    /// handing over from cones to rods and becoming more sensitive to blue as
    /// it does. Painting it neutral is physically right and looks wrong.
    ///
    /// Rebalanced when the moon's directional term grew teeth: this ambient
    /// is now the moonlit *sky's* glow alone — the stones themselves are
    /// modelled by the shadowed moonlight, which is what lets a full moon
    /// cast the shadow you can watch at the real monument.
    public static let full = SIMD4<Float>(0.020, 0.028, 0.052, 0.030)

    /// A night with no moon at all.
    ///
    /// Not black. Airglow, zodiacal light, integrated starlight and the faint
    /// scatter of everything else give roughly 0.002 lux — a thousandth of the
    /// full moon, but the dark-adapted eye covers that range easily, and on a
    /// clear night on Salisbury Plain you can walk without a torch and see the
    /// stones against the sky.
    ///
    /// The `w` component is the floor: the least light any surface receives, so
    /// that **the darkest night is still just legible**. Without it the app
    /// would be technically correct and, for several hours a month, a black
    /// rectangle.
    ///
    /// The colour is starlight's: pale and *whitish*-blue, not the deep blue
    /// of the sky it falls from. Integrated starlight averages warm-white —
    /// most bright stars are hotter than the sun — and the Purkinje shift
    /// cools it at the eye; the earlier value leaned as blue as the zenith
    /// and the ground read dyed rather than dim.
    public static let new = SIMD4<Float>(0.0135, 0.0150, 0.0185, 0.0080)

    /// Where this night sits between the two.
    ///
    /// Driven by illuminated fraction rather than by phase angle, and raised to
    /// a power well under one: the moon's *light* is far from linear in its
    /// illuminated area — a half moon gives under a tenth of a full moon's
    /// light, not a half, because at full the surface is lit head-on with no
    /// shadows between the regolith grains to swallow it. The exponent is the
    /// honest shape of that curve rather than the opposition surge itself.
    public static func blend(illuminatedFraction: Double, moonAltitude: Angle) -> Float {
        guard moonAltitude.degrees > -0.5 else { return 0 }
        // Below about 10° the moon is dimmed by airmass and lights very little.
        let horizonFade = Float(min(max((moonAltitude.degrees + 0.5) / 10.5, 0), 1))
        let lit = Float(max(illuminatedFraction, 0))
        return pow(lit, 2.2) * horizonFade
    }

    /// Ambient night colour for a moment, and the visibility floor in `w`.
    public static func colour(illuminatedFraction: Double,
                              moonAltitude: Angle) -> SIMD4<Float> {
        let t = blend(illuminatedFraction: illuminatedFraction, moonAltitude: moonAltitude)
        return new + (full - new) * t
    }
}

/// What the ground and the vegetation look like at this point in the year.
///
/// Chalk grassland is not one colour for twelve months. It comes green and wet
/// out of winter, flowers and then bleaches through a dry summer, goes tawny
/// and seed-headed in autumn, and sits grey-green and short through the cold.
/// This app can be scrubbed across five millennia and it should not be spring
/// in every one of them.
///
/// Keyed to solar longitude rather than to calendar month, for the same reason
/// everything else here is: in 2500 BC the June solstice falls in July, and a
/// palette indexed by month would put high summer in the wrong season.
public enum SeasonPalette {

    /// rgb multiplies the vegetation's colour; w is dryness, 0 lush to 1 parched,
    /// which the shader uses to bleach the sward and let more chalk through.
    public struct Colour: Sendable {
        public var tint: SIMD3<Float>
        public var dryness: Float
    }

    /// The four corners of the year, at their solar longitudes.
    ///
    /// Spring at the March equinox, high summer around the solstice, autumn at
    /// the September equinox, winter at midwinter.
    static let corners: [(longitude: Double, colour: Colour)] = [
        (0,   Colour(tint: SIMD3(0.92, 1.14, 0.78), dryness: 0.05)),   // spring: new growth
        (90,  Colour(tint: SIMD3(1.06, 1.06, 0.72), dryness: 0.35)),   // midsummer: starting to bleach
        (180, Colour(tint: SIMD3(1.14, 0.96, 0.62), dryness: 0.75)),   // autumn: tawny, seed heads
        (270, Colour(tint: SIMD3(0.78, 0.86, 0.74), dryness: 0.20))    // midwinter: grey-green, short
    ]

    /// Interpolate around the year. Circular, so December blends into March
    /// rather than snapping.
    public static func colour(atSolarLongitude longitude: Angle) -> Colour {
        let degrees = longitude.normalized.degrees
        let index = Int(degrees / 90) % 4
        let next = (index + 1) % 4
        let t = Float((degrees - Double(index) * 90) / 90)
        // Smoothstep rather than linear: seasons do not change at a constant
        // rate, and a linear blend puts a visible crease at each corner when
        // the year is run at speed.
        let eased = t * t * (3 - 2 * t)

        let a = corners[index].colour, b = corners[next].colour
        return Colour(tint: a.tint + (b.tint - a.tint) * eased,
                      dryness: a.dryness + (b.dryness - a.dryness) * eased)
    }
}
