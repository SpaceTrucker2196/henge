import XCTest
import Metal
import simd
import HengeAstro
import HengeGeometry
@testable import HengeEngine

/// Aerial perspective is the sky scattered along the line of sight, so a
/// distant surface seen against the high sky must fog toward a bluer, darker
/// colour than one seen at the horizon. For a long time the shader clamped
/// the elevation of that colour to the horizon for every fragment — the
/// azimuth was right, the elevation never was — and nothing measured it.
@MainActor
final class AerialPerspectiveTests: XCTestCase {

    static let size = 256

    private func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; aerial perspective unverified here.")
        }
        return device
    }

    /// Mean red-to-blue ratio of a small patch around a world point.
    private func redOverBlue(_ pixels: [UInt8], at point: SIMD3<Float>,
                             viewProjection: float4x4) -> Double {
        let clip = viewProjection * SIMD4(point, 1)
        let ndc = SIMD2(clip.x / clip.w, clip.y / clip.w)
        let cx = Int((ndc.x * 0.5 + 0.5) * Float(Self.size))
        let cy = Int((1 - (ndc.y * 0.5 + 0.5)) * Float(Self.size))
        var r = 0.0, b = 0.0
        for y in (cy - 2)...(cy + 2) {
            for x in (cx - 2)...(cx + 2) {
                let offset = (y * Self.size + x) * 4      // BGRA8
                b += Double(pixels[offset])
                r += Double(pixels[offset + 2])
            }
        }
        return r / max(b, 1)
    }

    /// One tall face 400 m off — far enough that the haze is nearly half the
    /// colour — with its foot on the horizon and its top 37° up the sky.
    /// Same albedo, same normal, same sun on both patches; only the sky
    /// behind the haze differs, and the top's must be the bluer of the two.
    func testAFarFaceFogsBluerAgainstTheHighSky() throws {
        let device = try makeDevice()
        let tower = Stone(id: "tower", position: SIMD3(0, 0, -400), height: 300,
                          width: 24, thickness: 6, bearing: Angle(degrees: 0))

        var camera = Camera(position: SIMD3(0, 1.7, 0), target: SIMD3(0, 130, -400))
        camera.near = 1
        camera.far = 1000
        // The sun behind the camera, so the face toward it is plainly lit.
        let sun = HorizontalCoordinate(altitude: Angle(degrees: 30),
                                       azimuth: Angle(degrees: 180))
        let state = SceneState(sun: sun, camera: camera, turbidity: 2.2, exposure: 1.0,
                               surfaceTexturing: false, grassBlades: false)
        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 512)
        try renderer.load(scene: MonumentScene(state: .asItWas, stones: [tower]),
                          subdivisions: 8, roughness: 0, rounding: 0)

        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size), mipmapLevel: 0)
        }
        let viewProjection = renderer.buildFrameUniforms(aspect: 1).viewProjection
        let face: Float = -400 + 3          // the near face of a 6 m thick slab
        let foot = redOverBlue(pixels, at: SIMD3(0, 8, face), viewProjection: viewProjection)
        let top = redOverBlue(pixels, at: SIMD3(0, 290, face), viewProjection: viewProjection)

        // The two patches are the same stone under the same light; with the
        // elevation clamped to the horizon they came out identical.
        XCTAssertLessThan(top, foot * 0.95,
                          "top R/B \(top) should be bluer than the foot's \(foot)")
    }
}
