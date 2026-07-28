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
                               camera: camera, turbidity: 2.2, exposure: 1.0,
                               surfaceTexturing: false, grassBlades: false)
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
        // 7 matrices × 64 bytes + 9 float4s × 16 bytes: the last two are
        // `cascadeRadii` (PCSS), `wind` and `grass`. This assertion has now caught three
        // separate field additions, which is the whole reason it is written as
        // arithmetic rather than a magic number — adding a field on one side
        // only silently reinterprets every uniform after it, and the result is
        // a plausible-looking render rather than a crash.
        XCTAssertEqual(MemoryLayout<FrameUniforms>.size, 7 * 64 + 10 * 16)
        // 2 matrices + albedo + `surface` (which map set, tile size, normal
        // strength) + `weather` (the stone's foot, lichen, damp, seed)
        // + `reflectance` (specular strength, roughness floor, takes wind).
        XCTAssertEqual(MemoryLayout<DrawUniforms>.size, 2 * 64 + 4 * 16)
        XCTAssertEqual(MemoryLayout<MeshVertex>.stride, 32)
    }

    /// Reverse-Z: the near plane maps to 1 and distance tends to 0.
    ///
    /// Conventional depth spends nearly all its precision in the first few
    /// metres, and with a horizon 15 km out that left two faces of the same
    /// stone sharing a depth bucket at sixty metres — the walls flickered away
    /// at some angles, which reads as transparency rather than as z-fighting.
    func testProjectionIsReverseZ() {
        let projection = MetalMath.perspective(fovyRadians: 1, aspect: 1.5, near: 0.5)
        let near = projection * SIMD4<Float>(0, 0, -0.5, 1)
        let mid = projection * SIMD4<Float>(0, 0, -60, 1)
        let far = projection * SIMD4<Float>(0, 0, -15_000, 1)

        XCTAssertEqual(near.z / near.w, 1, accuracy: 1e-4, "the near plane is 1")
        XCTAssertLessThan(far.z / far.w, mid.z / mid.w, "further is smaller")
        XCTAssertGreaterThan(far.z / far.w, 0)

        // The point of it: two surfaces a metre apart at sixty metres must
        // remain distinguishable, which is what failed before.
        let front = projection * SIMD4<Float>(0, 0, -60, 1)
        let back = projection * SIMD4<Float>(0, 0, -61, 1)
        let separation = abs(front.z / front.w - back.z / back.w)
        XCTAssertGreaterThan(separation, 1e-5,
                             "a metre of stone at sixty metres must survive the depth buffer")
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

/// Is the stone opaque once it is actually drawn?
///
/// The mesh is provably watertight (`SolidityTests`), but that is not enough:
/// culling draws only one side of each triangle, and if the renderer's idea of
/// which side is front disagrees with the mesh's, every face vanishes and the
/// scene is drawn from the inside out. The mesh would still be perfect and the
/// stone would still be full of holes.
///
/// This settles it by rendering the same view twice — once with the stone and
/// once without — and flood-filling the untouched pixels inward from the frame
/// edge. Any pixel the stone failed to cover, that is nonetheless enclosed by
/// pixels it did cover, is a hole you can see through.
final class OpacityTests: XCTestCase {

    static let size = 384

    @MainActor
    private func render(stones: [Stone], sun: HorizontalCoordinate,
                        bearing: Double, device: MTLDevice) throws -> [UInt8] {
        let camera = Camera.orbiting(distance: 26, azimuthDegrees: Float(bearing),
                                     elevationDegrees: 9,
                                     target: SIMD3<Float>(0, 3.4, 0))
        // Untextured: this suite asks whether the surface has holes in it, and
        // photographic grain would put variation into exactly the pixel
        // comparison that answers it.
        let state = SceneState(sun: sun, camera: camera, turbidity: 2.2, exposure: 1.5,
                               surfaceTexturing: false, grassBlades: false)
        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 1024)
        try renderer.load(scene: MonumentScene(state: .asItWas, stones: stones),
                          subdivisions: 12)
        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)

        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                             mipmapLevel: 0)
        }
        return pixels
    }

    @MainActor
    func testTheStoneIsOpaqueFromEveryBearing() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; opacity is unverified in this environment.")
        }

        let stone = Stone(id: "opaque", position: .zero, height: 6.5,
                          width: 2.4, thickness: 1.1, bearing: Angle(degrees: 49.9))
        let sun = HorizontalCoordinate(altitude: Angle(degrees: 22),
                                       azimuth: Angle(degrees: 300))

        // Includes 320°, where the trilithon is seen along its across-axis and
        // the uprights line up behind one another.
        for bearing in [0.0, 49.9, 140.0, 230.0, 320.0] {
            let withStone = try render(stones: [stone], sun: sun,
                                       bearing: bearing, device: device)
            let empty = try render(stones: [], sun: sun, bearing: bearing, device: device)

            // A pixel the stone changed is a pixel it covered.
            var covered = [Bool](repeating: false, count: Self.size * Self.size)
            var coveredCount = 0
            for i in 0..<(Self.size * Self.size) {
                var difference = 0
                for channel in 0..<3 {
                    difference += abs(Int(withStone[i * 4 + channel]) - Int(empty[i * 4 + channel]))
                }
                // Generous: the stone's shadow also changes pixels, and that is
                // fine — shadow only ever adds to the covered region, which
                // makes this test stricter rather than looser.
                if difference > 2 { covered[i] = true; coveredCount += 1 }
            }
            XCTAssertGreaterThan(coveredCount, 800,
                                 "the stone is barely visible at bearing \(bearing)")

            // Flood fill the uncovered pixels inward from the border.
            var reachable = [Bool](repeating: false, count: Self.size * Self.size)
            var stack: [Int] = []
            for x in 0..<Self.size {
                for index in [x, (Self.size - 1) * Self.size + x] where !covered[index] {
                    if !reachable[index] { reachable[index] = true; stack.append(index) }
                }
            }
            for y in 0..<Self.size {
                for index in [y * Self.size, y * Self.size + Self.size - 1] where !covered[index] {
                    if !reachable[index] { reachable[index] = true; stack.append(index) }
                }
            }
            while let index = stack.popLast() {
                let x = index % Self.size, y = index / Self.size
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, ny >= 0, nx < Self.size, ny < Self.size else { continue }
                    let next = ny * Self.size + nx
                    if !covered[next] && !reachable[next] {
                        reachable[next] = true
                        stack.append(next)
                    }
                }
            }

            let holes = (0..<(Self.size * Self.size)).filter { !covered[$0] && !reachable[$0] }
            XCTAssertLessThan(holes.count, 12,
                              """
                              \(holes.count) enclosed background pixels at bearing \
                              \(bearing)° — the stone is being drawn with holes in it, \
                              which means the renderer and the mesh disagree about which \
                              side of a triangle faces out
                              """)
        }
    }
}

