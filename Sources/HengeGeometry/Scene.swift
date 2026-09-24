import Foundation
import simd
import HengeAstro

/// The stones present in a given view of the monument.
///
/// Placement comes from the surveyed plan in `StonePoseTable` wherever a stone
/// has a row there, and from a ring radius and a count where it does not. The
/// two are never blended in one stone: each `Stone` says which it is in its
/// `provenance`, so a test can count the reconstructions and the lore panel
/// can say how many there are. The ring formulas are kept as the fallback for
/// a build with no plan resource, and for the stones the plan has lost.
public struct MonumentScene: Sendable {

    public let state: Monument.State
    public let stones: [Stone]

    public init(state: Monument.State = .asItWas, stones: [Stone]) {
        self.state = state
        self.stones = stones
    }

    public func stone(id: String) -> Stone? {
        stones.first { $0.id == id }
    }

    public var sarsens: [Stone] { stones.filter { $0.material == .sarsen } }
    public var bluestones: [Stone] { stones.filter { $0.material == .bluestone } }

    /// How many stones stand where the plan puts them, and how many are ours.
    public var provenanceCount: (surveyed: Int, provisional: Int, reconstruction: Int) {
        var counts = (0, 0, 0)
        for stone in stones where stone.material != .chalk {
            switch stone.provenance.position {
            case .surveyed: counts.0 += 1
            case .provisional: counts.1 += 1
            case .reconstruction: counts.2 += 1
            }
        }
        return counts
    }

    // ── the plan ────────────────────────────────────────────────────────────

    /// The surveyed plan, when the resource is present. Every generator below
    /// asks this first and falls back to its formula when the answer is nil
    /// or the stone has no row.
    static let plan: StonePoseTable? = StonePoseTable.daw

    /// Radius the sarsen uprights' centres stand on: fitted from the plan
    /// when there is one, else the constant.
    public static var sarsenRingRadius: Double {
        plan?.sarsenRingRadius ?? Monument.sarsenCircleDiameter / 2
    }

    private static func source(_ pose: StonePose) -> StoneSource {
        pose.positionIsSurveyed
            ? .surveyed(StonePoseTable.citation, accuracyClass: pose.accuracyClass)
            : .provisional(StonePoseTable.citation, accuracyClass: pose.accuracyClass)
    }

    /// A stone drawn exactly as its row describes it: footprint, yaw and
    /// height from the plan. Used in the ruin for what lies or is a stump,
    /// where the row's outline is the block on the ground and its "height"
    /// is how high the block rises. Nothing else describes a fallen stone.
    private static func planned(_ pose: StonePose, id: String? = nil,
                                height: Double? = nil, material: StoneMaterial,
                                lean: Angle = .zero) -> Stone {
        let plan = plan!
        let source = source(pose)
        return Stone(id: id ?? "stone-\(pose.petrie)",
                     position: plan.position(of: pose),
                     height: height ?? pose.height,
                     width: pose.width, thickness: pose.thickness,
                     bearing: plan.bearing(of: pose), lean: lean,
                     material: material,
                     provenance: StoneProvenance(position: source, footprint: source,
                                                 height: height == nil ? heightSource(pose) : .reconstruction))
    }

    /// Where a row's height comes from: Cleal's appendix when Daw says so,
    /// else Daw's own placeholder, else nothing.
    private static func heightSource(_ pose: StonePose) -> StoneSource {
        pose.clealHeight != nil
            ? .surveyed(StonePoseTable.clealCitation, accuracyClass: pose.heightSource ?? "")
            : .provisional(StonePoseTable.citation, accuracyClass: pose.heightSource ?? "placeholder")
    }

