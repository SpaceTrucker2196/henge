import Foundation

/// The twelve zodiac constellations, as places in the sky.
///
/// **Constellations, not signs** — the distinction matters in an app about
/// precession. The astrological signs are twelve equal 30° slices measured
/// from the moving equinox; the constellations are the actual star patterns,
/// and the two have drifted a full sign apart since the Babylonians bound
/// them together. What belongs on the *sky* is the constellations, riding
/// with their stars: their centres precess through `StarField` exactly as
/// Aldebaran does.
///
/// Positions are the approximate centroids of the IAU constellation
/// boundaries (Delporte 1930, as digitised in Roman 1987, VizieR VI/42),
/// J2000, quoted to the tenth of a degree — a label's worth of precision
/// for regions that span tens of degrees.
public struct ZodiacConstellation: Sendable, Hashable, Identifiable {

    public let name: String
    /// The traditional glyph, worn since the medieval manuscripts.
    public let symbol: String
    /// Centroid of the IAU boundary, J2000.
    public let rightAscension: Angle
    public let declination: Angle

    public var id: String { name }

    public static let all: [ZodiacConstellation] = [
        ZodiacConstellation(name: "Aries", symbol: "♈",
                            rightAscension: Angle(degrees: 39.7),
                            declination: Angle(degrees: 20.8)),
        ZodiacConstellation(name: "Taurus", symbol: "♉",
                            rightAscension: Angle(degrees: 70.6),
                            declination: Angle(degrees: 15.9)),
        ZodiacConstellation(name: "Gemini", symbol: "♊",
                            rightAscension: Angle(degrees: 106.1),
                            declination: Angle(degrees: 22.6)),
        ZodiacConstellation(name: "Cancer", symbol: "♋",
                            rightAscension: Angle(degrees: 129.8),
                            declination: Angle(degrees: 19.8)),
        ZodiacConstellation(name: "Leo", symbol: "♌",
                            rightAscension: Angle(degrees: 159.9),
                            declination: Angle(degrees: 13.1)),
        ZodiacConstellation(name: "Virgo", symbol: "♍",
                            rightAscension: Angle(degrees: 200.9),
                            declination: Angle(degrees: -4.2)),
        ZodiacConstellation(name: "Libra", symbol: "♎",
                            rightAscension: Angle(degrees: 228.1),
                            declination: Angle(degrees: -15.2)),
        ZodiacConstellation(name: "Scorpius", symbol: "♏",
                            rightAscension: Angle(degrees: 253.2),
                            declination: Angle(degrees: -27.0)),
        ZodiacConstellation(name: "Sagittarius", symbol: "♐",
                            rightAscension: Angle(degrees: 286.5),
                            declination: Angle(degrees: -28.5)),
        ZodiacConstellation(name: "Capricornus", symbol: "♑",
                            rightAscension: Angle(degrees: 315.4),
                            declination: Angle(degrees: -18.0)),
        ZodiacConstellation(name: "Aquarius", symbol: "♒",
                            rightAscension: Angle(degrees: 334.3),
                            declination: Angle(degrees: -10.8)),
        ZodiacConstellation(name: "Pisces", symbol: "♓",
                            rightAscension: Angle(degrees: 7.4),
                            declination: Angle(degrees: 13.7))
    ]
}
