import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The zodiac-only sky in pixels: looking up and north on a September
/// night — Ursa Major, Cassiopeia, Cygnus, none of it zodiac — the switch
/// must put most of the points out.
@MainActor
final class ZodiacRenderTests: XCTestCase {

    static let size = 256

    private func brightPixels(zodiacOnly: Bool) throws -> Int {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the zodiac sky is unverified here.")
        }
        let camera = Camera(position: SIMD3(0, 1.7, 0), target: SIMD3(0, 60, -40))
        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: -30),
                                                         azimuth: Angle(degrees: 0)),
                               camera: camera, grassBlades: false,
                               epoch: JulianDay(CalendarDate(year: 2026, month: 9, day: 20, hour: 21)))
        state.stars = true
        state.milkyWay = false
        state.zodiacOnly = zodiacOnly
        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 512)
        try renderer.load(scene: MonumentScene(stones: []))
        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size), mipmapLevel: 0)
        }
        var bright = 0
        for i in 0..<(Self.size * Self.size) {
            let luminance = 0.2126 * Double(pixels[i * 4 + 2])
                + 0.7152 * Double(pixels[i * 4 + 1]) + 0.0722 * Double(pixels[i * 4])
            if luminance > 35 { bright += 1 }
        }
        return bright
    }

    func testTheZodiacOnlySkyPutsTheNorthernStarsOut() throws {
        let whole = try brightPixels(zodiacOnly: false)
        let zodiac = try brightPixels(zodiacOnly: true)
        XCTAssertGreaterThan(whole, 20, "the whole sky must have stars to put out")
        XCTAssertLessThan(zodiac, whole / 3,
                          "\(zodiac) bright pixels zodiac-only against \(whole) whole")
    }
}
