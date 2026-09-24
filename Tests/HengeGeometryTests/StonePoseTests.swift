import XCTest
import simd
import HengeAstro
@testable import HengeGeometry

/// The surveyed plan, and the frame it is read into.
///
/// Fixtures come from three places a reader can check independently: the
/// vendored CSV itself (a row quoted by value), Ordnance Survey's published
/// transform (run in `scripts/bake_terrain.py`, a separate implementation),
/// and the monument's published geometry (the Station-Stone rectangle, the
/// axis). Nothing here compares the code with itself.
final class StonePoseTests: XCTestCase {

    private var plan: StonePoseTable {
        get throws { try XCTUnwrap(StonePoseTable.daw, "the plan resource must be in the bundle") }
    }

    // MARK: the resource

    func testThePlanIsBundledInItsSubdirectory() {
        // The macOS app bundle keeps the nesting; the flat lookup alone found
        // the star catalogue on iOS and returned nil on the Mac. Same trap.
        XCTAssertNotNil(StonePoseTable.bundledURL(subdirectoryOnly: true))
    }

    func testEveryRowLoadsAndKeepsItsGrade() throws {
        let plan = try plan
        XCTAssertEqual(plan.poses.count, 93, "Daw's file has 93 stones")

        // Stone 1, quoted from the CSV.
        let one = try XCTUnwrap(plan.pose(1))
        XCTAssertEqual(one.grid.easting, 412258.301)
        XCTAssertEqual(one.grid.northing, 142202.371)
        XCTAssertEqual(one.yawDegrees, -59.9)
        XCTAssertEqual(one.width, 1.993)
        XCTAssertEqual(one.thickness, 1.22)
        XCTAssertEqual(one.accuracyClass, "plan_locked")
        XCTAssertTrue(one.positionIsSurveyed)

        // Fragments keep their suffix; placeholders keep their grade.
        XCTAssertEqual(try XCTUnwrap(plan.pose("55a")).status, .fallen)
        XCTAssertFalse(try XCTUnwrap(plan.pose(96)).positionIsSurveyed, "the Heel Stone row is seed_only")
        XCTAssertFalse(try XCTUnwrap(plan.pose(92)).positionIsSurveyed, "92 is a digitised hole symbol")
        XCTAssertEqual(try XCTUnwrap(plan.pose(33)).status, .emptySocket)
    }

    // MARK: the frame

    /// The Swift transform against the Python one in `scripts/bake_terrain.py`
    /// for the site coordinate. Python: `wgs84_to_osgb36(51.1789, -1.8262)`
    /// → (412245.37, 142199.44). Both are ports of the OS guide; agreement
    /// to a centimetre means neither has a dropped term.
    func testNationalGridMatchesTheTerrainBakeTransform() {
        let point = OSGB.nationalGrid(latitude: Angle(degrees: 51.1789),
                                      longitude: Angle(degrees: -1.8262))
        XCTAssertEqual(point.easting, 412245.37, accuracy: 0.01)
        XCTAssertEqual(point.northing, 142199.44, accuracy: 0.01)
    }

    /// The fitted circle centre and the site coordinate describe the same
    /// place. The site figure is rounded to four decimals (about 10 m in
    /// longitude) and the Helmert shift is good to a few metres, so agreement
    /// to 10 m is what "the same place" can mean — and it rules out a swapped
    /// axis, a wrong grid square or a sign error, which would all miss by
    /// hundreds of metres or more.
    func testTheCircleCentreIsWhereTheSiteIs() throws {
        let plan = try plan
        let site = OSGB.nationalGrid(latitude: GeographicSite.stonehenge.latitude,
                                     longitude: GeographicSite.stonehenge.longitude)
        XCTAssertEqual(plan.centre.easting, site.easting, accuracy: 10)
        XCTAssertEqual(plan.centre.northing, site.northing, accuracy: 10)
    }