    /// A stone placed and turned by its row, with the fallback footprint,
    /// and Cleal's height where the row carries one.
    ///
    /// This is every standing stone, in both states, and every stone the
    /// complete monument raises on a row that is a stump, a fallen block or
    /// an empty socket. The plan's footprints are a digitised hatch at
    /// ground level, and for the bluestones they come out two to three times
    /// the cross-sections measured from volume and height (issue #4), so a
    /// standing stone's section stays the fallback until the per-stone
    /// cross-check in #3 can be run against the laser-scan volumes. Height
    /// is different: where Daw's row says the height is Cleal's, it is used
    /// and cited; a standing stone whose row is a placeholder keeps the
    /// fallback height and says so.
    private static func raised(_ pose: StonePose, id: String? = nil,
                               height fallbackHeight: Double, width: Double, thickness: Double,
                               material: StoneMaterial, lean: Angle = .zero) -> Stone {
        let plan = plan!
        let measured = pose.status == .standing ? pose.clealHeight : nil
        return Stone(id: id ?? "stone-\(pose.petrie)",
                     position: plan.position(of: pose),
                     height: measured ?? fallbackHeight, width: width, thickness: thickness,
                     bearing: plan.bearing(of: pose), lean: lean,
                     material: material,
                     provenance: StoneProvenance(position: source(pose),
                                                 footprint: .reconstruction,
                                                 height: measured == nil ? .reconstruction : heightSource(pose)))
    }

    /// Petrie's number without a fragment suffix: `55a` → 55.
    private static func number(of pose: StonePose) -> Int? {
        Int(pose.petrie.prefix { $0.isNumber })
    }

    private static func horizontalBearing(_ p: SIMD3<Double>) -> Angle {
        WorldAxes.azimuth(of: normalize(SIMD3(p.x, 0, p.z)))
    }

    /// A lintel laid from one upright to the next: centred between them,
    /// long enough to overlap both, seated into them rather than balanced
    /// on top, and turned to lie along the line joining them.
    private static func lintel(id: String, from a: Stone, to b: Stone,
                               seat: Double, height: Double, thickness: Double) -> Stone {
        let span = b.position - a.position
        let run = SIMD3(span.x, 0, span.z)
        let mid = (a.position + b.position) / 2
        let along = WorldAxes.azimuth(of: normalize(run))
        let fromPlan = a.provenance.position.isFromPlan && b.provenance.position.isFromPlan
        return Stone(id: id,
                     position: SIMD3(mid.x, seat, mid.z),
                     height: height,
                     // Overlaps both uprights, as a lintel must.
                     width: simd_length(run) + (a.width + b.width) / 2,
                     thickness: thickness,
                     // Local +X (the width) lies 90° anticlockwise of the
                     // bearing, so a bearing 90° on from the run puts the
                     // width along the run.
                     bearing: (along + Angle(degrees: 90)).normalized,
                     material: .sarsen,
                     provenance: StoneProvenance(
                        position: fromPlan
                            ? .surveyed(StonePoseTable.citation, accuracyClass: "spans surveyed uprights")
                            : .reconstruction,
                        footprint: .reconstruction, height: .reconstruction))
    }

    // ── the whole monument ──────────────────────────────────────────────────

    /// Everything, in the chosen state.
    public static func complete(state: Monument.State = .asItWas) -> MonumentScene {
        var stones: [Stone] = []
        stones += sarsenCircle(state: state)
        stones += trilithonHorseshoe(state: state)
        stones += bluestoneCircle(state: state)
        stones += bluestoneHorseshoe(state: state)
        stones += [altarStone(state: state), heelStone()]
        stones += slaughterStones(state: state)
        stones += stationStones(state: state)
        stones += aubreyHoles()
        return MonumentScene(state: state, stones: stones)
    }

    /// The M1 scene: one trilithon and the Heel Stone. Kept because the shadow
    /// tests need a scene with nothing else casting into the measurement.
    public static func milestoneOne(state: Monument.State = .asItWas) -> MonumentScene {
        var stones = trilithon(.great, state: state)
        stones.append(heelStone())
        return MonumentScene(state: state, stones: stones)
    }

    // ── the sarsen circle ───────────────────────────────────────────────────

