import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The research note's testing rule, applied: render N same-dimension stones
/// and require the variance of their image statistics to exceed a floor.
/// Internal consistency proves nothing here — a renderer drawing the same
/// stone eighty times is perfectly consistent and perfectly wrong.
@MainActor
final class StoneIndividualityRenderTests: XCTestCase {

    static let size = 192

    /// Render one stone alone on the plain, mid-morning sun, fixed camera;
    /// return the luminances of a patch centred on the stone.
    private func portrait(id: String) throws -> [Double] {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; stone individuality unverified here.")
        }
        let stone = Stone(id: id, position: .zero,
                          height: 6.0, width: 2.4, thickness: 1.1)
        var camera = Camera(position: SIMD3(0, 3, 11), target: SIMD3(0, 3, 0))
        camera.near = 0.3
        let state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: 35),
                                                         azimuth: Angle(degrees: 140)),
                               camera: camera, grassBlades: false)
        let renderer = try HengeRenderer(device: device, state: state,
                                         shadowResolution: 512)
        try renderer.load(scene: MonumentScene(stones: [stone]))

        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                             mipmapLevel: 0)
        }
        var luminances: [Double] = []
        for y in (Self.size / 4)..<(Self.size * 3 / 4) {
            for x in (Self.size * 3 / 8)..<(Self.size * 5 / 8) {
                let offset = (y * Self.size + x) * 4
                luminances.append(0.2126 * Double(pixels[offset + 2])
                                  + 0.7152 * Double(pixels[offset + 1])
                                  + 0.0722 * Double(pixels[offset]))
            }
        }
        return luminances
    }

    private func statistics(_ luminance: [Double]) -> (mean: Double, spread: Double) {
        let mean = luminance.reduce(0, +) / Double(luminance.count)
        let variance = luminance.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            / Double(luminance.count)
        return (mean, variance.squareRoot())
    }

    /// **No two stones render alike.** Five stones of identical nominal
    /// dimensions, photographed identically, must differ in their image
    /// statistics — because their meshes and their coats both differ.
    func testSameDimensionStonesRenderAsIndividuals() throws {
        let ids = ["stone-1", "stone-2", "stone-3", "stone-9", "stone-17"]
        let portraits = try ids.map { try portrait(id: $0) }
        let stats = portraits.map(statistics)

        // Guard against a vacuous pass: the stone must actually be in frame.
        for (id, s) in zip(ids, stats) {
            XCTAssertGreaterThan(s.mean, 15, "\(id) rendered black — nothing measured")
        }

        let means = stats.map(\.mean)
        let contrasts = stats.map(\.spread)
        let meanSpread = (means.max() ?? 0) - (means.min() ?? 0)
        let contrastSpread = (contrasts.max() ?? 0) - (contrasts.min() ?? 0)

        // Floors measured at calibration with headroom below the observed
        // values; identical stones would put both at zero exactly.
        XCTAssertGreaterThan(meanSpread, 1.0,
                             "five stones' mean luminances span only "
                             + "\(meanSpread) levels — the circle is one rock "
                             + "wearing eighty coats")
        XCTAssertGreaterThan(contrastSpread, 1.0,
                             "five stones' contrasts span only \(contrastSpread)")
    }

    /// The same stone must render byte-identically twice — individuality is
    /// seeded, never sampled from anything time-dependent.
    func testAStoneIsTheSameStoneTwice() throws {
        let first = try portrait(id: "stone-21")
        let second = try portrait(id: "stone-21")
        XCTAssertEqual(zip(first, second).filter { $0 != $1 }.count, 0,
                       "stone-21 changed between two identical renders")
    }
}
