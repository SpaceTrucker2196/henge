import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The golden-hour light shafts, measured rather than admired.
///
/// The pass is a raymarch through haze that asks the shadow cascades whether
/// the sun can see each piece of air, so two things are checkable in pixels:
/// the haze glows toward a low sun, and a stone standing in the light carves
/// its shadow out of that glow — which is what a beam *is*, the lit remainder.
@MainActor
final class LightBeamTests: XCTestCase {

    static let size = 224

    private func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the light shafts are unverified here.")
        }
        return device
    }

    /// Render toward a western sun and return per-pixel *linear* luminance —
    /// radiance in the scene's units, before exposure and the tone curve.
    ///
    /// In bytes the beams cannot be measured where these tests look: the
    /// sky beside a setting sun sits on the tone curve's shoulder at 223 of
    /// 255, and there the pass's whole contribution is under one level.
    /// That is the curve doing its job, not the beams failing; the claims
    /// here are about light added, so they are made in linear light.
    private func frame(sunAltitude: Double, lightShafts: Bool,
                       stones: [Stone], camera: Camera) throws -> [Double] {
        let device = try makeDevice()
        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                                         azimuth: Angle(degrees: 270)),
                               camera: camera, turbidity: 2.4, exposure: 1.6,
                               grassBlades: false)
        state.lightShafts = lightShafts

        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 1024)
        try renderer.load(scene: MonumentScene(stones: stones))

        let texture = try renderer.renderOffscreenLinear(width: Self.size, height: Self.size)
        // rgba16Float: four half floats per pixel.
        var halves = [UInt16](repeating: 0, count: Self.size * Self.size * 4)
        halves.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 8,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                             mipmapLevel: 0)
        }
        var luminances = [Double](repeating: 0, count: Self.size * Self.size)
        for i in 0..<(Self.size * Self.size) {
            let r = Self.half(halves[i * 4]), g = Self.half(halves[i * 4 + 1])
            let b = Self.half(halves[i * 4 + 2])
            luminances[i] = 0.2126 * r + 0.7152 * g + 0.0722 * b
        }
        return luminances
    }

    /// IEEE 754 binary16 to Double, spelled out so the test does not depend
    /// on `Float16` being available on the host.
    static func half(_ bits: UInt16) -> Double {
        let sign = (bits & 0x8000) != 0 ? -1.0 : 1.0
        let exponent = Int((bits >> 10) & 0x1F)
        let fraction = Double(bits & 0x3FF)
        switch exponent {
        case 0: return sign * fraction * pow(2.0, -24)          // subnormal
        case 31: return fraction == 0 ? sign * .infinity : .nan
        default: return sign * (1 + fraction / 1024) * pow(2.0, Double(exponent - 15))
        }
    }

    private func mean(_ luminance: [Double], rows: Range<Int>, columns: Range<Int>) -> Double {
        var total = 0.0
        var count = 0
        for y in rows {
            for x in columns {
                total += luminance[y * Self.size + x]
                count += 1
            }
        }
        return total / Double(max(count, 1))
    }

    /// **The haze answers the hour.** At sunset the pass brightens the air
    /// toward the sun; at 30° — the shadow oracle's configuration — it must
    /// contribute exactly nothing, or it would be fog on the instrument.
    func testTheHazeGlowsAtSunsetAndNotAtMidMorning() throws {
        // Eye height on the empty plain, looking straight at a setting sun.
        let camera = Camera(position: SIMD3(0, 1.7, 0), target: SIMD3(-60, 3.2, 0),
                            fieldOfView: 55 * .pi / 180, near: 0.3, far: 3000)

        let sunsetOn = try frame(sunAltitude: 2, lightShafts: true, stones: [], camera: camera)
        let sunsetOff = try frame(sunAltitude: 2, lightShafts: false, stones: [], camera: camera)
        // The sky band above the horizon, full width: where the glow lives.
        let rows = (Self.size * 5 / 16)..<(Self.size * 7 / 16)
        let on = mean(sunsetOn, rows: rows, columns: 0..<Self.size)
        let off = mean(sunsetOff, rows: rows, columns: 0..<Self.size)
        // One per cent of the sky's own radiance. The arithmetic says more:
        // the march integrates sun × phase × (1 − e^−τ) with τ ≈ 0.4 × the
        // height fall-off, so about 0.27 of the sun's radiance, and toward
        // the sun the Henyey–Greenstein phase is ~1 — a sun of 0.12 against
        // a sky of 1.0 predicts three per cent, and 1.8 % is measured across
        // the whole band. (In bytes this used to read as "> 4 levels", which
        // was the tone curve's toe amplifying a small addition tenfold; the
        // curve now runs once, after the haze is composited in linear light.)
        XCTAssertGreaterThan(on - off, off * 0.01,
                             "sunset air gained only \(on - off) of its \(off) radiance "
                             + "from the light shafts — the golden hour is not glowing")

        let morningOn = try frame(sunAltitude: 30, lightShafts: true, stones: [], camera: camera)
        let morningOff = try frame(sunAltitude: 30, lightShafts: false, stones: [], camera: camera)
        XCTAssertEqual(zip(morningOn, morningOff).filter { $0 != $1 }.count, 0,
                       "at 30° the haze pass must not run at all — the shadow "
                       + "agreement oracle renders in this configuration")
    }

    /// **The beam comes through the gap.** A wall of two slabs with a gap
    /// between them, the camera looking straight down the gap at a setting
    /// sun. The air behind the gap is lit and glows; the air behind each slab
    /// stands in its shadow and must not. The measured quantity is the haze
    /// pass's own contribution — the same pixels rendered with the shafts on
    /// and off — so nothing here depends on how bright the slabs themselves
    /// are, only on what the pass added to the air in front of them.
    func testTheBeamComesThroughTheGapAndNotThroughTheStone() throws {
        // Level with the target so the horizon sits on the middle row and a
        // pixel row maps to elevation at about four pixels per degree.
        let camera = Camera(position: SIMD3(30, 2.5, 0), target: SIMD3(-60, 2.5, 0),
                            fieldOfView: 55 * .pi / 180, near: 0.3, far: 3000)
        // Two slabs either side of a three-metre gap on the camera's axis,
        // broad faces toward the camera, sun dead behind them.
        let wall = [
            Stone(id: "beam-north", position: SIMD3(0, 0, -3.5),
                  height: 6.5, width: 4, thickness: 1, bearing: Angle(degrees: 90)),
            Stone(id: "beam-south", position: SIMD3(0, 0, 3.5),
                  height: 6.5, width: 4, thickness: 1, bearing: Angle(degrees: 90))
        ]

        let on = try frame(sunAltitude: 2, lightShafts: true, stones: wall,
                           camera: camera)
        let off = try frame(sunAltitude: 2, lightShafts: false, stones: wall,
                            camera: camera)
        let delta = zip(on, off).map { $0 - $1 }

        // Rays 3°–7° above level: under the slab tops at the wall, over the
        // sun's disc. About four pixels per degree at this size and field.
        let centre = Self.size / 2
        let rows = (centre - 28)..<(centre - 12)
        // The gap subtends ±2.9° at thirty metres; the slabs 3°–10° each side.
        let gap = mean(delta, rows: rows, columns: (centre - 10)..<(centre + 10))
        let stoneSide = (mean(delta, rows: rows,
                              columns: (centre - 40)..<(centre - 16))
                       + mean(delta, rows: rows,
                              columns: (centre + 16)..<(centre + 40))) / 2

        // In linear light, as fractions of the sky seen through the gap: the
        // lit air adds at least one per cent of it (the march predicts about
        // two — see the sunset test), and the claim that matters is the
        // *ratio*: lit air behind the gap must far out-glow shadowed air
        // behind the stones, which gains nothing and loses a little to the
        // haze's own veil.
        let skyThroughGap = mean(off, rows: rows, columns: (centre - 10)..<(centre + 10))
        XCTAssertGreaterThan(gap, skyThroughGap * 0.01,
                             "the gap gained only \(gap) against a sky of "
                             + "\(skyThroughGap) — no beam")
        XCTAssertGreaterThan(gap, stoneSide * 1.8 + skyThroughGap * 0.005,
                             "gap gained \(gap), air behind the slabs gained "
                             + "\(stoneSide) — the shadow is not carving the beam")
    }
}