    /// Thirty uprights on a ring of about 31 m, carrying a continuous lintel
    /// ring.
    ///
    /// Petrie numbers the outer circle 1–30 clockwise from the sarsen
    /// immediately east of the axis, seen from the centre. Twenty-five have a
    /// row in the plan; the five that are gone without trace (13, 17, 18, 20,
    /// 24) are raised at slots interpolated between their surveyed
    /// neighbours, and so are the stones that survive only as fallen blocks
    /// or stumps, because where a block lies is not where it stood.
    ///
    /// The lintel ring ran dead level although the ground slopes — the builders
    /// packed the sockets to compensate. Modelled by giving every lintel the
    /// same height rather than letting it follow the terrain.
    public static func sarsenCircle(state: Monument.State = .asItWas) -> [Stone] {
        let count = Monument.sarsenUprightCount
        let radius = sarsenRingRadius

        // Bearings of the uprights that still stand on their sockets, keyed
        // by Petrie number. Everything else is placed relative to these.
        var standingBearing: [Int: Angle] = [:]
        for k in 1...count {
            if let plan, let pose = plan.pose(k), pose.status == .standing {
                standingBearing[k] = horizontalBearing(plan.position(of: pose))
            }
        }

        /// The slot for a stone with no standing row: interpolated clockwise
        /// between its nearest standing neighbours, or on the ideal ring
        /// centred on the axis if nothing stands at all.
        func slot(_ k: Int) -> Angle {
            guard !standingBearing.isEmpty else {
                // The 30/1 gap straddles the axis, so stone 1 is half a
                // step clockwise of it.
                return (Monument.axisAzimuth + Angle(degrees: 6 + 12 * Double(k - 1))).normalized
            }
            func wrap(_ n: Int) -> Int { ((n - 1) % count + count) % count + 1 }
            var back = 1
            while standingBearing[wrap(k - back)] == nil { back += 1 }
            var forward = 1
            while standingBearing[wrap(k + forward)] == nil { forward += 1 }
            let a = standingBearing[wrap(k - back)]!, b = standingBearing[wrap(k + forward)]!
            // Clockwise from a to b, as Petrie counts.
            var sweep = (b - a).normalized.degrees
            if sweep == 0 { sweep = 360 }
            return (a + Angle(degrees: sweep * Double(back) / Double(back + forward))).normalized
        }

        var uprights: [Stone] = []
        for k in 1...count {
            let pose = plan?.pose(k)
            switch state {
            case .asItWas:
                if let pose, pose.status == .standing {
                    uprights.append(raised(pose, height: Monument.sarsenUprightHeight,
                                           width: Monument.sarsenUprightWidth,
                                           thickness: Monument.sarsenUprightThickness,
                                           material: .sarsen))
                } else {
                    let bearing = slot(k)
                    uprights.append(Stone(
                        id: "stone-\(k)",
                        position: WorldAxes.direction(azimuth: bearing) * radius,
                        height: Monument.sarsenUprightHeight,
                        width: Monument.sarsenUprightWidth,
                        thickness: Monument.sarsenUprightThickness,
                        // Broad faces look in and out along the radius.
                        bearing: bearing,
                        material: .sarsen))
                }
            case .asItStands:
                // The ruin is the plan, stone by stone: a standing stone
                // stands, a stump is a stump, a fallen block lies where it
                // fell, and a stone with no row is not drawn.
                if let pose, pose.status == .standing {
                    uprights.append(raised(pose, height: Monument.sarsenUprightHeight,
                                           width: Monument.sarsenUprightWidth,
                                           thickness: Monument.sarsenUprightThickness,
                                           material: .sarsen))
                } else if let pose, pose.status.survives {
                    uprights.append(planned(pose, material: .sarsen))
                }
            }
        }
        if state == .asItStands, let plan {
            // Fragments — 9a, 9b — carry a suffix and are not in 1...30.
            for pose in plan.poses(role: .sarsenUpright)
            where Int(pose.petrie) == nil && pose.status.survives {
                uprights.append(planned(pose, material: .sarsen))
            }
        }

        var stones = uprights
        let seat = Monument.sarsenUprightHeight - 0.2   // seated into the uprights
        func spanning(_ n: Int) -> Stone? {
            // Lintel 101 rests on 30 and 1, 102 on 1 and 2, and so on round.
            let left = n == 1 ? count : n - 1
            guard let a = uprights.first(where: { $0.id == "stone-\(left)" }),
                  let b = uprights.first(where: { $0.id == "stone-\(n)" })
            else { return nil }
            return lintel(id: "stone-\(100 + n)", from: a, to: b, seat: seat,
                          height: Monument.sarsenLintelHeight,
                          thickness: Monument.sarsenUprightThickness * 0.95)
        }

        switch state {
        case .asItWas:
            stones += (1...count).compactMap(spanning)
        case .asItStands:
            guard let plan else { break }
            for pose in plan.poses(role: .sarsenLintel) where pose.status.survives {
                if pose.status == .present, let n = Int(pose.petrie), let laid = spanning(n - 100) {
                    stones.append(laid)
                } else {
                    stones.append(planned(pose, material: .sarsen))
                }
            }
        }
        return stones
    }

