import XCTest
@testable import HengeAstro

/// The glyphs shown for phases and events, pinned to their meanings. The
/// mapping lives in `HengeAstro` precisely so this file can exist: a waxing
/// moon drawn with a waning glyph would pass every rendering test and still
/// be wrong in the way a calendar must never be.
final class SymbolTests: XCTestCase {

    private func phase(age: Double) -> LunarPhase {
        LunarPhase(illuminatedFraction: 0.5, phaseAngle: Angle(degrees: 90), age: age)
    }

    func testPhaseGlyphsAgreeWithTheirNames() {
        // One probe per band, at its centre. The claim is agreement between
        // the word and the shape, both driven by the same age.
        let expectations: [(age: Double, name: String, symbol: String)] = [
            (0.9, "New", "moonphase.new.moon"),
            (3.7, "Waxing crescent", "moonphase.waxing.crescent"),
            (7.4, "First quarter", "moonphase.first.quarter"),
            (11.0, "Waxing gibbous", "moonphase.waxing.gibbous"),
            (14.8, "Full", "moonphase.full.moon"),
            (18.5, "Waning gibbous", "moonphase.waning.gibbous"),
            (22.2, "Last quarter", "moonphase.last.quarter"),
            (25.9, "Waning crescent", "moonphase.waning.crescent")
        ]
        for expected in expectations {
            let probe = phase(age: expected.age)
            XCTAssertEqual(probe.name, expected.name)
            XCTAssertEqual(probe.symbolName, expected.symbol,
                           "at age \(expected.age) the glyph must show a "
                           + "\(expected.name.lowercased()) moon")
        }
    }

    func testEventGlyphsMatchTheirKind() {
        XCTAssertEqual(EventKind.fullMoon.symbolName, "moonphase.full.moon")
        XCTAssertEqual(EventKind.newMoon.symbolName, "moonphase.new.moon")
        XCTAssertEqual(EventKind.firstQuarter.symbolName, "moonphase.first.quarter")
        XCTAssertEqual(EventKind.lastQuarter.symbolName, "moonphase.last.quarter")
        XCTAssertEqual(EventKind.standstill(major: true).symbolName, "arrow.up.to.line")
        XCTAssertEqual(EventKind.standstill(major: false).symbolName, "arrow.down.to.line")
        XCTAssertNil(EventKind.station(.juneSolstice).symbolName,
                     "festivals carry names, not shapes")
    }
}
