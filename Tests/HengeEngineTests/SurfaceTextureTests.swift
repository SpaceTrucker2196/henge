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
                               camera: camera,
                                   grassBlades: false)
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

    /// Weathering darkens the foot of a stone, and only the foot.
    ///
    /// Groundwater wicks up the first half-metre and wet rock is darker than
    /// dry. Measured as a per-row ratio between the same stone rendered with
    /// weathering on and off, which is what makes it robust: an absolute
    /// reading at the base is dominated by self-shadowing and ambient
    /// occlusion, and hand-placing a measurement band got a diluted 0.8%
    /// because the band straddled the stone's foot and the turf below it.
    ///
    /// Asserting the *shape* rather than a single number also catches the
    /// failure that matters — weathering that darkens the whole stone is a
    /// tint, not a damp course.
    func testTheDampCourseDarkensTheFootAndNothingElse() throws {
        let device = try makeDevice()
        let size = 256

        func rowLuminances(weathered: Bool) throws -> [Double] {
            // A short stone seen close. The damp course is a fixed 0.55 m, so
            // on a six-metre upright it is 9% of the height — a sliver that
            // every added detail (turf below, then the soil bank against the
            // foot) pushed out of whatever band was being measured. On a
            // two-metre stone it is over a quarter of the frame and no longer
            // depends on placing a band precisely.
            let stone = Stone(id: "probe", position: SIMD3(0, 1.0, 0),
                              height: 2.0, width: 1.4, thickness: 0.9, material: .sarsen)
            var camera = Camera(position: SIMD3(0, 1.1, 5), target: SIMD3(0, 1.0, 0))
            camera.near = 0.2
            let state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: 45),
                                                             azimuth: Angle(degrees: 180)),
                                   camera: camera, weathering: weathered,
                                   grassBlades: false)
            let renderer = try HengeRenderer(device: device, state: state,
                                             shadowResolution: 1024)
            try renderer.load(scene: MonumentScene(stones: [stone]))

            let texture = try renderer.renderOffscreen(width: size, height: size)
            var pixels = [UInt8](repeating: 0, count: size * size * 4)
            pixels.withUnsafeMutableBytes { raw in
                texture.getBytes(raw.baseAddress!, bytesPerRow: size * 4,
                                 from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0)
            }

            return (0..<size).map { y in
                var total = 0.0
                // Only the middle columns, which are the stone's face.
                for x in (size * 5 / 12)..<(size * 7 / 12) {
                    let offset = (y * size + x) * 4
                    let b = Double(pixels[offset])
                    let g = Double(pixels[offset + 1])
                    let r = Double(pixels[offset + 2])
                    total += 0.2126 * r + 0.7152 * g + 0.0722 * b
                }
                return total / Double(size / 6)
            }
        }

        let dry = try rowLuminances(weathered: false)
        let wet = try rowLuminances(weathered: true)
        let ratios = zip(wet, dry).map { $1 > 4 ? $0 / $1 : 1.0 }

        // Image rows run downward: the stone's top half is the upper rows.
        let upper = Array(ratios[(size * 26 / 100)..<(size * 44 / 100)])
        // The stone's whole lower half, and take the minimum rather than a
        // mean. Hand-placing a narrow band kept breaking as the scene gained
        // detail — first it straddled the turf, then the soil bank heaped
        // against the foot moved the damp course out of it. The minimum is
        // immune to both: soil is not weather-dependent, so those rows have a
        // ratio of exactly 1 and can never be the darkest.
        let lower = Array(ratios[(size * 52 / 100)..<(size * 74 / 100)])

        let darkest = lower.min() ?? 1
        XCTAssertLessThan(darkest, 0.94,
                          "the base darkened by only \((1 - darkest) * 100)% — "
                          + "the damp course is not doing anything")

        let upperMean = upper.reduce(0, +) / Double(upper.count)
        XCTAssertGreaterThan(upperMean, 0.93,
                             "weathering dimmed the whole stone by \((1 - upperMean) * 100)% — "
                             + "that is a tint, not a damp course")
    }

    /// Weathering is on in the shipping path, for the same reason texturing is.
    func testWeatheringIsOnByDefault() {
        let state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: 30),
                                                         azimuth: Angle(degrees: 120)))
        XCTAssertTrue(state.weathering)
    }

    /// Two stones must not weather alike. The pattern is seeded per stone, and
    /// a shared seed would put the same lichen patch on all eighty of them.
    func testWeatheringIsSeededPerStone() {
        let scene = MonumentScene.complete(state: .asItWas)
        let seeds = Set(scene.stones.map(\.seed))
        XCTAssertGreaterThan(seeds.count, scene.stones.count / 2,
                             "stones share seeds; they would weather identically")
    }
}