    // ── the trilithon horseshoe ─────────────────────────────────────────────

    /// Five trilithons in a horseshoe opening north-east, graded in height
    /// toward the Great Trilithon at the closed south-west apex.
    public static func trilithonHorseshoe(state: Monument.State = .asItWas) -> [Stone] {
        Monument.Trilithon.allCases.flatMap { trilithon($0, state: state) }
    }

    /// Angular offset from the apex, and the radius each trilithon stands at,
    /// for the fallback with no plan. The horseshoe opens along the axis, so
    /// these are symmetric about it. Clockwise from the south-west apex is
    /// toward the north-west, so the north-west pairs carry the positive
    /// offsets — the earlier signs had the two sides swapped, which nothing
    /// caught because the plan-less fallback has no test of its own.
    private static func placement(_ which: Monument.Trilithon) -> (offset: Double, radius: Double) {
        switch which {
        case .great: (0, 8.2)
        case .northWestInner: (46, 8.9)
        case .southEastInner: (-46, 8.9)
        case .northWestOuter: (88, 9.9)
        case .southEastOuter: (-88, 9.9)
        }
    }

    /// Place one trilithon.
    ///
    /// Each upright that still stands is drawn on its row. A fallen partner
    /// is raised beside the standing one, a gap's width away along the
    /// standing stone's own face, at the standing stone's height — the pairs
    /// were matched, and the surviving stone is the better witness to its
    /// partner's size than a shared constant is. Only with neither standing
    /// does the whole pair come from the formula.
    public static func trilithon(_ which: Monument.Trilithon,
                                 state: Monument.State = .asItWas) -> [Stone] {
        let numbers = which.numbers
        let firstPose = plan?.pose(numbers.first)
        let secondPose = plan?.pose(numbers.second)

        func onRow(_ pose: StonePose) -> Stone {
            raised(pose, height: which.uprightHeight, width: which.uprightWidth,
                   thickness: which.uprightThickness, material: .sarsen)
        }

        /// The missing partner, on the side Petrie's clockwise numbering
        /// says: `first` is anticlockwise of `second`.
        func partner(of stone: Stone, number: Int, clockwise: Bool) -> Stone {
            let across = WorldAxes.direction(azimuth: (stone.bearing - Angle(degrees: 90)).normalized)
            let separation = stone.width / 2 + which.gap + which.uprightWidth / 2
            let candidates = [stone.position + across * separation,
                              stone.position - across * separation]
            let here = horizontalBearing(stone.position)
            let chosen = candidates.first {
                let turn = (horizontalBearing($0) - here).signedNormalized.degrees
                return clockwise ? turn > 0 : turn < 0
            } ?? candidates[0]
            return Stone(id: "stone-\(number)", position: chosen,
                         height: stone.height, width: which.uprightWidth,
                         thickness: which.uprightThickness, bearing: stone.bearing,
                         material: .sarsen,
                         // The height is its twin's, which may be Cleal's;
                         // the twin's row is the witness, so it is cited.
                         provenance: StoneProvenance(position: .reconstruction,
                                                     footprint: .reconstruction,
                                                     height: stone.provenance.height))
        }

        func formulaPair() -> (Stone, Stone) {
            let apexBearing = (Monument.axisAzimuth + Angle(degrees: 180)).normalized
            let (offset, radius) = placement(which)
            let radialBearing = (apexBearing + Angle(degrees: offset)).normalized
            let centre = WorldAxes.direction(azimuth: radialBearing) * radius
            // Each trilithon looks back toward the centre of the horseshoe,
            // and the pair straddles that facing.
            let facing = (radialBearing + Angle(degrees: 180)).normalized
            let across = WorldAxes.direction(azimuth: (facing + Angle(degrees: 90)).normalized)
            let halfSpan = which.uprightWidth / 2 + which.gap / 2
            func upright(_ n: Int, _ side: Double) -> Stone {
                Stone(id: "stone-\(n)", position: centre + across * halfSpan * side,
                      height: which.uprightHeight, width: which.uprightWidth,
                      thickness: which.uprightThickness, bearing: facing, material: .sarsen)
            }
            return (upright(numbers.first, -1), upright(numbers.second, 1))
        }

        func cap(_ a: Stone, _ b: Stone) -> Stone {
            lintel(id: "stone-\(numbers.lintel)", from: a, to: b,
                   seat: min(a.height, b.height) - 0.25,
                   height: which.lintelHeight, thickness: which.uprightThickness)
        }

        switch state {
        case .asItWas:
            let pair: (Stone, Stone)
            switch (firstPose?.status == .standing ? firstPose : nil,
                    secondPose?.status == .standing ? secondPose : nil) {
            case let (first?, second?):
                pair = (onRow(first), onRow(second))
            case let (first?, nil):
                let a = onRow(first)
                pair = (a, partner(of: a, number: numbers.second, clockwise: true))
            case let (nil, second?):
                let b = onRow(second)
                pair = (partner(of: b, number: numbers.first, clockwise: false), b)
            case (nil, nil):
                pair = formulaPair()
            }
            return [pair.0, pair.1, cap(pair.0, pair.1)]

        case .asItStands:
            guard let plan else {
                // No plan: the ruin as it was read off the literature.
                let (left, right) = formulaPair()
                switch which {
                case .great: return [right]
                case .northWestOuter, .southEastOuter: return [left, right, cap(left, right)]
                default: return [left, right]
                }
            }
            var stones: [Stone] = []
            for pose in plan.poses(role: .trilithonUpright)
            where [numbers.first, numbers.second].contains(number(of: pose)) && pose.status.survives {
                stones.append(pose.status == .standing ? onRow(pose) : planned(pose, material: .sarsen))
            }
            for pose in plan.poses(role: .trilithonLintel)
            where number(of: pose) == numbers.lintel && pose.status.survives {
                if pose.status == .present,
                   let a = stones.first(where: { $0.id == "stone-\(numbers.first)" }),
                   let b = stones.first(where: { $0.id == "stone-\(numbers.second)" }) {
                    stones.append(cap(a, b))
                } else {
                    stones.append(planned(pose, material: .sarsen))
                }
            }
            return stones
        }
    }

