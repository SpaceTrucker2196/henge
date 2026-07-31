import Foundation
import simd
import HengeAstro

/// The enclosure earthwork — the ditch and bank that give a henge its name,
/// though Stonehenge wears them backwards: the main bank stands *inside*
/// the ditch, with a slighter counterscarp bank outside, an arrangement
/// unusual enough that by the strict typology Stonehenge is not a henge.
///
/// **Provenance (invariant 3, established):** Cleal, Walker & Montague,
/// *Stonehenge in its Landscape* (English Heritage Archaeological Report
/// 10, 1995). Enclosure about 110 m across; ditch roughly 5–6 m wide and
/// 1.4–2.1 m deep as dug (c. 2900 BC), now silted to a hollow of half a
/// metre or so; internal bank about 6 m wide, perhaps 2 m of fresh chalk
/// when new, now under half a metre of grassed swell; low counterscarp
/// outside the ditch. Two causeways interrupt the circuit: the main
/// north-eastern entrance on the monument's axis, where the Avenue meets
/// it, and a smaller gap on the south.
///
/// Everything here is an analytic profile — smooth radial bumps gated by
/// azimuth windows — so a test can hold the causeway level and the bank
/// inside the ditch without rendering a pixel.
public enum Earthwork {

    // ── the circuit, in metres from the monument's centre ───────────────────

    /// Inner bank: crest radius and half-width.
    static let bankCrest = 47.5
    static let bankHalfWidth = 3.6
    /// Ditch: centreline and half-width.
    public static let ditchCentre = 54.2
    static let ditchHalfWidth = 3.5
    /// Counterscarp bank, low and outside.
    static let counterscarpCrest = 59.2
    static let counterscarpHalfWidth = 2.2

    /// Where the ring begins and ends mattering at all — used by the mesh
    /// to bound its annulus and by the ground grid to carve its hole.
    public static let innerRadius = 40.0
    public static let outerRadius = 64.0

    /// Heights, by state. As dug, the ditch went through turf into solid
    /// chalk and the bank stood bright white beside it; four and a half
    /// millennia of silt and sward leave the gentle swellings the aerial
    /// photographs show.
    static func amplitudes(for state: Monument.State)
        -> (bank: Double, ditch: Double, counterscarp: Double) {
        switch state {
        case .asItWas: (1.9, -1.9, 0.55)
        case .asItStands: (0.42, -0.5, 0.16)
        }
    }

    /// The two causeways, as azimuth windows (degrees from north, half-width
    /// and feather). The main entrance sits on the monument's axis; the
    /// southern gap is narrower.
    static var causeways: [(centre: Double, half: Double, feather: Double)] {
        [(Monument.axisAzimuth.degrees, 8.0, 4.0),
         (165.0, 3.0, 2.5)]
    }

    // ── the profile ─────────────────────────────────────────────────────────

    /// A raised-cosine bump: 1 at the centre, 0 beyond the half-width.
    private static func bump(_ radius: Double, centre: Double,
                             halfWidth: Double) -> Double {
        let t = abs(radius - centre) / halfWidth
        guard t < 1 else { return 0 }
        let c = cos(t * .pi / 2)
        return c * c
    }

    /// How much of the circuit is present at this azimuth: 1 on the ring,
    /// falling smoothly to 0 through each causeway.
    static func circuit(atAzimuth degrees: Double) -> Double {
        var presence = 1.0
        for causeway in causeways {
            var separation = abs(degrees - causeway.centre)
                .truncatingRemainder(dividingBy: 360)
            if separation > 180 { separation = 360 - separation }
            let t = (separation - causeway.half) / causeway.feather
            presence *= min(1, max(0, t))
        }
        return presence
    }

    /// Height of the earthwork above (or below) the natural grade.
    public static func heightDelta(east: Double, south: Double,
                                   state: Monument.State) -> Double {
        let radius = (east * east + south * south).squareRoot()
        guard radius > innerRadius, radius < outerRadius else { return 0 }
        let a = amplitudes(for: state)
        let profile = a.bank * bump(radius, centre: bankCrest,
                                    halfWidth: bankHalfWidth)
            + a.ditch * bump(radius, centre: ditchCentre,
                             halfWidth: ditchHalfWidth)
            + a.counterscarp * bump(radius, centre: counterscarpCrest,
                                    halfWidth: counterscarpHalfWidth)
        return profile * circuit(atAzimuth: azimuth(east: east, south: south))
    }

