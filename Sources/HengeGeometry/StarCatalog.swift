import Foundation
import HengeAstro

/// The naked-eye sky, from the Hipparcos catalogue.
///
/// **Provenance (invariant 5):** ESA, 1997, *The Hipparcos and Tycho
/// Catalogues*, ESA SP-1200 — free with attribution, which this header and
/// `SECURITY.md` provide. The bundled file is `hip_main.dat` (CDS I/239)
/// filtered to V ≤ 6.5 — the 8,870 stars a dark-adapted eye can see — with
/// each line carrying HIP identifier, ICRS position at epoch J1991.25,
/// V magnitude, B−V colour index, and the two proper-motion components.
///
/// The catalogue lives in `HengeGeometry` beside the terrain heightfield
/// because `HengeAstro` is a no-I/O module: the arithmetic that moves these
/// stars is there and provable without a file system, and the file is here
/// with the other bundled survey data.
public struct StarCatalog: Sendable {

    /// One catalogue star, as vendored.
    public struct Entry: Sendable, Hashable {
        public let hip: Int
        /// ICRS at epoch J1991.25.
        public let rightAscension: HengeAstro.Angle
        public let declination: HengeAstro.Angle
        public let magnitude: Double
        /// B−V colour index; 0 for the handful of entries without one.
        public let colourIndex: Double
        /// μα★ (already × cos δ) and μδ, mas/yr.
        public let pmRACosDec: Double
        public let pmDeclination: Double
    }

    /// A star ready for the sky of a particular date.
    public struct Instance: Sendable {
        /// Unit vector against the equator and equinox of that date.
        public let direction: SIMD3<Double>
        public let magnitude: Double
        /// Linear RGB, an artistic reading of the B−V index — a blackbody
        /// impression, not photometry, and labelled as such.
        public let colour: SIMD3<Float>
    }

    public let entries: [Entry]

    /// Load the bundled catalogue. Nil rather than a throw, and the renderer
    /// treats nil as "no stars tonight": the almanac must not die for want
    /// of decoration — same contract as the surface textures.
    public static func load() -> StarCatalog? {
        guard let url = Bundle.module.url(forResource: "hipparcos-bright",
                                          withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        var entries: [Entry] = []
        entries.reserveCapacity(9000)
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: ",")
            guard fields.count == 7,
                  let hip = Int(fields[0]),
                  let ra = Double(fields[1]),
                  let dec = Double(fields[2]),
                  let magnitude = Double(fields[3]),
                  let colourIndex = Double(fields[4]),
                  let pmRA = Double(fields[5]),
                  let pmDec = Double(fields[6]) else { continue }
            entries.append(Entry(hip: hip,
                                 rightAscension: Angle(degrees: ra),
                                 declination: Angle(degrees: dec),
                                 magnitude: magnitude,
                                 colourIndex: colourIndex,
                                 pmRACosDec: pmRA,
                                 pmDeclination: pmDec))
        }
        guard !entries.isEmpty else { return nil }
        return StarCatalog(entries: entries)
    }

    /// Every star, moved to a date: proper motion first, then precession —
    /// the sky the builders had, not tonight's with the labels changed.
    public func instances(at tt: JulianDay) -> [Instance] {
        entries.map { entry in
            let moved = StarField.properMotionApplied(
                rightAscension: entry.rightAscension,
                declination: entry.declination,
                pmRACosDec: entry.pmRACosDec,
                pmDeclination: entry.pmDeclination,
                at: tt)
            let dated = StarField.equatorialOfDate(
                rightAscension: moved.rightAscension,
                declination: moved.declination,
                at: tt)
            return Instance(direction: StarField.unitVector(
                                rightAscension: dated.rightAscension,
                                declination: dated.declination),
                            magnitude: entry.magnitude,
                            colour: Self.colour(forIndex: entry.colourIndex))
        }
    }

    /// B−V to a linear RGB impression: blue-white for the hot stars, solar
    /// white near 0.65, ember orange past 1.5. Piecewise between published
    /// anchor temperatures, but the palette itself is an artistic choice.
    static func colour(forIndex bv: Double) -> SIMD3<Float> {
        let anchors: [(index: Double, colour: SIMD3<Float>)] = [
            (-0.30, SIMD3(0.62, 0.72, 1.00)),
            (0.00, SIMD3(0.78, 0.85, 1.00)),
            (0.65, SIMD3(1.00, 0.96, 0.88)),
            (1.50, SIMD3(1.00, 0.62, 0.36))
        ]
        if bv <= anchors[0].index { return anchors[0].colour }
        for i in 1..<anchors.count where bv <= anchors[i].index {
            let a = anchors[i - 1], b = anchors[i]
            let t = Float((bv - a.index) / (b.index - a.index))
            return a.colour + (b.colour - a.colour) * t
        }
        return anchors[anchors.count - 1].colour
    }
}