    // ── the bluestones ──────────────────────────────────────────────────────

    /// The formula slots for a ring, ranked by how far each lies from any
    /// surveyed stone, so the reconstructions fill the gaps in the plan
    /// rather than stand inside stones that are there.
    private static func emptiest(slots: [(index: Int, position: SIMD3<Double>)],
                                 away from: [Stone], count: Int) -> [(index: Int, position: SIMD3<Double>)] {
        let ranked = slots.map { slot -> (Double, (index: Int, position: SIMD3<Double>)) in
            let nearest = from.map {
                simd_distance(SIMD2($0.position.x, $0.position.z), SIMD2(slot.position.x, slot.position.z))
            }.min() ?? .infinity
            return (nearest, slot)
        }.sorted { $0.0 > $1.0 }
        return ranked.prefix(count).map(\.1).sorted { $0.index < $1.index }
    }

    /// The bluestone circle, between the sarsens and the trilithon horseshoe.
    ///
    /// Perhaps sixty stones originally; forty are represented here, the honest
    /// middle of a Debated count. Petrie numbered the ones he could see 31–49,
    /// and every one of those has a row in the plan — a standing stone, a
    /// fallen one, or an empty socket, each of which says where the stone
    /// was. The twenty-one beyond Petrie's count are reconstructions on the
    /// ring, placed in the largest gaps. Dolerite and rhyolite carried from
    /// the Preseli Hills, 250 km away in Wales — the most remarkable single
    /// fact about the place.
    public static func bluestoneCircle(state: Monument.State = .asItWas) -> [Stone] {
        let count = 40
        let rows = (31...49).compactMap { plan?.pose($0) }.filter { $0.role == .bluestone }
        let radius = rows.isEmpty ? 12.2
            : rows.map { simd_length(SIMD2(plan!.position(of: $0).x, plan!.position(of: $0).z)) }
                .reduce(0, +) / Double(rows.count)

        func fallbackHeight(_ i: Int) -> Double { 1.9 + Double(i % 5) * 0.16 }
        func fallbackLean(_ i: Int) -> Angle { Angle(degrees: Double((i * 7) % 9) - 4) }
        func slotPosition(_ i: Int) -> (bearing: Angle, position: SIMD3<Double>) {
            let bearing = Angle(degrees: Double(i) * 360 / Double(count) + 4)
            return (bearing, WorldAxes.direction(azimuth: bearing) * radius)
        }
        func reconstruction(id: String, slot i: Int) -> Stone {
            let (bearing, position) = slotPosition(i)
            return Stone(id: id, position: position,
                         height: fallbackHeight(i),
                         // The interim single section from issue #4: about
                         // 0.26 m², the measured mean. Per-stone sections
                         // are issue #3.
                         width: 0.60, thickness: 0.43,
                         bearing: bearing, lean: fallbackLean(i), material: .bluestone)
        }

        switch state {
        case .asItWas:
            var stones: [Stone] = []
            for k in 31...49 {
                if let pose = rows.first(where: { $0.petrie == String(k) }) {
                    stones.append(raised(pose, height: fallbackHeight(k - 31),
                                         width: 0.60, thickness: 0.43, material: .bluestone))
                } else {
                    stones.append(reconstruction(id: "stone-\(k)", slot: k - 31))
                }
            }
            let slots = (0..<count).map { (index: $0, position: slotPosition($0).position) }
            for slot in emptiest(slots: slots, away: stones, count: count - stones.count) {
                stones.append(reconstruction(id: "bluestone-circle-\(slot.index)", slot: slot.index))
            }
            return stones

        case .asItStands:
            guard plan != nil else {
                // Roughly half survive, scattered rather than in a clean arc.
                return (0..<count).compactMap { i in
                    i % 5 < 2 ? nil
                        : reconstruction(id: i < 19 ? "stone-\(31 + i)" : "bluestone-circle-\(i)", slot: i)
                }
            }
            return rows.filter { $0.status.survives }.map { pose in
                pose.status == .standing
                    ? raised(pose, height: fallbackHeight(Int(pose.petrie)! - 31),
                             width: 0.60, thickness: 0.43, material: .bluestone)
                    : planned(pose, material: .bluestone)
            }
        }
    }

