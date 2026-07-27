import XCTest
import Metal
import simd
import HengeAstro
import HengeGeometry
@testable import HengeEngine

/// Layer 2 of the oracle: the rendered shadow must land where the mathematics
/// says it does.
///
/// MISSION.md invariant 2 says visual plausibility is never a substitute for
/// agreement. This is where that is enforced. The scene is rendered from
/// straight overhead through an orthographic projection, so a pixel maps
/// linearly to a position on the ground and the comparison is a distance in
/// metres rather than a judgement about an image.
///
/// Where no Metal device exists the tests **skip loudly** — a silent pass would
/// be worse than no test at all.
final class ShadowAgreementTests: XCTestCase {

    /// Ground area covered by the offscreen render, in metres.
    static let groundExtent: Double = 40
    static let imageSize = 512

    /// Tolerance, in metres on the ground.
    ///
    /// Measured, not chosen. The suite was walked down through 0.24, 0.20,
    /// 0.14 and 0.10 to find where agreement breaks: it holds at 0.28 m across
    /// all four bearings and fails below. The limiting case is the 225°
    /// diagonal, where the box's corner sits worst against the shadow map's
    /// texel grid; the cardinal bearings are good to about 0.1 m.
    ///
    /// The floor is the sum of the sampling step (78 mm per ground pixel), the
    /// shadow map texel in this cascade (117 mm) and the 3×3 comparison tap
    /// either side of it.
    ///
    /// It is a ceiling on this configuration's honesty, so it moves only when
    /// the renderer earns it — M2's PCSS will change the number, and the right
    /// response then is to re-measure rather than to relax.
    static let toleranceMetres: Double = 0.28

