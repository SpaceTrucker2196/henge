import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The ceremony torch's arithmetic — the parts a test can hold without a GPU.
final class TorchIntensityTests: XCTestCase {

    func testTheTorchBelongsToTheNight() {
        // Full strength below the horizon, nothing by mid-morning. The gate
        // runs −1° to 6°, a Hermite ramp, so its midpoint 2.5° gives half.
        let flickerless = { (altitude: Double) in
            SceneState.torchIntensity(sunAltitudeDegrees: altitude, flickerAt: 0)
        }
        XCTAssertEqual(flickerless(40), 0)
        XCTAssertEqual(flickerless(6), 0)
        XCTAssertEqual(flickerless(2.5) / flickerless(-10), 0.5, accuracy: 1e-9)
        XCTAssertEqual(flickerless(-1), flickerless(-30),
                       "below the gate the night is fully dark and the torch fully lit")
    }

    func testTheGateFadesMonotonely() {
        var previous = SceneState.torchIntensity(sunAltitudeDegrees: -1, flickerAt: 0)
        for step in stride(from: -0.9, through: 6.0, by: 0.1) {
            let value = SceneState.torchIntensity(sunAltitudeDegrees: step, flickerAt: 0)
            XCTAssertLessThanOrEqual(value, previous + 1e-12,
                                     "the dusk fade brightened at \(step)°")
            previous = value
        }
    }

    func testTheFlameGuttersButNeverGoesOut() {
        var seen: Set<Int> = []
        for tick in 0..<2000 {
            let flicker = SceneState.torchFlicker(at: Double(tick) * 0.031)
            XCTAssertGreaterThan(flicker, 0.79,
                                 "the flame went out at t=\(Double(tick) * 0.031)")
            XCTAssertLessThan(flicker, 1.11, "the flame flared past its bound")
            seen.insert(Int(flicker * 1000))
        }
        XCTAssertGreaterThan(seen.count, 50, "a flame this steady is a lamp")
    }

    func testTheFlickerIsDeterministic() {
        XCTAssertEqual(SceneState.torchFlicker(at: 12.34),
                       SceneState.torchFlicker(at: 12.34))
    }
}

/// The torch in pixels: it lights the near stone at night, leaves the far
/// field alone, and at noon leaves the frame byte-identical — the night gate
/// is exactly zero there, so the shader's term is absent, not merely faint.
@MainActor
final class TorchRenderTests: XCTestCase {

    static let size = 192

    private func frame(sunAltitude: Double, torch: Bool) throws -> [Double] {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the torch is unverified here.")
        }
        // A stone three metres ahead of the viewer, new-moon night or day.
        let stone = Stone(id: "torch-probe", position: SIMD3(0, 0, -3),
                          height: 4, width: 2, thickness: 1,
                          bearing: Angle(degrees: 180))
        var camera = Camera(position: SIMD3(0, 1.7, 1.5), target: SIMD3(0, 1.7, -3))
        camera.near = 0.3
        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                                         azimuth: Angle(degrees: 300)),
                               camera: camera, grassBlades: false)
        state.torchlight = torch

        let renderer = try HengeRenderer(device: device, state: state,
                                         shadowResolution: 512)
        try renderer.load(scene: MonumentScene(stones: [stone]))
        let texture = try renderer.renderOffscreen(width: Self.size, height: Self.size)
        var pixels = [UInt8](repeating: 0, count: Self.size * Self.size * 4)
        pixels.withUnsafeMutableBytes { raw in
            texture.getBytes(raw.baseAddress!, bytesPerRow: Self.size * 4,
                             from: MTLRegionMake2D(0, 0, Self.size, Self.size),
                             mipmapLevel: 0)
        }
        return pixels.indices.compactMap { i -> Double? in
            guard i % 4 == 0 else { return nil }
            return 0.2126 * Double(pixels[i + 2]) + 0.7152 * Double(pixels[i + 1])
                 + 0.0722 * Double(pixels[i])
        }
    }

    private func centrePatchMean(_ luminance: [Double]) -> Double {
        var total = 0.0
        var count = 0
        for y in (Self.size * 3 / 8)..<(Self.size * 5 / 8) {
            for x in (Self.size * 3 / 8)..<(Self.size * 5 / 8) {
                total += luminance[y * Self.size + x]
                count += 1
            }
        }
        return total / Double(count)
    }

    func testTheTorchLightsTheNearStoneAtNight() throws {
        let dark = try frame(sunAltitude: -25, torch: false)
        let lit = try frame(sunAltitude: -25, torch: true)
        let before = centrePatchMean(dark)
        let after = centrePatchMean(lit)
        XCTAssertLessThan(before, 40, "the moonless night is too bright to measure a torch in")
        XCTAssertGreaterThan(after - before, 25,
                             "the stone face three metres away gained only "
                             + "\(after - before) levels — that is no ceremony")
    }

    func testTheTorchAtNoonChangesNothing() throws {
        let plain = try frame(sunAltitude: 45, torch: false)
        let carried = try frame(sunAltitude: 45, torch: true)
        XCTAssertEqual(zip(plain, carried).filter { $0 != $1 }.count, 0,
                       "the noon frame changed with the torch lit — the night "
                       + "gate is meant to make this exactly zero, not merely dim")
    }
}