    /// The inner bluestone horseshoe: an oval opening north-east, inside the
    /// trilithons and graded toward the apex as they are. Petrie's 61–72 have
    /// rows; the rest of the nineteen are reconstructions in the gaps.
    public static func bluestoneHorseshoe(state: Monument.State = .asItWas) -> [Stone] {
        let apexBearing = (Monument.axisAzimuth + Angle(degrees: 180)).normalized
        let count = 19
        let rows = (61...72).compactMap { plan?.pose($0) }.filter { $0.role == .bluestone }

        func offset(of bearing: Angle) -> Double {
            max(-135, min(135, (bearing - apexBearing).signedNormalized.degrees))
        }
        func fallbackHeight(offset: Double) -> Double { 2.5 - abs(offset) / 135.0 * 0.8 }
        func slot(_ i: Int) -> (bearing: Angle, position: SIMD3<Double>, offset: Double) {
            // Spread over 270°, leaving the north-east open; oval rather than
            // circular, deeper along the axis.
            let offset = -135.0 + Double(i) * (270.0 / Double(count - 1))
            let bearing = (apexBearing + Angle(degrees: offset)).normalized
            let radius = 6.2 + 1.5 * cos(Angle(degrees: offset).radians)
            return (bearing, WorldAxes.direction(azimuth: bearing) * radius, offset)
        }
        func reconstruction(id: String, slot i: Int) -> Stone {
            let s = slot(i)
            return Stone(id: id, position: s.position,
                         height: fallbackHeight(offset: s.offset),
                         width: 0.60, thickness: 0.43,   // issue #4's interim section
                         bearing: (s.bearing + Angle(degrees: 180)).normalized,
                         material: .bluestone)
        }

        switch state {
        case .asItWas:
            var stones: [Stone] = []
            for k in 61...72 {
                if let pose = rows.first(where: { $0.petrie == String(k) }) {
                    let bearing = horizontalBearing(plan!.position(of: pose))
                    let height = fallbackHeight(offset: offset(of: bearing))
                    stones.append(raised(pose, height: height, width: 0.60, thickness: 0.43,
                                         material: .bluestone))
                } else {
                    stones.append(reconstruction(id: "stone-\(k)", slot: k - 61))
                }
            }
            let slots = (0..<count).map { (index: $0, position: slot($0).position) }
            for s in emptiest(slots: slots, away: stones, count: count - stones.count) {
                stones.append(reconstruction(id: "bluestone-horseshoe-\(s.index)", slot: s.index))
            }
            return stones

        case .asItStands:
            guard let plan else {
                return (0..<count).compactMap { i in
                    i % 4 == 1 ? nil
                        : reconstruction(id: i < 12 ? "stone-\(61 + i)" : "bluestone-horseshoe-\(i)", slot: i)
                }
            }
            // Fragments (61a) have a suffix and sit outside 61...72.
            return plan.poses(role: .bluestone)
                .filter { $0.status.survives && (61...72).contains(number(of: $0) ?? 0) }
                .map { pose in
                    guard pose.status == .standing else { return planned(pose, material: .bluestone) }
                    let bearing = horizontalBearing(plan.position(of: pose))
                    return raised(pose, height: fallbackHeight(offset: offset(of: bearing)),
                                  width: 0.60, thickness: 0.43, material: .bluestone)
                }
        }
    }