    private func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("""
                No Metal device on this machine, so the GPU half of the oracle \
                cannot run here. This is a skip, not a pass: the shadow \
                agreement claim is unverified in this environment.
                """)
        }
        return device
    }

    /// A camera looking straight down, so that image space is ground space.
    @MainActor
    private func makeOverheadRenderer(device: MTLDevice,
                                      sun: HorizontalCoordinate,
                                      scene: MonumentScene) throws -> HengeRenderer {
        var camera = Camera(position: SIMD3(0, 260, 0.001), target: SIMD3(0, 0, 0))
        // A narrow field from high up approximates an orthographic view closely
        // enough that the residual perspective error stays well inside a pixel
        // over the ground patch being measured.
        let extent = Float(Self.groundExtent)
        camera.fieldOfView = 2 * atan((extent / 2) / camera.position.y)
        camera.near = 1
        camera.far = 600

        let state = SceneState(sun: sun, sunAngularRadius: 0.00465,
                               camera: camera, turbidity: 2.2, exposure: 1.0)
        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 2048)
        try renderer.load(scene: scene, subdivisions: 8, roughness: 0, rounding: 0)
        return renderer
    }

    /// Map a ground position to a pixel by pushing it through the renderer's
    /// *own* view-projection.
    ///
    /// Deriving the mapping instead of assuming one matters: looking straight
    /// down is the degenerate case for a look-at matrix, and the basis it picks
    /// there flips east and west. An assumed mapping made this suite report a
    /// shadow on the wrong side of the stone while the renderer was correct.
    @MainActor
    private func pixelMapper(_ renderer: HengeRenderer)
        -> (SIMD2<Double>) -> (x: Int, y: Int) {
        let viewProjection = renderer.buildFrameUniforms(aspect: 1).viewProjection
        return { ground in
            let world = SIMD4<Float>(Float(ground.x), 0, Float(ground.y), 1)
            let clip = viewProjection * world
            let ndc = SIMD2(clip.x / clip.w, clip.y / clip.w)
            // NDC y points up, image rows run down.
            return (x: Int((ndc.x * 0.5 + 0.5) * Float(Self.imageSize)),
                    y: Int((1 - (ndc.y * 0.5 + 0.5)) * Float(Self.imageSize)))
        }
    }

    private func luminance(_ pixels: [UInt8], x: Int, y: Int) -> Double? {
        guard x >= 0, y >= 0, x < Self.imageSize, y < Self.imageSize else { return nil }
        let offset = (y * Self.imageSize + x) * 4
        // BGRA8
        let b = Double(pixels[offset]), g = Double(pixels[offset + 1]), r = Double(pixels[offset + 2])
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
    }

    @MainActor
    private func readPixels(_ texture: MTLTexture) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: Self.imageSize * Self.imageSize * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!,
                             bytesPerRow: Self.imageSize * 4,
                             from: MTLRegionMake2D(0, 0, Self.imageSize, Self.imageSize),
                             mipmapLevel: 0)
        }
        return pixels
    }

    // ── the test that matters ───────────────────────────────────────────────

    /// Walk outward from the base of a stone along the shadow's bearing and
    /// find where the ground stops being dark. That measured tip must agree
    /// with `ShadowSolver`'s analytic tip.
    @MainActor
    func testRenderedShadowTipAgreesWithTheAnalyticSolution() async throws {
        let device = try makeDevice()

        // A single upright, alone on the plain, so nothing else casts into the
        // measurement. 30° elevation gives a shadow about 1.7× the height —
        // long enough to measure, short enough to stay inside the patch.
        let stone = Stone(id: "gnomon", position: SIMD3(0, 0, 0),
                          height: 6.0, width: 1.2, thickness: 1.2)
        let scene = MonumentScene(state: .asItWas, stones: [stone])

        for azimuth in [90.0, 140.0, 225.0, 310.0] {
            let sun = HorizontalCoordinate(altitude: Angle(degrees: 30),
                                           azimuth: Angle(degrees: azimuth))

            let renderer = try makeOverheadRenderer(device: device, sun: sun, scene: scene)
            let texture = try renderer.renderOffscreen(width: Self.imageSize,
                                                       height: Self.imageSize)
            let pixels = readPixels(texture)
            let pixel = pixelMapper(renderer)

            // The renderer casts the whole stone, so the prediction must be the
            // silhouette's far edge along the sampling ray — not the shadow of
            // the apex, which stops half a stone short and would make a correct
            // renderer look wrong by a consistent half metre.
            let bearing = ShadowSolver.shadowBearing(sunAzimuth: Angle(degrees: azimuth))
            let direction = SIMD2(bearing.sine, -bearing.cosine)
            // Against the mesh the renderer actually draws, not the box that
            // bounds it: the drawn stone is a rounded solid inscribed in that
            // box, and comparing to the box would charge the renderer for a
            // difference of shape.
            let drawn = StoneMeshBuilder.build(stone, subdivisions: 8,
                                               roughness: 0, rounding: 0)
            let outline = ShadowSolver.shadowOutline(of: drawn, sun: sun)
            let analyticDistance = try XCTUnwrap(
                Self.rayExitDistance(polygon: outline, direction: direction),
                "the analytic outline does not cross the sampling ray")

            // Sample along the shadow's centre line. Start clear of the stone's
            // own footprint so the stone itself is not mistaken for its shadow.
            let start = 1.4
            let step = Self.groundExtent / Double(Self.imageSize)
            var brightnesses: [(distance: Double, value: Double)] = []
            var d = start
            while d < analyticDistance * 1.8 {
                let ground = direction * d
                let p = pixel(ground)
                if let value = luminance(pixels, x: p.x, y: p.y) {
                    brightnesses.append((d, value))
                }
                d += step
            }
            XCTAssertGreaterThan(brightnesses.count, 40, "not enough samples along the shadow")

            // The edge is the steepest brightness rise: shadowed turf to lit
            // turf. Taking the maximum gradient rather than a fixed threshold
            // keeps this independent of exposure and sky colour.
            var edgeDistance: Double?
            var steepest = 0.0
            for i in 1..<brightnesses.count {
                let rise = brightnesses[i].value - brightnesses[i - 1].value
                if rise > steepest {
                    steepest = rise
                    edgeDistance = (brightnesses[i].distance + brightnesses[i - 1].distance) / 2
                }
            }

            let measured = try XCTUnwrap(edgeDistance,
                                         "no shadow edge found at azimuth \(azimuth)")
            XCTAssertGreaterThan(steepest, 0.05,
                                 "the edge at azimuth \(azimuth) is not a real transition")
            XCTAssertEqual(measured, analyticDistance,
                           accuracy: Self.toleranceMetres,
                           """
                           rendered shadow tip disagrees with the analytic solution \
                           at azimuth \(azimuth)°: measured \(String(format: "%.3f", measured)) m, \
                           computed \(String(format: "%.3f", analyticDistance)) m
                           """)
        }
    }

    /// The shadow must also lie in the right *direction*, not merely the right
    /// distance — a sign error would keep the length and lose the calendar.
    @MainActor
    func testShadowFallsOnTheOppositeSideFromTheSun() async throws {
        let device = try makeDevice()
        let stone = Stone(id: "gnomon", position: .zero, height: 6, width: 1.2, thickness: 1.2)
        let scene = MonumentScene(state: .asItWas, stones: [stone])

        let sun = HorizontalCoordinate(altitude: Angle(degrees: 35),
                                       azimuth: Angle(degrees: 90))   // due east
        let renderer = try makeOverheadRenderer(device: device, sun: sun, scene: scene)
        let pixels = readPixels(try renderer.renderOffscreen(width: Self.imageSize,
                                                             height: Self.imageSize))
        let pixel = pixelMapper(renderer)

        // 4 m west of the stone should be in shadow; 4 m east should be lit.
        let westPixel = pixel(SIMD2(-4, 0))
        let eastPixel = pixel(SIMD2(4, 0))
        let west = try XCTUnwrap(luminance(pixels, x: westPixel.x, y: westPixel.y))
        let east = try XCTUnwrap(luminance(pixels, x: eastPixel.x, y: eastPixel.y))
        XCTAssertLessThan(west, east,
                          "with the sun in the east the shadow must fall to the west")
        XCTAssertGreaterThan(east - west, 0.05, "shadow and lit ground must be distinguishable")
    }

    /// When the sun is below the horizon nothing should be lit — and no shadow
    /// should be drawn to infinity.
    @MainActor
    func testNightRendersWithoutSunlight() async throws {
        let device = try makeDevice()
        let scene = MonumentScene.milestoneOne(state: .asItWas)
        let sun = HorizontalCoordinate(altitude: Angle(degrees: -8),
                                       azimuth: Angle(degrees: 300))

        let renderer = try makeOverheadRenderer(device: device, sun: sun, scene: scene)
        let pixels = readPixels(try renderer.renderOffscreen(width: Self.imageSize,
                                                             height: Self.imageSize))

        var total = 0.0
        var count = 0
        for y in stride(from: 0, to: Self.imageSize, by: 8) {
            for x in stride(from: 0, to: Self.imageSize, by: 8) {
                if let value = luminance(pixels, x: x, y: y) { total += value; count += 1 }
            }
        }
        let mean = total / Double(max(count, 1))
        XCTAssertLessThan(mean, 0.25, "the ground should be dark when the sun has set")
    }
}

