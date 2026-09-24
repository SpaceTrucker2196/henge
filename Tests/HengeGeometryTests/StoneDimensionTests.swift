import XCTest
@testable import HengeGeometry

/// Real-world sizes, not internal consistency (MISSION.md invariant 9): a
/// stone at twice life size renders correctly and passes every other test.
final class StoneDimensionTests: XCTestCase {

    /// Bluestone cross-sections. Volume over height on the four bluestones
    /// that have both figures published — 31, 49, 62 and 68 — gives sections
    /// of 0.362, 0.195, 0.202 and 0.285 m² (issue #4, from Historic England
    /// RR 32/2012 Appendix 1 volumes and Cleal, Walker & Montague 1995
    /// Appendix 5 heights). The literature describes the pillars as about
    /// 60 cm across, which is 0.28 m² for a square section. Every generated
    /// bluestone must sit inside that measured spread; the previous
    /// 0.95 × 0.62 (0.59 m²) sat well outside it.
    func testBluestoneSectionsAreLifeSize() {
        let stones = MonumentScene.bluestoneCircle(state: .asItWas)
            + MonumentScene.bluestoneHorseshoe(state: .asItWas)
        XCTAssertEqual(stones.count, 59)
        for stone in stones {
            let section = stone.width * stone.thickness
            XCTAssertGreaterThanOrEqual(section, 0.18,
                                        "\(stone.id) is thinner than any measured bluestone")
            XCTAssertLessThanOrEqual(section, 0.37,
                                     "\(stone.id) is fatter than any measured bluestone")
            // A stone on a fallback height reads as a pillar. One with a
            // cited height is whatever height Cleal recorded, and 34 and 46
            // stand under a metre.
            if stone.provenance.height == .reconstruction {
                XCTAssertGreaterThan(stone.height / max(stone.width, stone.thickness), 2.0,
                                     "\(stone.id) should read as a pillar, not a block")
            }
        }
    }
}
