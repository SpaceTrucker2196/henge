import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// How surfaces answer light, and how the wind moves the grass.
@MainActor
final class SurfaceResponseTests: XCTestCase {

    static let size = 224

    private func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; surface response unverified here.")
        }
        return device
    }

    /// Render the plain from eye height, *looking toward the sun* — the
    /// geometry that produces a specular rim on anything too smooth.
    ///
    /// Two things about the framing, both learned the hard way. The camera
    /// looks south along +Z with the sun on the same bearing, because a
    /// specular lobe only appears between viewer and light; the first version
    /// looked away from the sun and could not have found a highlight if one
    /// existed. And only the near ground is sampled: at the horizon the aerial
    /// perspective blends turf into sky, and the first version read that fog as
    /// a highlight thirty-two times the median.
    private func plain(windTime: Double, windSpeed: Float = 4.5,
                       sunAltitude: Double = 20) throws -> [Double] {
        let device = try makeDevice()
        var camera = Camera(position: SIMD3(0, 1.7, 0), target: SIMD3(0, 1.7, 60))
        camera.near = 0.3
        camera.far = 3000

        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                                         azimuth: Angle(degrees: 180)),
                               camera: camera, turbidity: 2.4, exposure: 1.6)
        state.windTime = windTime
        state.windSpeed = windSpeed

        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 512)
        try renderer.load(scene: MonumentScene(stones: []))

        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                             mipmapLevel: 0)
        }

        // From below the horizon down to the bottom edge, skipping the band
        // nearest the horizon where aerial perspective blends turf into sky.
        // The first version sampled only the bottom quarter, which at eye
        // height is a patch a few metres across — too small for a gust front to
        // cross, so the wind test saw the whole patch move together or not at
        // all.
        var luminances: [Double] = []
        for y in (Self.size * 9 / 16)..<Self.size {
            for x in 0..<Self.size {
                let offset = (y * Self.size + x) * 4
                let b = Double(pixels[offset])
                let g = Double(pixels[offset + 1])
                let r = Double(pixels[offset + 2])
                luminances.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
            }
        }
        return luminances
    }

    /// **Grass does not shine.** Looking into a low sun across the plain is
    /// exactly where a too-smooth ground grows a specular rim — the hour this
    /// app is entirely about. No part of the turf may approach a highlight.
    func testTheGrassHasNoSpecularHighlight() throws {
        let ground = try plain(windTime: 0, sunAltitude: 20)
        let sorted = ground.sorted()
        let median = sorted[sorted.count / 2]
        let brightest = sorted[Int(Double(sorted.count) * 0.999)]

        // Guard against a vacuous pass: a black frame has no highlight either.
        XCTAssertGreaterThan(median, 15,
                             "the ground is too dark for this test to mean anything")
        // A highlight is a small number of pixels far brighter than the rest.
        // Diffuse grass under a low sun should have a gentle gradient instead.
        XCTAssertLessThan(brightest / max(median, 1), 3.2,
                          "brightest ground \(brightest) against a median of "
                          + "\(median) — that is a specular rim on grass")
    }

    /// Turf's material constants say the same thing the render does, so a
    /// future edit that makes grass glossy fails here first and legibly.
    func testTurfIsMatteByConstruction() {
        XCTAssertLessThan(SurfaceMaterial.turfReflectance.x, 0.4,
                          "grass returns little specular; it is blades and air")
        XCTAssertGreaterThan(SurfaceMaterial.turfReflectance.y, 0.6,
                             "grass may never get smoother than this")
        XCTAssertEqual(SurfaceMaterial.turfReflectance.z, 1, "turf takes the wind")

        XCTAssertEqual(SurfaceMaterial.stoneReflectance.x, 1.0,
                       "a solid surface returns a full dielectric specular")
        XCTAssertEqual(SurfaceMaterial.stoneReflectance.z, 0, "stones do not sway")
    }

    /// **The wind moves.** Two instants must not render alike — and the change
    /// must be a travelling pattern, not the whole field pulsing, so the mean
    /// stays put while individual places change.
    func testTheWindChangesTheFieldOverTime() throws {
        // A well-lit ground, because the effect is proportional to the light on
        // it: at 4° the turf renders at a luminance of about 3 out of 255 and
        // the gusts move it by 1, which is true and unmeasurable.
        let first = try plain(windTime: 0, sunAltitude: 35)
        let later = try plain(windTime: 6, sunAltitude: 35)

        let differences = zip(first, later).map { abs($0 - $1) }
        // One luminance level, not two. The threshold is set from measurement:
        // a gust changes the turf by a few percent, which on ground rendering
        // around 57 of 255 is one to four levels. That is what wind in grass
        // actually looks like — a shimmer, not a flag — and a test demanding
        // more would be asking the renderer to overstate it.
        let changed = differences.filter { $0 >= 1 }.count
        XCTAssertGreaterThan(Double(changed) / Double(differences.count), 0.02,
                             "only \(changed) of \(differences.count) samples moved "
                             + "in six seconds of wind")

        let meanFirst = first.reduce(0, +) / Double(first.count)
        let meanLater = later.reduce(0, +) / Double(later.count)
        XCTAssertEqual(meanFirst, meanLater, accuracy: max(meanFirst * 0.08, 2),
                       "the whole field brightened rather than a gust crossing it")
    }

    /// A still day is still. Wind at zero must be perfectly static, or every
    /// offscreen render in the suite becomes time-dependent.
    func testNoWindMeansNoMovement() throws {
        let first = try plain(windTime: 0, windSpeed: 0, sunAltitude: 35)
        let later = try plain(windTime: 40, windSpeed: 0, sunAltitude: 35)
        XCTAssertEqual(zip(first, later).filter { $0 != $1 }.count, 0,
                       "the grass moved with the wind switched off")
    }

    /// The sky's own colour reaches the stones. Reflection is evaluated down
    /// the reflection vector through the same analytic sky the dome is drawn
    /// with, so a red dawn must tint the stones differently from a blue noon —
    /// and by more than the direct sunlight alone accounts for.
    func testStonesTakeTheirSheenFromTheSky() throws {
        let device = try makeDevice()

        func meanChannels(sunAltitude: Double) throws -> (r: Double, b: Double) {
            let stone = Stone(id: "probe", position: SIMD3(0, 0, 0),
                              height: 6, width: 3, thickness: 1.2, material: .sarsen)
            var camera = Camera(position: SIMD3(0, 3, 14), target: SIMD3(0, 3, 0))
            camera.near = 0.3
            let state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                                             azimuth: Angle(degrees: 180)),
                                   camera: camera)
            let renderer = try HengeRenderer(device: device, state: state,
                                             shadowResolution: 512)
            try renderer.load(scene: MonumentScene(stones: [stone]))

            let size = 192
            let texture = try renderer.renderOffscreen(width: size, height: size)
            var pixels = [UInt8](repeating: 0, count: size * size * 4)
            pixels.withUnsafeMutableBytes { raw in
                texture.getBytes(raw.baseAddress!, bytesPerRow: size * 4,
                                 from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0)
            }
            var red = 0.0, blue = 0.0
            var count = 0
            for y in (size / 3)..<(size * 2 / 3) {
                for x in (size * 5 / 12)..<(size * 7 / 12) {
                    let offset = (y * size + x) * 4
                    blue += Double(pixels[offset])
                    red += Double(pixels[offset + 2])
                    count += 1
                }
            }
            return (red / Double(count), blue / Double(count))
        }

        let dawn = try meanChannels(sunAltitude: 1)
        let noon = try meanChannels(sunAltitude: 55)
        XCTAssertGreaterThan(dawn.r / max(dawn.b, 1), noon.r / max(noon.b, 1) * 1.05,
                             "dawn r/b \(dawn.r / dawn.b), noon \(noon.r / noon.b) — "
                             + "the stone is not taking the sky's colour")
    }
}