    /// How worn the ground is here, 0 turf to 1 bare: fresh chalk on a new
    /// bank and ditch, a thin pale sward on today's — the pale ring the
    /// aerial photographs show.
    public static func wear(east: Double, south: Double,
                            state: Monument.State) -> Double {
        let radius = (east * east + south * south).squareRoot()
        guard radius > innerRadius, radius < outerRadius else { return 0 }
        let band = bump(radius, centre: bankCrest, halfWidth: bankHalfWidth)
            + bump(radius, centre: ditchCentre, halfWidth: ditchHalfWidth)
        let strength = switch state {
        case .asItWas: 0.95
        case .asItStands: 0.38
        }
        return min(1, band * strength)
            * circuit(atAzimuth: azimuth(east: east, south: south))
    }

    static func azimuth(east: Double, south: Double) -> Double {
        let degrees = atan2(east, -south) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    // ── the mesh ────────────────────────────────────────────────────────────

    /// Does this ground-grid cell sit wholly under the annulus? The base
    /// terrain carves these out: a dug ditch cannot be an overlay on an
    /// opaque plain, because the plain would occlude the hollow.
    public static func swallows(east: Double, south: Double) -> Bool {
        let radius = (east * east + south * south).squareRoot()
        return radius > innerRadius + 4 && radius < outerRadius - 4
    }

    /// The earthwork as its own fine polar mesh, riding the natural grade.
    /// The base terrain grid runs about ten metres a vertex out here — far
    /// too coarse for a six-metre ditch — so the ring gets the resolution
    /// the base cannot afford everywhere. The rim bands (where the profile
    /// is zero) float a centimetre proud of the base so the two surfaces
    /// never fight in the depth buffer.
    public static func build(state: Monument.State,
                             groundHeight: (Double, Double) -> Double) -> Mesh {
        let radialSteps = 44
        let azimuthSteps = 320
        var mesh = Mesh()

        func surface(_ radius: Double, _ azimuthDegrees: Double)
            -> (position: SIMD3<Float>, wear: Double) {
            let a = azimuthDegrees * .pi / 180
            let east = radius * sin(a)
            let south = -radius * cos(a)
            let lift = 0.012
            let y = groundHeight(east, south)
                + heightDelta(east: east, south: south, state: state)
                + lift
            return (SIMD3(Float(east), Float(y), Float(south)),
                    wear(east: east, south: south, state: state))
        }

        for r in 0...radialSteps {
            let radius = innerRadius
                + (outerRadius - innerRadius) * Double(r) / Double(radialSteps)
            for a in 0..<azimuthSteps {
                let degrees = 360.0 * Double(a) / Double(azimuthSteps)
                let here = surface(radius, degrees)
                mesh.positions.append(here.position)
                mesh.blends.append(Float(1 - here.wear))
                // Normal from finite differences of the composite surface.
                let dr = surface(radius + 0.4, degrees).position
                    - surface(radius - 0.4, degrees).position
                let da = surface(radius, degrees + 0.25).position
                    - surface(radius, degrees - 0.25).position
                var normal = cross(da, dr)
                let length = length(normal)
                normal = length > 1e-9 ? normal / length : SIMD3(0, 1, 0)
                mesh.normals.append(normal.y < 0 ? -normal : normal)
            }
        }

        for r in 0..<radialSteps {
            for a in 0..<azimuthSteps {
                let next = (a + 1) % azimuthSteps
                let i0 = UInt32(r * azimuthSteps + a)
                let i1 = UInt32(r * azimuthSteps + next)
                let i2 = UInt32((r + 1) * azimuthSteps + next)
                let i3 = UInt32((r + 1) * azimuthSteps + a)
                // Both windings, deliberately: a polar sheet's orientation
                // flips against the grid convention depending on sector,
                // and a culled sector reads as a hole straight through the
                // planet. The normals point up regardless; twenty-six
                // thousand extra triangles are cheaper than one wrong cull.
                mesh.indices.append(contentsOf: [i0, i2, i1, i0, i3, i2])
                mesh.indices.append(contentsOf: [i0, i1, i2, i0, i2, i3])
            }
        }
        return mesh
    }
}
