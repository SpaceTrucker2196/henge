import XCTest
import Metal
import simd
import HengeAstro
import HengeGeometry
@testable import HengeEngine

/// The shadow cascades are refitted only when something they see has moved
/// enough to matter — and a monument arriving is that. The app builds the
/// scene off the main actor and lands it through `load(prepared:)`, which
/// is the path this pins: a viewer holding perfectly still after the load
/// must still get shadows under the new stones on the next frame.
final class CascadeRefitTests: XCTestCase {

    private func makeDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device on this machine; the renderer cannot be built here.")
        }
        return device
    }

    @MainActor
    func testALoadedMonumentRefitsTheCascades() throws {
        let device = try makeDevice()
        let camera = Camera(position: SIMD3(0, 3, 30), target: SIMD3(0, 3, 0))
        let state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: 40),
                                                         azimuth: Angle(degrees: 160)),
                               camera: camera, grassBlades: false)
        let renderer = try HengeRenderer(device: device, state: state, shadowResolution: 256)

        // First frame fits; a second identical frame keeps the fit.
        _ = renderer.buildFrameUniforms(aspect: 1.5)
        XCTAssertTrue(renderer.shadowPassNeeded)
        _ = renderer.buildFrameUniforms(aspect: 1.5)
        XCTAssertFalse(renderer.shadowPassNeeded)

        // The monument lands by the app's path: prepared off the actor,
        // then loaded. Nothing else has moved.
        let stone = Stone(id: "arrival", position: .zero, height: 6,
                          width: 3, thickness: 1.6, bearing: Angle(degrees: 0))
        let prepared = HengeRenderer.prepare(scene: MonumentScene(state: .asItWas, stones: [stone]),
                                             terrain: renderer.terrain, soilBanks: false,
                                             subdivisions: 6, roughness: 0, rounding: 0)
        try renderer.load(prepared: prepared)
        _ = renderer.buildFrameUniforms(aspect: 1.5)
        XCTAssertTrue(renderer.shadowPassNeeded,
                      "the cascades still hold the empty plain after the monument arrived")

        // And it is a one-frame event, not a permanent refit.
        _ = renderer.buildFrameUniforms(aspect: 1.5)
        XCTAssertFalse(renderer.shadowPassNeeded)
    }
}
