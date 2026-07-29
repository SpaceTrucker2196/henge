import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The stars in pixels: present on a dark night, absent at noon, and gone
/// when the switch says so.
@MainActor
final class StarRenderTests: XCTestCase {

    static let size = 256

    private func brightSkyPixels(sunAltitude: Double, stars: Bool) throws -> Int {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the stars are unverified here.")
        }
        // Looking up into the sky, empty plain, new moon.
        let camera = Camera(position: SIMD3(0, 1.7, 0), target: SIMD3(0, 60, -40))
        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                                         azimuth: Angle(degrees: 0)),
                               camera: camera, grassBlades: false)
        state.stars = stars

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
        var bright = 0
        for i in 0..<(Self.size * Self.size) {
            let luminance = 0.2126 * Double(pixels[i * 4 + 2])
                + 0.7152 * Double(pixels[i * 4 + 1])
                + 0.0722 * Double(pixels[i * 4])
            if luminance > 35 { bright += 1 }
        }
        return bright
    }

    func testTheNightSkyHasStarsAndNoonHasNone() throws {
        let night = try brightSkyPixels(sunAltitude: -25, stars: true)
        let dark = try brightSkyPixels(sunAltitude: -25, stars: false)
        // Solid-angle honesty: a 55° field holds about six percent of the
        // sphere, so expect tens of stars above the threshold, not hundreds
        // — the first version of this test asked for a planetarium and the
        // sky rightly refused. The floor sits well under the measured count
        // so retuning the fade cannot flake it.
        XCTAssertGreaterThan(night - dark, 20,
                             "only \(night - dark) starlike pixels on a "
                             + "moonless midnight — the catalogue is not being drawn")
        XCTAssertLessThan(dark, 10,
                          "with stars off the night sky should hold almost "
                          + "nothing above the threshold")

        let noonWithStars = try brightSkyPixels(sunAltitude: 45, stars: true)
        let noonWithout = try brightSkyPixels(sunAltitude: 45, stars: false)
        XCTAssertEqual(noonWithStars, noonWithout,
                       "the noon sky must not change when the (invisible) "
                       + "stars are enabled — the twilight gate has failed")
    }
}
