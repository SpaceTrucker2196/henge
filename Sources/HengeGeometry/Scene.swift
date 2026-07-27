import Foundation
import simd
import HengeAstro

/// The stones present in a given view of the monument.
///
/// M1 raises only what the light needs: the Great Trilithon, the Heel Stone,
/// and the ground they stand on. M2 fills in the sarsen circle, the bluestones
/// and the earthworks — the placement rules live here so that is an addition,
/// not a rewrite.
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

    /// The M1 scene: one trilithon and the Heel Stone, on the true axis.
    public static func milestoneOne(state: Monument.State = .asItWas) -> MonumentScene {
        var stones = trilithon(.great, state: state)
        stones.append(heelStone())
        return MonumentScene(state: state, stones: stones)
    }

    /// Place a trilithon in the horseshoe.
    ///
    /// The horseshoe opens to the north-east along the monument's axis, so the
    /// Great Trilithon stands at the closed south-west apex with its inner face
    /// square to the axis — which is what makes midwinter sunset fall through
    /// it, the alignment the midwinter argument turns on.
    public static func trilithon(_ which: Monument.Trilithon,
                                 state: Monument.State = .asItWas) -> [Stone] {
        let axis = Monument.axisAzimuth
        // Distance from the circle's centre out to the apex of the horseshoe.
        let apexDistance = 11.0
        let centreBearing = (axis + Angle(degrees: 180)).normalized
        let outward = WorldAxes.direction(azimuth: centreBearing)
        let centre = outward * apexDistance

        // The pair straddles the axis; each upright sits half a gap out.
        let acrossBearing = (axis + Angle(degrees: 90)).normalized
        let across = WorldAxes.direction(azimuth: acrossBearing)
        let halfSpan = which.uprightWidth / 2 + which.gap / 2

        let left = Stone(
            id: "\(which)-upright-left",
            position: centre - across * halfSpan,
            height: which.uprightHeight,
            width: which.uprightWidth,
            thickness: which.uprightThickness,
            bearing: axis
        )
        let right = Stone(
            id: "\(which)-upright-right",
            position: centre + across * halfSpan,
            height: which.uprightHeight,
            width: which.uprightWidth,
            thickness: which.uprightThickness,
            bearing: axis
        )

        switch state {
        case .asItStands:
            // Of the Great Trilithon only stone 56 still stands; its partner
            // and the lintel fell. Established — the ruin is surveyed fact.
            return which == .great ? [left] : [left, right]

        case .asItWas:
            // Seated a little into the uprights rather than balanced on them.
            // The two surfaces are both rounded, so meeting them exactly at the
            // nominal height leaves a notch of daylight along the joint — and a
            // real lintel sits in a mortice anyway.
            let seating = 0.25
            let lintel = Stone(
                id: "\(which)-lintel",
                position: SIMD3(centre.x, which.uprightHeight - seating, centre.z),
                height: which.lintelHeight,
                width: which.uprightWidth * 2 + which.gap,
                thickness: which.uprightThickness,
                bearing: axis
            )
            return [left, right, lintel]
        }
    }

    /// The Heel Stone: unshaped, leaning, out along the Avenue on the axis.
    ///
    /// The solstice sun rises a little to its left. A companion stone probably
    /// stood beside it forming a corridor — that is *debated*, and it is a
    /// toggle in later milestones rather than something quietly drawn in.
    public static func heelStone() -> Stone {
        let direction = WorldAxes.direction(azimuth: Monument.axisAzimuth)
        return Stone(
            id: "heel-stone",
            position: direction * Monument.heelStoneDistance,
            height: Monument.heelStoneHeight,
            width: 2.4,
            thickness: 2.1,
            bearing: Monument.axisAzimuth,
            // Leans about 27° from vertical *toward the circle* — that is,
            // against its own facing, hence the negative angle.
            lean: Angle(degrees: -27)
        )
    }
}
