import XCTest
import simd
@testable import HengeGeometry

/// Per-stone heights, and the honesty of the ones that are not per stone.
///
/// Fixtures are Cleal, Walker & Montague 1995, Appendix 5, "Heights of
/// Stones", pp 547–548, quoted by value from the printed page: stone 11's
/// 9 ft (2.74 m) is the short upright Petrie singled out in 1880; stone 56's
/// 21 ft 6 in (6.55 m) is the Great Trilithon's survivor; stone 68's
/// 8 ft 2 in (2.49 m) is the height issue #3 quotes against its laser-scan
/// volume.
final class StoneSurveyTests: XCTestCase {

    private var survey: StoneSurvey {
        get throws { try XCTUnwrap(StoneSurvey.cleal, "the appendix resource must be in the bundle") }
    }

    func testTheAppendixIsBundledInItsSubdirectory() {
        XCTAssertNotNil(StoneSurvey.bundledURL(subdirectoryOnly: true))
    }

    func testRowsMatchThePrintedPage() throws {
        let survey = try survey
        XCTAssertEqual(survey.standingHeight(of: "11"), 2.74)
        XCTAssertEqual(survey.standingHeight(of: "56"), 6.55)
        XCTAssertEqual(survey.standingHeight(of: "68"), 2.49)
        XCTAssertEqual(survey.standingHeight(of: "1"), 3.96)
        XCTAssertEqual(survey.standingHeight(of: "51"), 4.98)
        XCTAssertEqual(survey.standingHeight(of: "96"), 4.57)
        XCTAssertEqual(survey.standingHeight(of: "31"), 1.88)
        XCTAssertEqual(survey.standingHeight(of: "49"), 1.90, "the first of four pieces is the stone's own")
        XCTAssertEqual(survey.lintelThickness(of: "152"), 1.07)

        // Feet and metres are both printed; where they disagree the row
        // says so and the metres column is what the app reads.
        let flagged = survey.rows.filter { $0.note.contains("disagree") }.map(\.petrie)
        XCTAssertEqual(Set(flagged), ["9A", "58", "64"])

        // Every row cites a page in the appendix, and the whole table came
        // from those two pages.
        XCTAssertEqual(Set(survey.rows.map(\.page)), [547, 548])
        XCTAssertGreaterThan(survey.rows.count, 130)
    }

    /// Stones re-erected in 1958 are listed as they lay, and the table must
    /// not hand those pieces back as a standing height.
    func testReErectedStonesHaveNoStandingHeightInTheTable() throws {
        let survey = try survey
        for petrie in ["22", "57", "58"] {
            XCTAssertNil(survey.standingHeight(of: petrie), "\(petrie) is recorded as it lay before 1958")
            XCTAssertFalse(survey.rows(for: petrie).isEmpty, "\(petrie) is in the table, as pieces")
        }
        XCTAssertNil(survey.standingHeight(of: "13"), "13 is lost and has no row")
    }

    /// A standing stone with a recorded height stands at it, in both states,
    /// and cites the appendix; one without keeps the fallback and says so.
    func testStandingStonesTakeClealsHeightWhereRecorded() throws {
        let survey = try survey
        let plan = try XCTUnwrap(StonePoseTable.daw)
        var cited = 0
        for state in Monument.State.allCases {
            let scene = MonumentScene.complete(state: state)
            for pose in plan.poses where pose.status == .standing {
                guard let stone = scene.stone(id: "stone-\(pose.petrie)") else { continue }
                let lies = MonumentScene.liesDespiteRow.contains(pose.petrie)
                if let height = survey.standingHeight(of: pose.petrie), !lies {
                    XCTAssertEqual(stone.height, height, accuracy: 1e-9, "\(state) stone \(pose.petrie)")
                    XCTAssertEqual(stone.provenance.height.citation, StoneSurvey.citation, "stone \(pose.petrie)")
                    cited += 1
                } else if pose.petrie == "22" {
                    // Recorded by Cleal only as it lay; Petrie measured it
                    // standing in 1877: 153 in.
                    XCTAssertEqual(stone.height, 153 * 0.0254, accuracy: 1e-9)
                    XCTAssertEqual(stone.provenance.height.citation, StoneSurvey.petrieCitation)
                } else {
                    XCTAssertEqual(stone.provenance.height, .reconstruction,
                                   "stone \(pose.petrie) has no recorded height and must not claim one")
                }
                // Footprints are not yet per stone, and no standing stone
                // may pretend otherwise (issue #3). Daw's status column calls
                // 91 and 95 standing; both lie, and the ruin draws each at
                // the plan's outline of the block on the ground.
                if state == .asItStands && lies {
                    XCTAssertLessThan(stone.height, 1.5, "\(pose.petrie) lies")
                } else {
                    XCTAssertEqual(stone.provenance.footprint, .reconstruction, "stone \(pose.petrie)")
                }
            }
        }
        XCTAssertGreaterThan(cited, 60, "most standing stones now carry a recorded height")
    }

