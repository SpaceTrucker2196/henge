import XCTest
import Metal
import simd
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// A full moon casts a shadow you can stand in — you can watch it happen at
/// the monument, and for a while this renderer computed that shadow and then
/// washed it invisible under its own unshadowed ambient. This test is the
/// balance's keeper: moonlit turf against moon-shadowed turf must differ by
/// a margin the eye would call a shadow.
@MainActor
final class MoonShadowTests: XCTestCase {

    static let size = 256

    func testAFullMoonCastsAVisibleShadow() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the moon's shadow is unverified here.")
        }

        // Full moon riding at 40° in the south; the sun far below the
        // opposite horizon, as it is when a full moon stands that high.
        // One stone alone on the plain, seen from above so image space is
        // ground space — the shadow-agreement suite's geometry, reused.
        let stone = Stone(id: "moon-gnomon", position: .zero,
                          height: 6, width: 2, thickness: 1.2,
                          bearing: Angle(degrees: 180))
        var camera = Camera(position: SIMD3(0, 120, 0.001), target: SIMD3(0, 0, 0))
        camera.fieldOfView = 2 * atan(20.0 / 120.0)
        camera.near = 1
        camera.far = 400

        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: -30),
                                                         azimuth: Angle(degrees: 0)),
                               moon: HorizontalCoordinate(altitude: Angle(degrees: 40),
                                                          azimuth: Angle(degrees: 180)),
                               moonIllumination: 1.0,
                               camera: camera, grassBlades: false)
        state.stars = false

        let renderer = try HengeRenderer(device: device, state: state,
                                         shadowResolution: 1024)
        try renderer.load(scene: MonumentScene(stones: [stone]))
        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                             mipmapLevel: 0)
        }
        func mean(rows: Range<Int>, columns: Range<Int>) -> Double {
            var total = 0.0; var count = 0
            for y in rows { for x in columns {
                let offset = (y * Self.size + x) * 4
                total += 0.2126 * Double(pixels[offset + 2])
                    + 0.7152 * Double(pixels[offset + 1])
                    + 0.0722 * Double(pixels[offset])
                count += 1
            } }
            return total / Double(count)
        }

        // The moon stands south, so the shadow runs north: sample the turf
        // four metres north of the stone (inside the ~7 m shadow of a 6 m
        // stone at 40°), against turf four metres east, where nothing
        // shades. Ground points are pushed through the renderer's own
        // view-projection rather than an assumed row order — the
        // shadow-agreement suite learned that a straight-down look-at flips
        // its basis, and this test does not relearn it.
        let viewProjection = renderer.buildFrameUniforms(aspect: 1).viewProjection
        func pixel(_ east: Double, _ south: Double) -> (x: Int, y: Int) {
            let clip = viewProjection * SIMD4<Float>(Float(east), 0, Float(south), 1)
            let ndc = SIMD2(clip.x / clip.w, clip.y / clip.w)
            return (x: Int((ndc.x * 0.5 + 0.5) * Float(Self.size)),
                    y: Int((1 - (ndc.y * 0.5 + 0.5)) * Float(Self.size)))
        }
        func patchMean(at point: (x: Int, y: Int)) -> Double {
            mean(rows: (point.y - 6)..<(point.y + 6),
                 columns: (point.x - 6)..<(point.x + 6))
        }
        let shade = patchMean(at: pixel(0, -4))
        let lit = patchMean(at: pixel(4.5, 0))

        XCTAssertGreaterThan(lit, 6,
                             "moonlit turf at \(lit) is too dark for a shadow "
                             + "to be measurable against")
        XCTAssertLessThan(shade, lit * 0.72,
                          "moon-shadowed turf (\(shade)) against moonlit "
                          + "(\(lit)) — a full moon's shadow should be "
                          + "unmistakable, and this one is a rumour")
    }
}
