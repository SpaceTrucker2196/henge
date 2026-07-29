import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The Moon's disc, measured. The angular size is the ephemeris's business
/// and is deliberately tiny; these tests enlarge the disc the same way the
/// penumbra suite enlarges the sun — the geometry scales, and a measurable
/// disc is the whole point of the knob.
@MainActor
final class MoonRenderTests: XCTestCase {

    static let size = 256

    /// Render a night sky with an enlarged moon centred in frame.
    private func discPixels(sunAzimuth: Double) throws -> [Double] {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the moon's face is unverified here.")
        }
        let moon = HorizontalCoordinate(altitude: Angle(degrees: 40),
                                        azimuth: Angle(degrees: 180))
        let v = moon.unitVector
        var camera = Camera(position: SIMD3(0, 1.7, 0),
                            target: SIMD3(Float(v.x), Float(v.y), Float(v.z)) * 100
                                + SIMD3(0, 1.7, 0))
        camera.near = 0.3
        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: -25),
                                                         azimuth: Angle(degrees: sunAzimuth)),
                               moon: moon,
                               moonAngularRadius: 0.06,
                               moonIllumination: 1.0,
                               camera: camera, grassBlades: false)
        state.stars = false

        let renderer = try HengeRenderer(device: device, state: state,
                                         shadowResolution: 512)
        try renderer.load(scene: MonumentScene(stones: []))
        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                             mipmapLevel: 0)
        }
        // The disc sits at frame centre; 0.06 rad in a 55° field at 256 px
        // is about 32 px across, so a 20-px central patch stays inside it.
        var luminances: [Double] = []
        for y in (Self.size / 2 - 10)..<(Self.size / 2 + 10) {
            for x in (Self.size / 2 - 10)..<(Self.size / 2 + 10) {
                let offset = (y * Self.size + x) * 4
                luminances.append(0.2126 * Double(pixels[offset + 2])
                                  + 0.7152 * Double(pixels[offset + 1])
                                  + 0.0722 * Double(pixels[offset]))
            }
        }
        return luminances
    }

    private func statistics(_ values: [Double]) -> (mean: Double, spread: Double) {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            / Double(values.count)
        return (mean, variance.squareRoot())
    }

    /// **The Moon wears its photograph.** A full disc must show the maria —
    /// internal contrast a plain lit sphere does not have — and must be
    /// bright at its centre, which is also the regression pin for the
    /// normal-sign fix: the old far-side normal darkened exactly the full
    /// phase the photograph makes obvious.
    func testTheFullMoonShowsItsFaceBrightly() throws {
        // Full moon: the sun stands opposite the moon's azimuth, below the
        // horizon, as it really does when the full moon rides high.
        let disc = try discPixels(sunAzimuth: 0)
        let stats = statistics(disc)
        XCTAssertGreaterThan(stats.mean, 60,
                             "the full disc's centre averages \(stats.mean) — "
                             + "a dark full moon is the inverted-normal bug")
        XCTAssertGreaterThan(stats.spread, 8,
                             "disc contrast \(stats.spread): no maria — the "
                             + "photograph is not on the disc")
    }

    /// **New moon is dark.** Sun and moon on the same bearing: the face we
    /// see is unlit, and only earthshine's ghost may remain.
    func testTheNewMoonKeepsItsDarkFace() throws {
        let full = statistics(try discPixels(sunAzimuth: 0)).mean
        let new = statistics(try discPixels(sunAzimuth: 180)).mean
        XCTAssertLessThan(new, full * 0.35,
                          "same-bearing sun leaves the disc at \(new) against "
                          + "\(full) opposed — the phase geometry is inverted")
    }
}
