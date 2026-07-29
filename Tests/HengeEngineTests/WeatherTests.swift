import XCTest
import Metal
@testable import HengeEngine
import HengeAstro
import HengeGeometry

/// The weather's decisions, held where they are made — on the CPU.
final class WeatherModelTests: XCTestCase {

    func testClearIsExactlyNothing() {
        // The default condition must contribute zero to every channel: the
        // shadow-agreement oracle renders under it, and "almost nothing"
        // would be fog on the instrument.
        XCTAssertEqual(Weather.clear.cloudCover, 0)
        XCTAssertEqual(Weather.clear.sunTransmission, 1)
        XCTAssertEqual(Weather.clear.wetness, 0)
        XCTAssertEqual(Weather.frostAmount(condition: .clear,
                                           sunAltitudeDegrees: -10), 0)
    }

    func testTheWeatherDimsInTheRightOrder() {
        XCTAssertLessThan(Weather.rain.sunTransmission,
                          Weather.overcast.sunTransmission,
                          "rain is thicker weather than plain overcast")
        XCTAssertLessThan(Weather.overcast.sunTransmission, 1)
        XCTAssertEqual(Weather.frost.sunTransmission, 1,
                       "a frost morning froze because its sky was clear")
        XCTAssertGreaterThan(Weather.rain.cloudCover,
                             Weather.frost.cloudCover)
    }

    func testFrostMeltsAsTheSunClimbs() {
        XCTAssertEqual(Weather.frostAmount(condition: .frost,
                                           sunAltitudeDegrees: -5), 1,
                       "the night's frost is whole")
        XCTAssertEqual(Weather.frostAmount(condition: .frost,
                                           sunAltitudeDegrees: 8), 0.5,
                       accuracy: 1e-9, "half gone at the melt ramp's midpoint")
        XCTAssertEqual(Weather.frostAmount(condition: .frost,
                                           sunAltitudeDegrees: 20), 0,
                       "melted by mid-morning")
        var previous = 1.0
        for altitude in stride(from: 4.0, through: 12.0, by: 0.5) {
            let amount = Weather.frostAmount(condition: .frost,
                                             sunAltitudeDegrees: altitude)
            XCTAssertLessThanOrEqual(amount, previous, "frost refroze at \(altitude)°")
            previous = amount
        }
    }

    func testOnlyRainWetsTheWorld() {
        for condition in Weather.allCases {
            XCTAssertEqual(condition.wetness, condition == .rain ? 1 : 0,
                           "\(condition.rawValue)")
        }
    }
}

/// The weather in pixels: the overcast sky mottles and dims, rain darkens
/// the stone, frost pales its crown — and clear weather is byte-identical
/// to weather nobody set.
@MainActor
final class WeatherRenderTests: XCTestCase {

    static let size = 192