    /// Thirteen locked, standing uprights fit a circle of about 15.4 m radius
    /// with residuals under a third of a metre — the "few tenths of a metre"
    /// Daw quotes against Rees. The customary 33 m diameter is to the outer
    /// faces; Cleal's 29.6 m is the inner; the centres lie between.
    func testTheSarsenRingFitsACircle() throws {
        let plan = try plan
        XCTAssertEqual(plan.sarsenRingRadius * 2, 30.9, accuracy: 0.3)
        for pose in plan.poses(role: .sarsenUpright)
        where pose.status == .standing && pose.positionIsSurveyed {
            let p = plan.position(of: pose)
            let r = simd_length(SIMD2(p.x, p.z))
            XCTAssertEqual(r, plan.sarsenRingRadius, accuracy: 0.6, "stone \(pose.petrie)")
        }
    }

    /// Grid convergence at 1.83° W, 51.18° N: (λ − λ₀) sin φ = 0.174° × 0.779
    /// = 0.135°, positive because the site is east of the 2° W central
    /// meridian. OS, *A guide to coordinate systems in Great Britain*.
    func testGridConvergenceAtTheSite() {
        XCTAssertEqual(OSGB.gridConvergence(at: .stonehenge).degrees, 0.135, accuracy: 0.002)
    }

    /// The bearing conversion, checked on one row by hand. Stone 1's yaw is
    /// −59.9°: its width axis lies 59.9° clockwise of grid east, so the face
    /// looks along grid 239.9° (or 59.9°), and true is 0.135° more.
    func testYawBecomesATrueBearing() throws {
        let plan = try plan
        let one = try XCTUnwrap(plan.pose(1))
        XCTAssertEqual(plan.bearing(of: one).degrees, 240.035, accuracy: 0.005)

        // And the face of a circle stone looks along the radius, as it must
        // if the conversion is right in sign: within the few degrees a
        // dressed stone is skewed on its socket.
        for pose in plan.poses(role: .sarsenUpright) where pose.status == .standing {
            let p = plan.position(of: pose)
            let radial = WorldAxes.azimuth(of: normalize(SIMD3(p.x, 0, p.z)))
            let face = plan.bearing(of: pose)
            let skew = min(face.separation(to: radial).degrees,
                           face.separation(to: (radial + Angle(degrees: 180)).normalized).degrees)
            XCTAssertLessThan(skew, 10, "stone \(pose.petrie) faces \(face), radius is \(radial)")
        }
    }

    // MARK: the plan against the published geometry

    /// Stone 1 is the sarsen immediately east of the axis and 30 the one west
    /// of it: the axis passes through the 30/1 gap. Petrie 1880.
    func testStonesOneAndThirtyStraddleTheAxis() throws {
        let plan = try plan
        let one = plan.position(of: try XCTUnwrap(plan.pose(1)))
        let thirty = plan.position(of: try XCTUnwrap(plan.pose(30)))
        let axis = Monument.axisAzimuth
        let b1 = (WorldAxes.azimuth(of: normalize(SIMD3(one.x, 0, one.z))) - axis).signedNormalized.degrees
        let b30 = (WorldAxes.azimuth(of: normalize(SIMD3(thirty.x, 0, thirty.z))) - axis).signedNormalized.degrees
        XCTAssertGreaterThan(b1, 0, "stone 1 is clockwise (east) of the axis")
        XCTAssertLessThan(b30, 0, "stone 30 is anticlockwise (west) of it")
        XCTAssertEqual(b1 + b30, 0, accuracy: 3, "and the gap is centred on the axis")
    }