    // ── the singular stones ─────────────────────────────────────────────────

    /// The Altar Stone: a recumbent slab at the focal point, five metres of
    /// grey-green sandstone.
    ///
    /// Recent work traces it not to Wales but to north-east Scotland — some
    /// 700 km, which nobody has satisfactorily explained. In the ruin it lies
    /// pinned beneath the fallen stones of the Great Trilithon.
    public static func altarStone(state: Monument.State = .asItWas) -> Stone {
        // Recumbent: it lies flat, so its "height" is its thickness. The
        // plan's row has no measured thickness, so this stays the literature's
        // figure and the dimensions are marked as ours.
        let thickness = 0.6
        let lean: Angle = state == .asItStands ? Angle(degrees: 6) : .zero
        if let plan, let pose = plan.pose(80) {
            return raised(pose, height: thickness, width: pose.width, thickness: pose.thickness,
                          material: .bluestone, lean: lean)
        }
        let apexBearing = (Monument.axisAzimuth + Angle(degrees: 180)).normalized
        return Stone(id: "stone-80",
                     position: WorldAxes.direction(azimuth: apexBearing) * 5.4,
                     height: thickness, width: 4.9, thickness: 1.0,
                     bearing: (Monument.axisAzimuth + Angle(degrees: 90)).normalized,
                     lean: lean,
                     material: .bluestone)
    }

    /// The Heel Stone: unshaped, leaning, out along the Avenue on the axis.
    ///
    /// The solstice sun rises a little to its left. A companion probably stood
    /// beside it forming a corridor — Debated, and a toggle in a later
    /// milestone rather than something quietly drawn in. The plan's row for
    /// it is one Daw grades `seed_only`, so it ships as provisional.
    public static func heelStone() -> Stone {
        // Leans about 27° toward the circle — against its own facing, hence
        // the negative angle.
        let lean = Angle(degrees: -27)
        if let plan, let pose = plan.pose(96) {
            // The lean is toward the circle, and a negative lean tips the
            // stone against its facing, so the face must look outward along
            // the axis, as the fallback's does.
            let raw = plan.bearing(of: pose)
            let outward = raw.separation(to: Monument.axisAzimuth).degrees < 90
                ? raw : (raw + Angle(degrees: 180)).normalized
            return Stone(id: "stone-96", position: plan.position(of: pose),
                         height: Monument.heelStoneHeight,
                         width: 2.4, thickness: 2.1,
                         bearing: outward, lean: lean, material: .sarsen,
                         provenance: StoneProvenance(position: source(pose),
                                                     footprint: .reconstruction,
                                                     height: .reconstruction))
        }
        return Stone(id: "stone-96",
                     position: WorldAxes.direction(azimuth: Monument.axisAzimuth)
                         * Monument.heelStoneDistance,
                     height: Monument.heelStoneHeight,
                     width: 2.4, thickness: 2.1,
                     bearing: Monument.axisAzimuth,
                     lean: lean,
                     material: .sarsen)
    }