    /// Stone 11 is the one Petrie called "very much smaller" and used to argue
    /// the circle was never finished. At 2.74 m against neighbours of about
    /// 4 m it should be visibly the runt of the ring in the complete monument.
    func testStoneElevenIsTheShortUpright() {
        let scene = MonumentScene.complete(state: .asItWas)
        let eleven = scene.stone(id: "stone-11")!
        let ten = scene.stone(id: "stone-10")!
        XCTAssertEqual(eleven.height, 2.74)
        XCTAssertGreaterThan(ten.height - eleven.height, 1.0)
    }

    /// The Great Trilithon: 56 at its recorded 6.55 m, and 55 raised beside
    /// it at the same height, since the twin is the witness.
    func testTheGreatTrilithonStandsAtItsRecordedHeight() {
        let stones = MonumentScene.trilithon(.great, state: .asItWas)
        XCTAssertEqual(stones.first { $0.id == "stone-56" }!.height, 6.55)
        XCTAssertEqual(stones.first { $0.id == "stone-55" }!.height, 6.55)
    }

    /// What lies in the ruin rises as high as its row says and no higher.
    func testFallenBlocksRiseToTheirRowsHeight() throws {
        let plan = try XCTUnwrap(StonePoseTable.daw)
        let ruin = MonumentScene.complete(state: .asItStands)
        for petrie in ["8", "12", "14", "55a", "156"] {
            let pose = try XCTUnwrap(plan.pose(petrie))
            let stone = try XCTUnwrap(ruin.stone(id: "stone-\(petrie)"))
            XCTAssertEqual(stone.height, pose.height, accuracy: 1e-9, petrie)
            XCTAssertLessThan(stone.height, 1.5, "\(petrie) lies")
        }
    }

    /// Petrie's 1877 heights against Cleal's 1919/Atkinson ones, for the
    /// stones nothing has moved in between. Excluded: 6, 7, 29 and 30
    /// (straightened 1919–20), 22 (fell 1900), 23 (fell and re-erected
    /// 1963–64), 56 (straightened 1901). The two surveys were made forty
    /// years apart with different instruments against different ground
    /// levels, and Cleal's "13 ft 0 in" repeats look rounded; they agree to
    /// about a third of a metre at worst (stone 11: 96 in against 9 ft) and
    /// a tenth on average, which is the check the issue asked for.
    func testPetrieAgreesWithClealWhereNothingMoved() throws {
        let petrie = try XCTUnwrap(StoneSurvey.petrie, "the Petrie resource must be in the bundle")
        let cleal = try survey
        func inches(_ p: String) -> Double? { petrie.first { $0.petrie == p }?.heightInches }

        // Quoted from the page: stone 1 is 159 in; stone 22, standing in
        // 1877 and fallen in 1900, is 153 in — the only standing height of
        // 22 in print.
        XCTAssertEqual(inches("1"), 159)
        XCTAssertEqual(inches("22"), 153)
        XCTAssertNil(cleal.standingHeight(of: "22"))

        let untouched = ["1", "2", "3", "4", "5", "10", "11", "16", "21", "27", "28", "34",
                         "51", "53", "54", "60"]
        var differences: [Double] = []
        for p in untouched {
            let a = try XCTUnwrap(petrie.first { $0.petrie == p }?.height, "Petrie lacks \(p)")
            let b = try XCTUnwrap(cleal.standingHeight(of: p), "Cleal lacks \(p)")
            XCTAssertEqual(a, b, accuracy: 0.35,
                           "stone \(p): Petrie \(String(format: "%.2f", a)) m, Cleal \(String(format: "%.2f", b)) m")
            differences.append(abs(a - b))
        }
        let mean = differences.reduce(0, +) / Double(differences.count)
        XCTAssertLessThan(mean, 0.2, "mean disagreement \(String(format: "%.2f", mean)) m")
    }
}