    /// The Station-Stone rectangle from the plan's rows: about 80 by 33 m,
    /// short sides on the solstice axis, long sides square to it. Atkinson's
    /// figure, and the whole reason the stones are interesting. The plan's
    /// rows for 92 and 94 are digitised hole symbols, so the tolerance is a
    /// couple of metres, not the half-metre a formula would give.
    func testStationStonesFormTheSurveyedRectangle() throws {
        let plan = try plan
        func at(_ n: Int) throws -> SIMD2<Double> {
            let p = plan.position(of: try XCTUnwrap(plan.pose(n)))
            return SIMD2(p.x, p.z)
        }
        let (a, b, c, d) = (try at(91), try at(92), try at(93), try at(94))
        XCTAssertEqual(simd_distance(a, b), 33, accuracy: 3)
        XCTAssertEqual(simd_distance(c, d), 33, accuracy: 3)
        XCTAssertEqual(simd_distance(b, c), 80, accuracy: 3)
        XCTAssertEqual(simd_distance(d, a), 80, accuracy: 3)

        let short = WorldAxes.azimuth(of: normalize(SIMD3(a.x - b.x, 0, a.y - b.y)))
        let long = WorldAxes.azimuth(of: normalize(SIMD3(c.x - b.x, 0, c.y - b.y)))
        let axis = Monument.axisAzimuth
        XCTAssertLessThan(min(short.separation(to: axis).degrees,
                              short.separation(to: (axis + Angle(degrees: 180)).normalized).degrees), 3,
                          "the short side runs on the axis")
        XCTAssertEqual(long.separation(to: axis).degrees, 90, accuracy: 3,
                       "the long side is square to it")
    }

    /// The Heel Stone stands about 77 m out, a little east of the axis.
    /// Cleal et al. 1995; Petrie put it 256 ft (78 m) from the centre.
    func testTheHeelStoneIsOutAlongTheAxis() throws {
        let plan = try plan
        let p = plan.position(of: try XCTUnwrap(plan.pose(96)))
        XCTAssertEqual(simd_length(SIMD2(p.x, p.z)), 78, accuracy: 2)
        let bearing = WorldAxes.azimuth(of: normalize(SIMD3(p.x, 0, p.z)))
        XCTAssertEqual(bearing.degrees, Monument.axisAzimuth.degrees, accuracy: 1.5)
    }

    /// Kåsa's fit on a known circle, including the arc case that matters.
    func testCircleFitRecoversAKnownCircle() {
        let centre = SIMD2(412245.5, 142193.7), radius = 15.44
        let points = stride(from: 40.0, through: 320.0, by: 12).map { deg -> SIMD2<Double> in
            let a = Angle(degrees: deg).radians
            return centre + SIMD2(sin(a), cos(a)) * radius
        }
        let fit = StonePoseTable.fitCircle(points)
        XCTAssertEqual(fit.centre.x, centre.x, accuracy: 1e-6)
        XCTAssertEqual(fit.centre.y, centre.y, accuracy: 1e-6)
        XCTAssertEqual(fit.radius, radius, accuracy: 1e-6)
    }

    // MARK: the scene

    /// Every stone says where it came from, and anything that claims a plan
    /// carries the citation for it.
    func testEveryStoneCarriesItsProvenance() {
        for state in Monument.State.allCases {
            let scene = MonumentScene.complete(state: state)
            for stone in scene.stones {
                for source in [stone.provenance.position, stone.provenance.dimensions] {
                    if let citation = source.citation {
                        XCTAssertFalse(citation.source.isEmpty, "\(stone.id) cites nothing")
                    }
                }
            }
            let counts = scene.provenanceCount
            XCTAssertGreaterThan(counts.surveyed, 50, "\(state): most stones stand on the plan")
            XCTAssertGreaterThan(counts.provisional, 0, "\(state): the placeholders are marked")
            if state == .asItWas {
                XCTAssertGreaterThan(counts.reconstruction, 20,
                                     "the complete monument raises stones the plan has lost")
            }
        }
    }

    /// A standing stone in the ruin stands on its row, to the millimetre the
    /// CSV carries, and a surveyed stone in the complete monument stands in
    /// the same place — the two states differ in what is raised, never in
    /// where a surviving stone is.
    func testSurvivingStonesStandOnTheirRows() throws {
        let plan = try plan
        let was = MonumentScene.complete(state: .asItWas)
        let stands = MonumentScene.complete(state: .asItStands)
        for petrie in [1, 16, 30, 56, 62, 68, 96] {
            let pose = try XCTUnwrap(plan.pose(petrie))
            let expected = plan.position(of: pose)
            for scene in [was, stands] {
                let stone = try XCTUnwrap(scene.stone(id: "stone-\(petrie)"), "\(scene.state) lacks \(petrie)")
                XCTAssertEqual(simd_distance(stone.position, expected), 0, accuracy: 1e-9, "stone \(petrie)")
                XCTAssertTrue(stone.provenance.position.isFromPlan)
            }
        }
    }