/// Are we looking at the near surface, or through it at the far one?
///
/// The opacity test cannot tell. If the renderer culled front faces and drew
/// back ones, the silhouette would still be completely filled and every
/// coverage check would pass — while what you actually see is the inside of
/// the stone's back wall. Reported as "the surface facing the camera is
/// transparent", which is precisely what that looks like.
///
/// Depth settles it: the value written at the centre of the stone must be the
/// distance to its *near* face.
final class NearSurfaceTests: XCTestCase {

    @MainActor
    func testTheVisibleSurfaceIsTheOneFacingTheCamera() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the visible surface is unverified here.")
        }

        // A stone squarely in front of the camera, at a known distance.
        let thickness = 1.6
        let stone = Stone(id: "near-surface", position: .zero, height: 6,
                          width: 3.0, thickness: thickness,
                          bearing: Angle(degrees: 0))

        let range: Float = 30
        var camera = Camera(position: SIMD3(0, 3, range), target: SIMD3(0, 3, 0))
        camera.near = 0.2
        let state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: 40),
                                                         azimuth: Angle(degrees: 160)),
                               camera: camera,
                                   grassBlades: false)
        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 512)
        try renderer.load(scene: MonumentScene(state: .asItWas, stones: [stone]),
                          subdivisions: 10, roughness: 0, rounding: 0)

        let size = 256
        let rendered = try renderer.renderOffscreen(width: size, height: size, keepDepth: true)
        let depthTexture = try XCTUnwrap(rendered.depth, "depth was not kept")

        var depths = [Float](repeating: 0, count: size * size)
        depths.withUnsafeMutableBytes { raw in
            depthTexture.getBytes(raw.baseAddress!,
                                  bytesPerRow: size * MemoryLayout<Float>.size,
                                  from: MTLRegionMake2D(0, 0, size, size),
                                  mipmapLevel: 0)
        }

        let centre = depths[(size / 2) * size + size / 2]
        XCTAssertGreaterThan(centre, 0,
                             "nothing was drawn at the centre of the frame")

        let measured = HengeRenderer.distance(fromReverseZ: centre, near: camera.near)
        let toNearFace = range - Float(thickness / 2)
        let toFarFace = range + Float(thickness / 2)

        XCTAssertEqual(measured, toNearFace, accuracy: 0.35,
                       """
                       the depth written is \(measured) m, but the near face of the \
                       stone is at \(toNearFace) m and its far face at \(toFarFace) m. \
                       If this reads as the far face, the renderer is culling the \
                       surface that faces the camera and drawing the one behind it — \
                       which looks exactly like the front of the stone being transparent.
                       """)
    }
}