    private func frame(weather: Weather, sunAltitude: Double = 35) throws -> [Double] {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device; the weather is unverified here.")
        }
        let stone = Stone(id: "weather-probe", position: .zero,
                          height: 5, width: 2.2, thickness: 1.1,
                          bearing: Angle(degrees: 180))
        var camera = Camera(position: SIMD3(0, 2.5, 10), target: SIMD3(0, 2.5, 0))
        camera.near = 0.3
        var state = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: sunAltitude),
                                                         azimuth: Angle(degrees: 200)),
                               camera: camera, grassBlades: false)
        state.weather = weather

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

    private func mean(_ luminance: [Double], rows: Range<Int>,
                      columns: Range<Int>) -> Double {
        var total = 0.0; var count = 0
        for y in rows { for x in columns {
            total += luminance[y * Self.size + x]; count += 1
        } }
        return total / Double(max(count, 1))
    }

    /// Two claims, honestly separated — the review caught the first draft
    /// naming a variable `unset` while setting it, and testing nothing but
    /// determinism under a claim about defaults.
    func testTheDefaultWeatherIsClearAndClearIsDeterministic() throws {
        // The default itself, pinned: the shadow-agreement oracle renders
        // whatever this is, so a drifted default would dress the instrument.
        let fresh = SceneState(sun: HorizontalCoordinate(altitude: Angle(degrees: 30),
                                                         azimuth: .zero))
        XCTAssertEqual(fresh.weather, .clear,
                       "SceneState's default weather must stay clear — the "
                       + "oracle's frames depend on it")

        // And determinism, which the rest of this suite stands on.
        let first = try frame(weather: .clear)
        let second = try frame(weather: .clear)
        XCTAssertEqual(zip(first, second).filter { $0 != $1 }.count, 0,
                       "two clear frames differ — nothing below can be trusted")
    }

    func testTheOvercastSkyIsGreyAndTheLightIsFlat() throws {
        let clear = try frame(weather: .clear)
        let overcast = try frame(weather: .overcast)
        // Sky band, upper quarter of the frame.
        let skyRows = (Self.size / 16)..<(Self.size / 4)
        let clearSky = mean(clear, rows: skyRows, columns: 0..<Self.size)
        let greySky = mean(overcast, rows: skyRows, columns: 0..<Self.size)
        XCTAssertGreaterThan(abs(greySky - clearSky), 4,
                             "the deck changed the sky by almost nothing")

        // The stone's lit face: with 68% of the sun gone, the direct light
        // falls far more than the ambient — flat light, the overcast look.
        let stoneRows = (Self.size * 5 / 12)..<(Self.size * 7 / 12)
        let stoneColumns = (Self.size * 5 / 12)..<(Self.size * 7 / 12)
        let clearStone = mean(clear, rows: stoneRows, columns: stoneColumns)
        let dimStone = mean(overcast, rows: stoneRows, columns: stoneColumns)
        XCTAssertLessThan(dimStone, clearStone * 0.85,
                          "the stone barely dimmed under a closed deck: "
                          + "\(dimStone) against \(clearStone)")
    }

    func testRainSoaksTheStoneDark() throws {
        let clear = try frame(weather: .clear)
        let rain = try frame(weather: .rain)
        let stoneRows = (Self.size * 5 / 12)..<(Self.size * 7 / 12)
        let stoneColumns = (Self.size * 5 / 12)..<(Self.size * 7 / 12)
        let dry = mean(clear, rows: stoneRows, columns: stoneColumns)
        let wet = mean(rain, rows: stoneRows, columns: stoneColumns)
        // Rain dims the sun AND soaks the surface; the claim here is the
        // soak specifically, so the threshold was calibrated by mutation:
        // with the two soak terms deleted from the shader, rain's stone
        // measures 0.70 of overcast's (the transmission gap alone); with
        // them, 0.50. The 0.60 threshold sits between with margin both
        // ways — the review proved the first threshold (0.92) passed with
        // the soak deleted, which made the test a decoration.
        let overcast = try frame(weather: .overcast)
        let dim = mean(overcast, rows: stoneRows, columns: stoneColumns)
        XCTAssertLessThan(wet, dim * 0.60,
                          "rain-soaked stone (\(wet)) should sit clearly below "
                          + "merely-overcast stone (\(dim)) — below what the "
                          + "transmission gap alone explains")
        XCTAssertLessThan(wet, dry * 0.6, "and far below dry (\(dry))")
    }

    func testFrostPalesTheGroundAndMeltsByNoon() throws {
        // Early morning: sun at 6°, frost still 84% whole by the melt curve.
        // The rime lives on upward faces, and the broadest upward face in
        // any frame is the turf itself — the first version measured the
        // stone's *vertical* face and the rime was rightly not there; the
        // second measured at a 2° sun, where the turf renders at three
        // luminance levels and nothing can show against it.
        let clearDawn = try frame(weather: .clear, sunAltitude: 6)
        let frostDawn = try frame(weather: .frost, sunAltitude: 6)
        let groundRows = (Self.size * 12 / 16)..<(Self.size * 15 / 16)
        let flanks = (Self.size / 16)..<(Self.size * 4 / 16)
        let bare = mean(clearDawn, rows: groundRows, columns: flanks)
        let rimed = mean(frostDawn, rows: groundRows, columns: flanks)
        // A 6° sun keeps early-morning turf at single-digit luminance, so
        // the claim is relative: the rime must lift the band by a clear
        // third. The floor guards only against a black frame.
        XCTAssertGreaterThan(bare, 3,
                             "the morning turf is too dark for this test to mean anything")
        XCTAssertGreaterThan(rimed, bare * 1.33,
                             "the frosted turf (\(rimed)) should stand clearly pale "
                             + "against the bare (\(bare))")

        // High sun: the frost has melted; the frames agree.
        let clearNoon = try frame(weather: .clear, sunAltitude: 45)
        let frostNoon = try frame(weather: .frost, sunAltitude: 45)
        XCTAssertEqual(zip(clearNoon, frostNoon).filter { $0 != $1 }.count, 0,
                       "at 45° the frost must be gone to the last texel — "
                       + "the melt curve reaches exactly zero")
    }
}
