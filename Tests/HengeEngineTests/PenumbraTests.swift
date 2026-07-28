import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The sun is not a point, and the shadows have to know it.
///
/// PCSS replaced a fixed 3×3 filter, and the claim it makes is physical: the
/// softness of a shadow edge is set by how far its caster stands above the
/// ground, times the sun's angular diameter. A tuned blur cannot make that
/// claim and could not be tested. This can, so it is.
@MainActor
final class PenumbraTests: XCTestCase {

    static let imageSize = 512
    /// **Twelve metres, not a hundred and twenty.** The first version of this
    /// suite framed the whole shadow, which put one pixel at 0.23 m — and the
    /// penumbra being measured is around 0.17 m. Every reading came back as the
    /// same three pixels regardless of the sun's size, which looked like PCSS
    /// not working and was in fact the ruler being coarser than the thing
    /// measured. The camera now frames the shadow *tip*, where the edge is.
    static let groundExtent = 12.0

    private func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("""
                No Metal device here, so the penumbra claim is unverified in \
                this environment. A skip, not a pass.
                """)
        }
        return device
    }

    /// One upright of known height, alone on the plain, lit from due east.
    private func render(stoneHeight: Double, sunAltitude: Double,
                        sunAngularRadius: Double = 0.00465) throws -> [UInt8] {
        let device = try makeDevice()
        let stone = Stone(id: "probe", position: SIMD3(0, 0, 0),
                          height: stoneHeight, width: 2.0, thickness: 1.2,
                          material: .sarsen)
        let scene = MonumentScene(stones: [stone])

        // Frame the analytic tip: the sun sits due east, so the shadow runs
        // west along −X, and the tip is height/tan(altitude) out.
        let tipX = Float(-stoneHeight / tan(sunAltitude * .pi / 180))
        // Twenty metres up, not a hundred and twenty. Cascade selection is by
        // *view* depth, so a high camera puts the ground in cascade 2 — where
        // one shadow texel covers about 0.2 m and a four-centimetre penumbra
        // cannot be represented at all. Both stone heights then clamped to the
        // texel floor and read identically, which looked like PCSS ignoring the
        // blocker distance and was really the shadow map being too coarse to
        // hold the answer. Inside cascade 0 a texel is about 1.4 cm.
        var camera = Camera(position: SIMD3(tipX, 20, 0.001),
                            target: SIMD3(tipX, 0, 0))
        camera.fieldOfView = 2 * atan(Float(Self.groundExtent / 2) / camera.position.y)
        camera.near = 1
        camera.far = 200

        let sun = HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                       azimuth: Angle(degrees: 90))
        let state = SceneState(sun: sun, sunAngularRadius: sunAngularRadius,
                               camera: camera, turbidity: 2.2, exposure: 1.0,
                               surfaceTexturing: false)
        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 2048)
        try renderer.load(scene: scene, subdivisions: 8, roughness: 0, rounding: 0)

        let texture = try renderer.renderOffscreen(width: Self.imageSize, height: Self.imageSize)
        var pixels = [UInt8](repeating: 0, count: Self.imageSize * Self.imageSize * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.imageSize * 4,
                             from: MTLRegionMake2D(0, 0, Self.imageSize, Self.imageSize),
                             mipmapLevel: 0)
        }
        return pixels
    }

    private func luminance(_ pixels: [UInt8], x: Int, y: Int) -> Double {
        let offset = (y * Self.imageSize + x) * 4
        let b = Double(pixels[offset]), g = Double(pixels[offset + 1])
        let r = Double(pixels[offset + 2])
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
    }

    /// Width of the shadow's leading edge, in metres, measured along the
    /// image row through the stone's base.
    ///
    /// Scans away from the stone until the ground is fully lit, then measures
    /// how many pixels the transition took between 20% and 80% of the swing.
    /// Returns nil if no edge was found — the caller asserts on that rather
    /// than quietly treating "no shadow" as "sharp shadow".
    private func edgeWidthMetres(_ pixels: [UInt8]) -> Double? {
        let row = Self.imageSize / 2
        let metresPerPixel = Self.groundExtent / Double(Self.imageSize)

        // Sample the whole row; the shadow runs west, so scan from the middle
        // outward in both directions and take whichever side has the edge.
        for direction in [-1, 1] {
            var samples: [Double] = []
            var x = Self.imageSize / 2
            while x > 4 && x < Self.imageSize - 4 {
                samples.append(luminance(pixels, x: x, y: row))
                x += direction
            }
            guard let dark = samples.min(), let bright = samples.max(),
                  bright - dark > 0.05 else { continue }

            let low = dark + 0.2 * (bright - dark)
            let high = dark + 0.8 * (bright - dark)
            guard let lowIndex = samples.firstIndex(where: { $0 >= low }),
                  let highIndex = samples.firstIndex(where: { $0 >= high }),
                  highIndex > lowIndex else { continue }
            return Double(highIndex - lowIndex) * metresPerPixel
        }
        return nil
    }

    /// **The physical claim.** A shadow thrown further is a shadow with a
    /// softer edge, because the blocker is further from the ground it darkens.
    /// Same stone, two sun heights.
    func testALongerShadowHasASofterEdge() throws {
        let high = try XCTUnwrap(edgeWidthMetres(render(stoneHeight: 4.0, sunAltitude: 55)),
                                 "no edge found with a high sun")
        let low = try XCTUnwrap(edgeWidthMetres(render(stoneHeight: 4.0, sunAltitude: 12)),
                                "no edge found with a low sun")

        XCTAssertGreaterThan(low, high * 1.5,
                             "12° sun: \(low) m edge; 55° sun: \(high) m edge")
    }

    /// A taller stone throws its shadow further and softens it the same way.
    ///
    /// Both heights are chosen so the tip lands clear of the stone's own
    /// footprint. A 1.5 m stone at 20° tips only 4.1 m out, which leaves the
    /// stone inside the twelve-metre frame and lets the scan measure the
    /// stone's own shading instead of the shadow edge — it read 1.99 m, wider
    /// than a 6 m stone's, which is how the framing error announced itself.
    func testATallerStoneSoftensItsOwnShadow() throws {
        let short = try XCTUnwrap(edgeWidthMetres(render(stoneHeight: 3.0, sunAltitude: 20)))
        let tall = try XCTUnwrap(edgeWidthMetres(render(stoneHeight: 6.0, sunAltitude: 20)))
        XCTAssertGreaterThan(tall, short,
                             "6 m stone: \(tall) m edge; 3 m stone: \(short) m edge")
    }

    /// **Nothing here is a tuned constant.** Quadruple the sun's angular size
    /// and the penumbra must widen with it. A fixed blur radius would not move.
    func testTheSoftnessFollowsTheSunsAngularSize() throws {
        let real = try XCTUnwrap(edgeWidthMetres(
            render(stoneHeight: 5.0, sunAltitude: 15, sunAngularRadius: 0.00465)))
        let swollen = try XCTUnwrap(edgeWidthMetres(
            render(stoneHeight: 5.0, sunAltitude: 15, sunAngularRadius: 0.00465 * 4)))

        XCTAssertGreaterThan(swollen, real * 1.4,
                             "0.53° sun: \(real) m; 2.1° sun: \(swollen) m")
    }

    /// And the width is roughly right, not merely ordered. A 5 m stone at 15°
    /// throws its tip about 18.7 m out; at 0.53° that tip's penumbra is around
    /// 0.17 m across, widened by the grazing angle. Generous bounds — the
    /// point is the order of magnitude, since anything tighter would be
    /// measuring the filter's tap pattern rather than the physics.
    func testTheEdgeWidthIsPhysicallyPlausible() throws {
        let width = try XCTUnwrap(edgeWidthMetres(
            render(stoneHeight: 5.0, sunAltitude: 15)))
        XCTAssertGreaterThan(width, 0.05, "\(width) m — too sharp for a 0.53° sun")
        XCTAssertLessThan(width, 4.0, "\(width) m — far too soft")
    }
}
