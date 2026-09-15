import XCTest
import HengeAstro
@testable import HengeGeometry

/// What the zodiac-only sky keeps, checked against published HIP numbers
/// rather than against the figure table that defines it.
final class ZodiacStarsTests: XCTestCase {

    func testTheZodiacIsTwelveFiguresAndTheSameTwelveTheGlyphsUse() {
        let figures = ConstellationFigure.all.filter(\.isZodiacal).map(\.name)
        XCTAssertEqual(figures.count, 12)
        XCTAssertEqual(Set(figures), Set(ZodiacConstellation.all.map(\.name)))
    }

    func testTheBrightStarsOfTheZodiacAreKept() {
        // Aldebaran (Taurus), Pollux (Gemini), Regulus (Leo), Spica (Virgo),
        // Antares (Scorpius) — Hipparcos numbers from the catalogue.
        for hip in [21421, 37826, 49669, 65474, 80763] {
            XCTAssertTrue(ConstellationFigure.zodiacHIPs.contains(hip), "HIP \(hip)")
        }
    }

    func testTheFamousStarsOutsideItGoDark() {
        // Sirius, Vega, Polaris, Betelgeuse: every one drawn in a figure,
        // none of them in the zodiac.
        for hip in [32349, 91262, 11767, 27989] {
            XCTAssertFalse(ConstellationFigure.zodiacHIPs.contains(hip), "HIP \(hip)")
        }
    }

    func testTheCatalogueKeepsAStripNotASky() throws {
        let catalog = try XCTUnwrap(StarCatalog.load())
        let kept = catalog.zodiacIndices
        XCTAssertGreaterThan(kept.count, 30, "twelve figures need a few dozen stars")
        XCTAssertLessThan(kept.count, catalog.entries.count / 20,
                          "the zodiac is a strip; it must be a small fraction of 8,870")
        for index in kept {
            XCTAssertTrue(ConstellationFigure.zodiacHIPs.contains(catalog.entries[index].hip))
        }
    }
}
