import Foundation
import simd
import HengeAstro

/// The stones present in a given view of the monument.
///
/// Placement is computed from the surveyed dimensions in `Monument`, on the
/// true axis, rather than arranged until it looks about right. Every ring and
/// horseshoe below is generated from a radius and a count, so the figures can
/// be checked against a plan and corrected in one place.
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

    /// Thirty uprights on a 33 m ring, carrying a continuous lintel ring.
    ///
    /// The lintel ring ran dead level although the ground slopes — the builders
    /// packed the sockets to compensate. Modelled by giving every lintel the
    /// same height rather than letting it follow the terrain.
    public static func sarsenCircle(state: Monument.State = .asItWas) -> [Stone] {
        let radius = Monument.sarsenCircleDiameter / 2
        let count = Monument.sarsenUprightCount
        var stones: [Stone] = []

        for i in 0..<count {
            // In the ruin much of the west side has fallen. The shape of the
            // gap is Established; which individual stone is which, at this
            // level of detail, is a fair reading of the plan rather than a
            // stone-by-stone survey.
            if state == .asItStands && fallenSarsen(index: i) { continue }

            let bearing = Angle(degrees: Double(i) * 360 / Double(count))
            stones.append(Stone(
                // Petrie numbers the outer circle 1–30 clockwise from the
                // sarsen immediately east of the axis, seen from the centre.
                id: "stone-\(i + 1)",
                position: WorldAxes.direction(azimuth: bearing) * radius,
                height: Monument.sarsenUprightHeight,
                width: Monument.sarsenUprightWidth,
                thickness: Monument.sarsenUprightThickness,
                // Broad faces look in and out along the radius.
                bearing: bearing,
                material: .sarsen
            ))
        }

        if state == .asItWas {
            stones += (0..<count).map { lintel(index: $0, radius: radius, count: count) }
        } else {
            // Only a short run of lintels is still up, on the north-east arc.
            stones += (0..<3).map { lintel(index: $0, radius: radius, count: count) }
        }
        return stones
    }

    private static func lintel(index: Int, radius: Double, count: Int) -> Stone {
        // Spans upright i to i+1, so it sits at the half-step between them.
        let bearing = Angle(degrees: (Double(index) + 0.5) * 360 / Double(count))
        let position = WorldAxes.direction(azimuth: bearing) * radius
        let chord = 2 * radius * sin(.pi / Double(count))

        return Stone(
            // Outer-circle lintels are 101–130 in the same order.
            id: "stone-\(101 + index)",
            // Seated into the uprights, not balanced on them.
            position: SIMD3(position.x, Monument.sarsenUprightHeight - 0.2, position.z),
            height: Monument.sarsenLintelHeight,
            width: chord + 0.4,          // overlaps its neighbours, as a ring must
            thickness: Monument.sarsenUprightThickness * 0.95,
            bearing: bearing,
            material: .sarsen
        )
    }

    private static func fallenSarsen(index: Int) -> Bool {
        (12...22).contains(index) && index % 3 != 0
    }

    // ── the trilithon horseshoe ─────────────────────────────────────────────

    /// Five trilithons in a horseshoe opening north-east, graded in height
    /// toward the Great Trilithon at the closed south-west apex.
    public static func trilithonHorseshoe(state: Monument.State = .asItWas) -> [Stone] {
        Monument.Trilithon.allCases.flatMap { trilithon($0, state: state) }
    }

    /// Angular offset from the apex, and the radius each trilithon stands at.
    /// The horseshoe opens along the axis, so these are symmetric about it.
    private static func placement(_ which: Monument.Trilithon) -> (offset: Double, radius: Double) {
        switch which {
        case .great: (0, 8.2)
        case .northWestInner: (-46, 8.9)
        case .southEastInner: (46, 8.9)
        case .northWestOuter: (-88, 9.9)
        case .southEastOuter: (88, 9.9)
        }
    }

    /// Place one trilithon.
    ///
    /// The horseshoe opens to the north-east along the axis, so the Great
    /// Trilithon stands at the closed south-west apex with its inner face
    /// square to the axis — which is what puts midwinter sunset through it.
    public static func trilithon(_ which: Monument.Trilithon,
                                 state: Monument.State = .asItWas) -> [Stone] {
        let apexBearing = (Monument.axisAzimuth + Angle(degrees: 180)).normalized
        let (offset, radius) = placement(which)

        let radialBearing = (apexBearing + Angle(degrees: offset)).normalized
        let centre = WorldAxes.direction(azimuth: radialBearing) * radius
        // Each trilithon looks back toward the centre of the horseshoe.
        let facing = (radialBearing + Angle(degrees: 180)).normalized

        // The pair straddles that facing, each upright half a gap out along
        // the perpendicular.
        let across = WorldAxes.direction(azimuth: (facing + Angle(degrees: 90)).normalized)
        let halfSpan = which.uprightWidth / 2 + which.gap / 2

        let numbers = which.numbers
        let left = Stone(id: "stone-\(numbers.first)",
                         position: centre - across * halfSpan,
                         height: which.uprightHeight, width: which.uprightWidth,
                         thickness: which.uprightThickness, bearing: facing,
                         material: .sarsen)
        let right = Stone(id: "stone-\(numbers.second)",
                          position: centre + across * halfSpan,
                          height: which.uprightHeight, width: which.uprightWidth,
                          thickness: which.uprightThickness, bearing: facing,
                          material: .sarsen)

        switch state {
        case .asItWas:
            return [left, right, lintelFor(which, centre, facing)]

        case .asItStands:
            // Of the Great Trilithon only stone 56 still stands; its partner
            // fell and brought the lintel down with it. Two of the others
            // survive complete. Established.
            switch which {
            case .great:
                // Only stone 56 still stands; 55 fell in 1797 and brought
                // lintel 156 down with it. Established.
                return [right]
            case .northWestOuter, .southEastOuter:
                return [left, right, lintelFor(which, centre, facing)]
            default:
                return [left, right]
            }
        }
    }

    private static func lintelFor(_ which: Monument.Trilithon,
                                  _ centre: SIMD3<Double>, _ facing: Angle) -> Stone {
        // Seated into the uprights rather than balanced on them: two rounded
        // surfaces meeting at the nominal height leave a line of daylight, and
        // a real lintel sits in a mortice anyway.
        Stone(id: "stone-\(which.numbers.lintel)",
              position: SIMD3(centre.x, which.uprightHeight - 0.25, centre.z),
              height: which.lintelHeight,
              width: which.uprightWidth * 2 + which.gap,
              thickness: which.uprightThickness,
              bearing: facing,
              material: .sarsen)
    }

    // ── the bluestones ──────────────────────────────────────────────────────

    /// The bluestone circle, between the sarsens and the trilithon horseshoe.
    ///
    /// Perhaps sixty stones originally; forty are represented here, the honest
    /// middle of a Debated count. Dolerite and rhyolite carried from the
    /// Preseli Hills, 250 km away in Wales — the most remarkable single fact
    /// about the place.
    public static func bluestoneCircle(state: Monument.State = .asItWas) -> [Stone] {
        let radius = 12.2
        let count = 40
        return (0..<count).compactMap { i in
            // Roughly half survive, scattered rather than in a clean arc.
            if state == .asItStands && i % 5 < 2 { return nil }
            let bearing = Angle(degrees: Double(i) * 360 / Double(count) + 4)
            return Stone(// Petrie numbered the bluestone circle 31–49, but that covers only
            // the stones he could see. This reconstruction raises forty, so the
            // surplus carries a marked scheme rather than borrowing numbers
            // that belong to the trilithons.
            id: i < 19 ? "stone-\(31 + i)" : "bluestone-circle-\(i)",
                         position: WorldAxes.direction(azimuth: bearing) * radius,
                         height: 1.9 + Double(i % 5) * 0.16,
                         width: 0.95, thickness: 0.62,
                         bearing: bearing,
                         lean: Angle(degrees: Double((i * 7) % 9) - 4),
                         material: .bluestone)
        }
    }

    /// The inner bluestone horseshoe: an oval opening north-east, inside the
    /// trilithons and graded toward the apex as they are.
    public static func bluestoneHorseshoe(state: Monument.State = .asItWas) -> [Stone] {
        let apexBearing = (Monument.axisAzimuth + Angle(degrees: 180)).normalized
        let count = 19
        return (0..<count).compactMap { i in
            if state == .asItStands && i % 4 == 1 { return nil }
            // Spread over 270°, leaving the north-east open.
            let offset = -135.0 + Double(i) * (270.0 / Double(count - 1))
            let bearing = (apexBearing + Angle(degrees: offset)).normalized
            // Oval rather than circular: deeper along the axis.
            let radius = 6.2 + 1.5 * cos(Angle(degrees: offset).radians)
            return Stone(id: i < 12 ? "stone-\(61 + i)" : "bluestone-horseshoe-\(i)",
                         position: WorldAxes.direction(azimuth: bearing) * radius,
                         height: 2.5 - abs(offset) / 135.0 * 0.8,
                         width: 0.9, thickness: 0.6,
                         bearing: (bearing + Angle(degrees: 180)).normalized,
                         material: .bluestone)
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
        let apexBearing = (Monument.axisAzimuth + Angle(degrees: 180)).normalized
        return Stone(id: "stone-80",
                     position: WorldAxes.direction(azimuth: apexBearing) * 5.4,
                     // Recumbent: it lies flat, so its "height" is its thickness.
                     height: 0.6, width: 4.9, thickness: 1.0,
                     bearing: (Monument.axisAzimuth + Angle(degrees: 90)).normalized,
                     lean: state == .asItStands ? Angle(degrees: 6) : .zero,
                     material: .bluestone)
    }

    /// The Heel Stone: unshaped, leaning, out along the Avenue on the axis.
    ///
    /// The solstice sun rises a little to its left. A companion probably stood
    /// beside it forming a corridor — Debated, and a toggle in a later
    /// milestone rather than something quietly drawn in.
    public static func heelStone() -> Stone {
        Stone(id: "stone-96",
              position: WorldAxes.direction(azimuth: Monument.axisAzimuth)
                  * Monument.heelStoneDistance,
              height: Monument.heelStoneHeight,
              width: 2.4, thickness: 2.1,
              bearing: Monument.axisAzimuth,
              // Leans about 27° toward the circle — against its own facing,
              // hence the negative angle.
              lean: Angle(degrees: -27),
              material: .sarsen)
    }

    /// The Slaughter Stone, fallen at the north-east entrance, and the portal
    /// partner it once stood beside. The name is antiquarian invention:
    /// nothing was slaughtered on it.
    public static func slaughterStones(state: Monument.State = .asItWas) -> [Stone] {
        let axis = Monument.axisAzimuth
        let entrance = WorldAxes.direction(azimuth: axis) * 21.0
        let across = WorldAxes.direction(azimuth: (axis + Angle(degrees: 90)).normalized)

        switch state {
        case .asItStands:
            return [Stone(id: "stone-95",
                          position: entrance - across * 1.8,
                          height: 0.9, width: 6.4, thickness: 2.1,
                          bearing: axis, material: .sarsen)]
        case .asItWas:
            return [
                Stone(id: "stone-95", position: entrance - across * 1.8,
                      height: 4.3, width: 2.1, thickness: 1.1,
                      bearing: axis, material: .sarsen),
                Stone(id: "stone-E", position: entrance + across * 1.8,
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
    public static func stationStones(state: Monument.State = .asItWas) -> [Stone] {
        let radius = Monument.aubreyCircleDiameter / 2
        let axis = Monument.axisAzimuth
        // The offsets are not free: they are what makes the figure the surveyed
        // 80 m by 33 m. On an 87 m circle a 33 m short side subtends about
        // 44.6°, so the corners sit ±22.3° either side of the axis.
        //
        // The first attempt used ±12° because it looked symmetrical, and gave a
        // rectangle 18 m across — which would have quietly broken the lunar
        // alignment the whole figure exists to demonstrate.
        let corners: [(name: String, offset: Double, survives: Bool)] = [
            ("91", 22.3, true),
            ("92", 157.7, false),
            ("93", 202.3, true),
            ("94", 337.7, false)
        ]
        return corners.compactMap { corner in
            if state == .asItStands && !corner.survives { return nil }
            let bearing = (axis + Angle(degrees: corner.offset)).normalized
            return Stone(id: "stone-\(corner.name)",
                         position: WorldAxes.direction(azimuth: bearing) * radius,
                         height: state == .asItStands && corner.name == "93" ? 1.0 : 1.4,
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
