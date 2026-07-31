import XCTest
@testable import HengeGeometry
import HengeAstro

/// The hand-drawn figures against the catalogue they are drawn on, and
/// against published sky geometry a reader can check with a star atlas.
final class ConstellationLineTests: XCTestCase {

    private static let catalog = StarCatalog.load()

    private func entry(_ hip: Int) throws -> StarCatalog.Entry {
        let catalog = try XCTUnwrap(Self.catalog)
        return try XCTUnwrap(catalog.entries.first { $0.hip == hip },
                             "HIP \(hip) is not in the bundled catalogue")
    }

    /// Great-circle separation from the vendored positions — independent
    /// spherical trigonometry, redoable on paper.
    private func separation(_ a: Int, _ b: Int) throws -> Double {
        let ea = try entry(a), eb = try entry(b)
        let cosine = ea.declination.sine * eb.declination.sine
            + ea.declination.cosine * eb.declination.cosine
            * (ea.rightAscension - eb.rightAscension).cosine
        return acos(min(1, max(-1, cosine))) * 180 / .pi
    }

    // ── the whole register of figures ───────────────────────────────────────

    func testEveryFigureStarIsInTheCatalogueAndNakedEyeBright() throws {
        XCTAssertEqual(ConstellationFigure.all.count, 29)
        for figure in ConstellationFigure.all {
            for segment in figure.segments {
                for hip in [segment.0, segment.1] {
                    let star = try entry(hip)
                    // Figure stars are the sky's bright framework; a sixth
                    // magnitude star in a figure is almost surely a typo'd
                    // identifier that happened to exist.
                    XCTAssertLessThan(star.magnitude, 5.5,
                                      "\(figure.name) joins HIP \(hip) at "
                                      + "magnitude \(star.magnitude)")
                }
            }
        }
    }

    func testEverySegmentIsAShortStroke() throws {
        // Figures join neighbouring stars. The longest honest stroke in
        // this set is Pegasus's square at about 16.5°; anything past 25°
        // means an identifier points at the wrong part of the sky.
        for figure in ConstellationFigure.all {
            for segment in figure.segments {
                let length = try separation(segment.0, segment.1)
                XCTAssertLessThan(length, 25,
                                  "\(figure.name) draws a \(length)° stroke "
                                  + "between HIP \(segment.0) and \(segment.1)")
            }
        }
    }

    // ── published fixtures ──────────────────────────────────────────────────

    func testOrionsBeltIsShortAndStraight() throws {
        // Alnitak–Mintaka is about 2.7° end to end (any atlas), and the
        // belt is famously near-collinear: the two half-strokes must sum
        // to the whole within a twentieth of a degree.
        let alnitak = 26727, alnilam = 26311, mintaka = 25930
        let whole = try separation(alnitak, mintaka)
        let halves = try separation(alnitak, alnilam)
            + separation(alnilam, mintaka)
        XCTAssertEqual(whole, 2.74, accuracy: 0.2)
        XCTAssertEqual(halves, whole, accuracy: 0.05,
                       "the belt should be a straight line of three")
        let orion = try XCTUnwrap(ConstellationFigure.all.first { $0.name == "Orion" })
        XCTAssertTrue(orion.segments.contains { $0 == (alnitak, alnilam) },
                      "Orion's figure must include the belt")
    }

    func testThePloughsHandleMatchesTheAtlas() throws {
        // Mizar to Alkaid: 6.7° in any catalogue.
        XCTAssertEqual(try separation(65378, 67301), 6.7, accuracy: 0.3)
    }

    func testDracoCarriesTheBuildersPoleStar() throws {
        // Thuban is the reason Draco is in this set at all.
        let draco = try XCTUnwrap(ConstellationFigure.all.first { $0.name == "Draco" })
        let stars = Set(draco.segments.flatMap { [$0.0, $0.1] })
        XCTAssertTrue(stars.contains(68756),
                      "Draco's figure must pass through Thuban (HIP 68756)")
    }

    // ── the name register the figures were authored against ────────────────

    func testTheRegisterKeepsWholeNames() {
        // The first generation of the register split names on whitespace
        // and shipped "Kaus Australis" as "Kaus", three times over — found
        // when the figures were authored against it. IAU names are unique;
        // a duplicate value is a truncation.
        XCTAssertEqual(StarCatalog.properNames[90185], "Kaus Australis")
        XCTAssertEqual(StarCatalog.properNames[107556], "Deneb Algedi")
        XCTAssertEqual(StarCatalog.properNames[102098], "Deneb")
        XCTAssertEqual(StarCatalog.properNames[42911], "Asellus Australis")
        let names = Array(StarCatalog.properNames.values)
        XCTAssertEqual(names.count, Set(names).count,
                       "duplicate register names mean truncation has returned")
    }
}
