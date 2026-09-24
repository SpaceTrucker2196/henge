import XCTest
import simd
@testable import HengeGeometry

/// Per-stone heights, and the honesty of the ones that are not per stone.
///
/// Fixtures are Cleal, Walker & Montague 1995, Appendix 5 (height above
/// ground), as those figures are carried in the vendored plan's rows that
/// name Cleal as their source. Stone 68's 2.49 m is also the height issue #3
/// quotes against its laser-scan volume; stone 11 is the famously short
/// upright Petrie singled out in 1880.
final class StoneSurveyTests: XCTestCase {

    private var plan: StonePoseTable {
        get throws { try XCTUnwrap(StonePoseTable.daw) }
    }

    func testOnlyRowsThatNameClealCarryAMeasuredHeight() throws {
        let plan = try plan
        XCTAssertEqual(try XCTUnwrap(plan.pose(68)).clealHeight, 2.49)
        XCTAssertEqual(try XCTUnwrap(plan.pose(11)).clealHeight, 2.74)
        XCTAssertEqual(try XCTUnwrap(plan.pose(31)).clealHeight, 1.88)
        XCTAssertEqual(try XCTUnwrap(plan.pose(27)).clealHeight, 3.96)
        // Hedged ("cleal_app5_or_scene"), bare, and placeholder rows do not.
        XCTAssertNil(try XCTUnwrap(plan.pose(56)).clealHeight, "56 is hedged in the source and stays unmeasured")
        XCTAssertNil(try XCTUnwrap(plan.pose(1)).clealHeight, "1 has no source named")
        XCTAssertNil(try XCTUnwrap(plan.pose(96)).clealHeight, "the Heel Stone row is a placeholder")

        let cited = plan.poses.filter { $0.clealHeight != nil }
        XCTAssertEqual(cited.count, 18, "eighteen rows name Cleal; the rest wait on the printed appendix")
    }

    /// A standing stone with a cited height stands at it, in both states,
    /// and says so; one without keeps the fallback and says that instead.
    func testStandingStonesTakeClealsHeightWhereItIsCited() throws {
        let plan = try plan
        for state in Monument.State.allCases {
            let scene = MonumentScene.complete(state: state)
            for pose in plan.poses where pose.status == .standing {
                guard let stone = scene.stone(id: "stone-\(pose.petrie)") else { continue }
                if let cleal = pose.clealHeight {
                    XCTAssertEqual(stone.height, cleal, accuracy: 1e-9, "\(state) stone \(pose.petrie)")
                    XCTAssertNotNil(stone.provenance.height.citation, "stone \(pose.petrie) must cite Cleal")
                } else {
                    XCTAssertEqual(stone.provenance.height, .reconstruction,
                                   "stone \(pose.petrie) has no cited height and must not claim one")
                }
                // Footprints are not yet per stone, and no standing stone
                // may pretend otherwise (issue #3). Daw's status column calls
                // 91 and 95 standing; both lie, and the ruin draws each at
                // the plan's outline of the block on the ground.
                if state == .asItStands && ["91", "95"].contains(pose.petrie) {
                    XCTAssertLessThan(stone.height, 1.5, "\(pose.petrie) lies")
                } else {
                    XCTAssertEqual(stone.provenance.footprint, .reconstruction, "stone \(pose.petrie)")
                }
            }
        }
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

    /// What lies in the ruin rises as high as its row says and no higher.
    func testFallenBlocksRiseToTheirRowsHeight() throws {
        let plan = try plan
        let ruin = MonumentScene.complete(state: .asItStands)
        for petrie in ["8", "12", "14", "55a", "156"] {
            let pose = try XCTUnwrap(plan.pose(petrie))
            let stone = try XCTUnwrap(ruin.stone(id: "stone-\(petrie)"))
            XCTAssertEqual(stone.height, pose.height, accuracy: 1e-9, petrie)
            XCTAssertLessThan(stone.height, 1.5, "\(petrie) lies")
        }
    }
}
