import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The constellation figures on the actual sky: present when asked for at
/// night, absent when off, and incapable of touching the day.
@MainActor
final class ConstellationRenderTests: XCTestCase {

    static let size = 256

    /// Total sky luminance rather than a bright-pixel count: the figures
    /// are deliberately faint — far below any star — so they move the sum,
    /// not the census of bright points.
    private func skyLuminance(sunAltitude: Double,
                              lines: Bool) throws -> Double {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the figures are unverified here.")
        }
        let camera = Camera(position: SIMD3(0, 1.7, 0), target: SIMD3(0, 60, -40))
        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                                         azimuth: Angle(degrees: 0)),
                               camera: camera, grassBlades: false)
        state.stars = true
        state.constellationLines = lines

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
        var total = 0.0
        for i in 0..<(Self.size * Self.size) {
            total += 0.2126 * Double(pixels[i * 4 + 2])
                + 0.7152 * Double(pixels[i * 4 + 1])
                + 0.0722 * Double(pixels[i * 4])
        }
        return total
    }

    func testTheFiguresJoinTheNightAndNeverTheDay() throws {
        let bare = try skyLuminance(sunAltitude: -25, lines: false)
        let figured = try skyLuminance(sunAltitude: -25, lines: true)
        // 188 faint strokes across the whole sphere; a 55° field sees
        // dozens of them. The margin is set well under the measured gain
        // so a tuning pass on the line brightness cannot flake it — and
        // well above zero so an empty buffer cannot pass it.
        XCTAssertGreaterThan(figured - bare, 500,
                             "figures on added \(figured - bare) luminance — "
                             + "the lines are not being drawn")

        let noonBare = try skyLuminance(sunAltitude: 45, lines: false)
        let noonFigured = try skyLuminance(sunAltitude: 45, lines: true)
        XCTAssertEqual(noonFigured, noonBare,
                       "the noon sky must not change when the (invisible) "
                       + "figures are enabled — the twilight gate has failed")
    }
}