    /// Stones with no row are raised at interpolated slots on the fitted
    /// ring, and are marked as ours.
    func testLostSarsensAreReconstructedOnTheRing() {
        let scene = MonumentScene.complete(state: .asItWas)
        for k in [13, 17, 18, 20, 24] {
            let stone = scene.stone(id: "stone-\(k)")!
            XCTAssertEqual(simd_length(SIMD2(stone.position.x, stone.position.z)),
                           MonumentScene.sarsenRingRadius, accuracy: 1e-9)
            XCTAssertEqual(stone.provenance, .reconstruction)
        }
        // Slots are in Petrie order: 17 lies between 16 and 19 clockwise.
        func bearing(_ k: Int) -> Double {
            let p = scene.stone(id: "stone-\(k)")!.position
            return WorldAxes.azimuth(of: normalize(SIMD3(p.x, 0, p.z))).degrees
        }
        XCTAssertGreaterThan(bearing(17), bearing(16))
        XCTAssertLessThan(bearing(17), bearing(19))
        XCTAssertEqual(bearing(18) - bearing(17), bearing(17) - bearing(16), accuracy: 0.5)
    }

    /// In the ruin the fallen stones lie where they lie and the sockets are
    /// empty: nothing is drawn for 13, 17, 18, 20, 24 or the empty bluestone
    /// sockets, and 55 is on the ground as two pieces.
    func testTheRuinDrawsThePlanAndNothingElse() {
        let ruin = MonumentScene.complete(state: .asItStands)
        for gone in ["stone-13", "stone-17", "stone-18", "stone-20", "stone-24", "stone-33", "stone-E"] {
            XCTAssertNil(ruin.stone(id: gone), "\(gone) has no row and should not be drawn")
        }
        XCTAssertNil(ruin.stone(id: "stone-55"))
        XCTAssertNotNil(ruin.stone(id: "stone-55a"))
        XCTAssertNotNil(ruin.stone(id: "stone-55b"))
        XCTAssertLessThan(ruin.stone(id: "stone-55a")!.height, 1.5, "55a lies")
        XCTAssertNotNil(ruin.stone(id: "stone-156"), "the Great Trilithon's lintel lies with it")
        // Lintels still up are laid across their uprights, not floating.
        let l130 = ruin.stone(id: "stone-130")!
        XCTAssertEqual(l130.position.y, Monument.sarsenUprightHeight - 0.2, accuracy: 1e-9)
    }

    /// The Great Trilithon's fallen 55 is raised beside 56 in the complete
    /// monument: same height, a gap away along 56's face, on the
    /// anticlockwise side Petrie's numbering puts it.
    func testTheFallenPartnerIsRaisedBesideTheStandingStone() {
        let stones = MonumentScene.trilithon(.great, state: .asItWas)
        let s55 = stones.first { $0.id == "stone-55" }!
        let s56 = stones.first { $0.id == "stone-56" }!
        XCTAssertTrue(s56.provenance.position.isFromPlan)
        XCTAssertEqual(s55.provenance, .reconstruction)
        XCTAssertEqual(s55.height, s56.height)
        XCTAssertEqual(s55.bearing.degrees, s56.bearing.degrees, accuracy: 1e-9)
        let gap = simd_distance(s55.position, s56.position) - (s55.width + s56.width) / 2
        XCTAssertEqual(gap, Monument.Trilithon.great.gap, accuracy: 1e-9)
        func bearing(_ s: Stone) -> Angle { WorldAxes.azimuth(of: normalize(SIMD3(s.position.x, 0, s.position.z))) }
        XCTAssertLessThan((bearing(s55) - bearing(s56)).signedNormalized.degrees, 0,
                          "55 is anticlockwise of 56")
    }
}
