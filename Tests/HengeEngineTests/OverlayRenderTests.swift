import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The overlay's one rendering promise: it is a diagram, not a thing in the
/// light. Its pieces draw at their own flat colour with no sun on them at
/// all — which is checkable by rendering them at midnight, when everything
/// that obeys the light is nearly black.
@MainActor
final class OverlayRenderTests: XCTestCase {

    static let size = 192

    func testTheOverlayIsLegibleAtMidnight() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the overlay's unlit path is unverified here.")
        }

        // Deep night, new moon: the darkest frame the app can draw.
        let camera = Camera(position: SIMD3(0, 55, 70), target: SIMD3(0, 0, 0))
        let state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: -25),
                                                         azimuth: Angle(degrees: 0)),
                               camera: camera, grassBlades: false)
        let renderer = try HengeRenderer(device: device, state: state,
                                         shadowResolution: 512)
        try renderer.load(scene: MonumentScene(stones: []))

        func brightest() throws -> Double {
            let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
            var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
            pixels.withUnsafeMutableBytes { raw in
                texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                                 from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                                 mipmapLevel: 0)
            }
            var maximum = 0.0
            for i in 0..<(Self.size * Self.size) {
                let luminance = 0.2126 * Double(pixels[i * 4 + 2])
                    + 0.7152 * Double(pixels[i * 4 + 1])
                    + 0.0722 * Double(pixels[i * 4])
                maximum = max(maximum, luminance)
            }
            return maximum
        }

        let dark = try brightest()
        XCTAssertLessThan(dark, 60,
                          "the moonless midnight frame is too bright for this "
                          + "test to mean anything")

        renderer.loadOverlay(GeometryOverlay.markerStones(at: JulianDay(2_451_623.816),
                                                          ground: { _, _ in 0 })
                             + [GeometryOverlay.sunRay(azimuth: Angle(degrees: 49.9),
                                                       ground: { _, _ in 0 })])
        let lit = try brightest()
        XCTAssertGreaterThan(lit, 120,
                             "gold markers at midnight peaked at \(lit) of 255 — "
                             + "the overlay is being lit like a stone instead of "
                             + "drawn like a diagram")

        renderer.loadOverlay([])
        XCTAssertEqual(try brightest(), dark, accuracy: 1,
                       "clearing the overlay must restore the plain frame")
    }
}