/// The renderer's own plumbing, checked without reference to what it draws.
final class RendererSetupTests: XCTestCase {

    @MainActor
    func testShadersCompile() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; shader compilation is unverified here.")
        }
        // Compiling from source at load is a deliberate choice (FACTORY.md);
        // this is the test that keeps it honest, because a syntax error in the
        // shader would otherwise only surface at runtime on a device.
        let library = try HengeRenderer.makeLibrary(device: device)
        for function in ["scene_vertex", "scene_fragment", "shadow_vertex",
                         "sky_vertex", "sky_fragment"] {
            XCTAssertNotNil(library.makeFunction(name: function), "missing \(function)")
        }
    }

    /// Swift and MSL agree on struct layout by hand, so a size change on one
    /// side without the other is exactly the bug this catches.
    func testUniformLayoutsAreTheExpectedSize() {
        // 7 matrices × 64 bytes + 5 float4s × 16 bytes = 528.
        XCTAssertEqual(MemoryLayout<FrameUniforms>.size, 7 * 64 + 5 * 16)
        XCTAssertEqual(MemoryLayout<DrawUniforms>.size, 2 * 64 + 16)
        XCTAssertEqual(MemoryLayout<MeshVertex>.stride, 32)
    }

    func testProjectionMapsNearPlaneToZeroAndFarToOne() {
        // Metal's clip space is 0...1 in z, not -1...1. Getting this wrong
        // yields a plausible picture over a useless depth buffer.
        let projection = MetalMath.perspective(fovyRadians: 1, aspect: 1.5, near: 0.5, far: 100)
        let near = projection * SIMD4<Float>(0, 0, -0.5, 1)
        let far = projection * SIMD4<Float>(0, 0, -100, 1)
        XCTAssertEqual(near.z / near.w, 0, accuracy: 1e-4)
        XCTAssertEqual(far.z / far.w, 1, accuracy: 1e-4)
    }

    func testOrbitCameraUsesTheAstronomicalAzimuthConvention() {
        // Azimuth 90° is east, so the camera should stand to the east (+X).
        let east = Camera.orbiting(distance: 10, azimuthDegrees: 90, elevationDegrees: 0,
                                   target: .zero)
        XCTAssertEqual(east.position.x, 10, accuracy: 1e-4)
        XCTAssertEqual(east.position.z, 0, accuracy: 1e-4)

        // Azimuth 0° is north, which is −Z.
        let north = Camera.orbiting(distance: 10, azimuthDegrees: 0, elevationDegrees: 0,
                                    target: .zero)
        XCTAssertEqual(north.position.z, -10, accuracy: 1e-4)
    }
}

extension ShadowAgreementTests {

    /// How far a ray from the origin travels before leaving a convex polygon.
    ///
    /// This is the analytic answer to the question the pixel walk asks: along
    /// this bearing, where does the shadow end?
    static func rayExitDistance(polygon: [SIMD2<Double>],
                                direction: SIMD2<Double>) -> Double? {
        guard polygon.count >= 3 else { return nil }
        var farthest: Double?

        for i in polygon.indices {
            let a = polygon[i]
            let b = polygon[(i + 1) % polygon.count]
            let edge = b - a

            // Solve origin + t·direction = a + u·edge for t, with 0 ≤ u ≤ 1.
            let denominator = direction.x * edge.y - direction.y * edge.x
            guard abs(denominator) > 1e-12 else { continue }

            let t = (a.x * edge.y - a.y * edge.x) / denominator
            let u = (a.x * direction.y - a.y * direction.x) / denominator
            guard t > 0, u >= 0, u <= 1 else { continue }

            if farthest == nil || t > farthest! { farthest = t }
        }
        return farthest
    }
}