    /// The Slaughter Stone, fallen at the north-east entrance, and the portal
    /// partner it once stood beside. The name is antiquarian invention:
    /// nothing was slaughtered on it.
    public static func slaughterStones(state: Monument.State = .asItWas) -> [Stone] {
        let axis = Monument.axisAzimuth
        let along = WorldAxes.direction(azimuth: axis)
        let across = WorldAxes.direction(azimuth: (axis + Angle(degrees: 90)).normalized)

        // Where 95 lies: on its row, else at the entrance on the axis.
        let pose = plan?.pose(95)
        let lying = pose.map { plan!.position(of: $0) } ?? along * 21.0 - across * 1.8
        let lyingBearing = pose.map { plan!.bearing(of: $0) } ?? axis
        let positionSource: StoneSource = pose.map(source) ?? .reconstruction

        switch state {
        case .asItStands:
            return [Stone(id: "stone-95", position: lying,
                          height: 0.9, width: pose?.width ?? 6.4, thickness: pose?.thickness ?? 2.1,
                          bearing: lyingBearing, material: .sarsen,
                          provenance: StoneProvenance(position: positionSource,
                                                      footprint: pose == nil ? .reconstruction : positionSource,
                                                      height: .reconstruction))]
        case .asItWas:
            // 95 raised where it lies; its lost partner E mirrored across the
            // axis, since the pair framed the entrance.
            let mirrored = along * 2 * simd_dot(lying, along) - lying
            return [
                Stone(id: "stone-95", position: lying,
                      height: 4.3, width: 2.1, thickness: 1.1,
                      bearing: axis, material: .sarsen,
                      provenance: StoneProvenance(position: positionSource, footprint: .reconstruction,
                                                  height: .reconstruction)),
                Stone(id: "stone-E", position: mirrored,
                      height: 4.3, width: 2.1, thickness: 1.1,
                      bearing: axis, material: .sarsen)
            ]
        }
    }

    /// The four Station Stones on the Aubrey circle, forming a rectangle whose
    /// short sides parallel the solstice axis and whose long sides point at the
    /// major standstill moonrise and moonset.
    ///
    /// That right angle only works at this latitude — walk fifty miles north or
    /// south and it breaks. Established, and the best single argument that the
    /// builders watched the moon as well as the sun. Two survive.
    ///
    /// The plan's rows for these are Daw's placeholders (91 and 93 seeded, 92
    /// and 94 digitised hole symbols), so they ship as provisional. They are
    /// still a better reading than the formula they replaced, which had the
    /// rectangle turned through 90°: its short side lay *across* the axis,
    /// and the only test on it measured lengths, not orientation.
    public static func stationStones(state: Monument.State = .asItWas) -> [Stone] {
        let radius = Monument.aubreyCircleDiameter / 2
        let axis = Monument.axisAzimuth
        // Fallback offsets from the axis for a build with no plan. On an 87 m
        // circle a 33 m short side subtends about 44.6°, and that side runs
        // along the axis, so a corner sits 22.3° either side of the
        // perpendicular.
        let corners: [(name: String, offset: Double, survives: Bool)] = [
            ("91", 67.7, true),
            ("92", 112.3, false),
            ("93", 247.7, true),
            ("94", 292.3, false)
        ]
        return corners.compactMap { corner in
            if state == .asItStands && !corner.survives { return nil }
            let height = state == .asItStands && corner.name == "93" ? 1.0 : 1.4
            if let plan, let pose = plan.pose(corner.name) {
                if state == .asItStands && corner.name == "91" {
                    // 91 lies; the row's footprint is the block as it lies.
                    return planned(pose, height: 1.0, material: .sarsen)
                }
                return raised(pose, height: height, width: 1.2, thickness: 0.8, material: .sarsen)
            }
            let bearing = (axis + Angle(degrees: corner.offset)).normalized
            return Stone(id: "stone-\(corner.name)",
                         position: WorldAxes.direction(azimuth: bearing) * radius,
                         height: height,
                         width: 1.2, thickness: 0.8,
                         bearing: bearing, material: .sarsen)
        }
    }

    /// The fifty-six Aubrey holes: chalk-filled pits on an 87 m circle, drawn
    /// as pale discs flush in the turf. They held cremated human remains —
    /// Stonehenge was a cemetery before it was anything else.
    public static func aubreyHoles() -> [Stone] {
        let radius = Monument.aubreyCircleDiameter / 2
        return (0..<Monument.aubreyHoleCount).map { i in
            let bearing = Angle(degrees: Double(i) * 360 / Double(Monument.aubreyHoleCount))
            return Stone(id: "aubrey-hole-\(i)",
                         position: WorldAxes.direction(azimuth: bearing) * radius,
                         height: 0.12, width: 1.7, thickness: 1.7,
                         bearing: bearing, material: .chalk)
        }
    }
}
