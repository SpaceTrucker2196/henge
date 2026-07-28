import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The photographic surfaces, and the guarantees around them.
@MainActor
final class SurfaceTextureTests: XCTestCase {

    private func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; texture loading unverified here.")
        }
        return device
    }

    /// Both material sets are present in the bundle and decode.
    ///
    /// Worth a test of its own because the failure mode is silent: a resource
    /// that did not get copied leaves the renderer drawing flat, which looks
    /// like a shading bug rather than a missing file.
    func testBothMaterialSetsLoad() throws {
        let device = try makeDevice()
        for kind in SurfaceTextures.Kind.allCases {
            let set = try XCTUnwrap(SurfaceTextures.load(kind, device: device),
                                    "\(kind) failed to load")
            XCTAssertGreaterThanOrEqual(set.albedo.width, 512)
            XCTAssertGreaterThan(set.albedo.mipmapLevelCount, 1,
                                 "no mipmaps means aliased turf at any distance")
            XCTAssertGreaterThanOrEqual(set.normal.width, 256)
            XCTAssertGreaterThanOrEqual(set.roughness.width, 256)
        }
    }

    /// Colour is sRGB; normal and roughness are data and must not be
    /// gamma-decoded. Getting this backwards washes out the albedo and bends
    /// the normals by the wrong amount — a subtle, plausible-looking wrongness
    /// that no silhouette test would ever catch.
    func testColourIsGammaDecodedAndDataIsNot() throws {
        let device = try makeDevice()
        let set = try XCTUnwrap(SurfaceTextures.load(.rock, device: device))
        XCTAssertTrue([.bgra8Unorm_srgb, .rgba8Unorm_srgb].contains(set.albedo.pixelFormat),
                      "albedo should be sRGB, got \(set.albedo.pixelFormat)")
        XCTAssertFalse([.bgra8Unorm_srgb, .rgba8Unorm_srgb].contains(set.normal.pixelFormat),
                       "a normal map must not be gamma-decoded")
        XCTAssertFalse([.bgra8Unorm_srgb, .rgba8Unorm_srgb].contains(set.roughness.pixelFormat),
                       "a roughness map must not be gamma-decoded")
    }

    /// **The shipping path is textured.** The geometry oracle switches this off
    /// so it can see a shadow edge through the grain, which is a legitimate
    /// thing to do and a dangerous one to forget — without this assertion the
    /// whole app could ship untextured and every test would still pass.
    func testTexturingIsOnByDefault() {
        let state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: 30),
                                                         azimuth: Angle(degrees: 120)))
        XCTAssertTrue(state.surfaceTexturing)
        XCTAssertTrue(SceneState.at(JulianDay(CalendarDate(year: 2026, month: 6, day: 21)))
            .surfaceTexturing)
    }

    /// Tile sizes come from what was photographed, not from taste. If these
    /// drift the stones turn to gravel or the turf to a putting green.
    func testTileSizesAreTheScaleOfTheThingPhotographed() {
        XCTAssertEqual(SurfaceTextures.Kind.rock.metresPerTile, 1.5, accuracy: 0.01)
        XCTAssertEqual(SurfaceTextures.Kind.grass.metresPerTile, 0.65, accuracy: 0.01)
        XCTAssertLessThan(SurfaceTextures.Kind.grass.normalStrength,
                          SurfaceTextures.Kind.rock.normalStrength,
                          "turf is flatter than sarsen; pushed further it reads "
                          + "as corrugated iron under a low sun")
    }

    /// A textured render still produces a lit, plausible image — the texture
    /// path must not darken the world to nothing or blow it out.
    func testATexturedRenderIsStillProperlyExposed() throws {
        let device = try makeDevice()
        var camera = Camera(position: SIMD3(0, 4, 40), target: SIMD3(0, 3, 0))
        camera.near = 0.5
        let state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: 35),
                                                         azimuth: Angle(degrees: 140)),
                               camera: camera)
        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 1024)
        try renderer.load(scene: MonumentScene.complete(state: .asItWas))

        let size = 256
        let texture = try renderer.renderOffscreen(width: size, height: size)
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: size * 4,
                             from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0)
        }

        var total = 0.0
        var distinct = Set<UInt8>()
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let luminance = 0.2126 * Double(pixels[i + 2]) + 0.7152 * Double(pixels[i + 1])
                + 0.0722 * Double(pixels[i])
            total += luminance
            distinct.insert(pixels[i + 1])
        }
        let mean = total / Double(size * size)
        XCTAssertGreaterThan(mean, 20, "the textured world came out black")
        XCTAssertLessThan(mean, 235, "the textured world blew out")
        // Texture means variation. A flat render would collapse to a handful of
        // values, so this also catches the textures silently failing to bind.
        XCTAssertGreaterThan(distinct.count, 40,
                             "too few distinct values — is anything textured?")
    }
}
