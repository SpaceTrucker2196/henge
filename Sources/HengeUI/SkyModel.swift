import Foundation
import SwiftUI
import HengeAstro
import HengeGeometry
import HengeEngine

// NOTE: SwiftUI declares its own `Angle`, so HengeAstro's is qualified
// throughout this module rather than shadowed by an import order.

/// The moment being looked at, and everything that follows from it.
///
/// One source of truth for time: the renderer's sun and the readout's sun are
/// the same call into `HengeAstro`, so the picture and the numbers cannot
/// disagree — which is the whole claim the app makes.
@MainActor
@Observable
public final class SkyModel {

    /// Universal Time of the moment on screen.
    public var time: JulianDay {
        didSet { clampRate() }
    }

    /// Whose sky is overhead.
    public var viewpoint: Viewpoint

    /// Whose sun this is.
    ///
    /// The monument is a sundial, and a sundial only agrees with the clock in
    /// your pocket if it stands at your longitude. Reading the device's own
    /// zone makes the stones keep *your* time: solar noon lands when the sun
    /// is actually overhead where you are.
    public enum Viewpoint: String, Sendable, CaseIterable, Identifiable {
        /// The sun as it is here, from the device's time zone.
        case here = "Here"
        /// The sun over Salisbury Plain.
        case stonehenge = "Wiltshire"

        public var id: String { rawValue }
    }
    public var monumentState: Monument.State
    /// Time-lapse multiplier. 1 is real time; 100,000 sweeps a year in minutes.
    public var rate: Double
    public var isPlaying: Bool

    public var cameraAzimuth: Double
    public var cameraElevation: Double
    public var cameraDistance: Double
    public var station: Station

    /// Where a standing viewer is looking, relative to the station's own
    /// bearing, and how far up or down.
    public var lookBearingOffset: Double = 0
    public var lookPitch: Double = 0
    /// Field of view for the ground stations, in degrees. Pinching narrows it,
    /// which is what zoom means when you cannot walk closer.
    public var fieldOfView: Double = 62

    /// Where the visitor is standing.
    ///
    /// The preset stations are the views the monument was built to be seen
    /// from; the free camera is for looking at it as an object.
    public enum Station: String, Sendable, CaseIterable, Identifiable {
        case aerial = "Aerial"
        case altarStone = "Altar Stone"
        case heelStone = "Heel Stone"
        case avenue = "Avenue"

        public var id: String { rawValue }

        /// Eye height of a standing adult, for the ground-level stations.
        public static let eyeHeight = 1.7
    }

    public init(time: JulianDay = JulianDay(Date()),
                viewpoint: Viewpoint = .here,
                monumentState: Monument.State = .asItWas) {
        self.time = time
        self.viewpoint = viewpoint
        self.monumentState = monumentState
        self.rate = 1
        self.isPlaying = false
        // Looking north-east down the axis from inside the circle: the view
        // the monument was built to be seen from.
        self.cameraAzimuth = 229.9
        self.cameraElevation = 12
        self.cameraDistance = 92
        self.station = .aerial
    }

    private func clampRate() {
        rate = min(max(rate, 1), 100_000)
    }

    /// The whole monument, in the chosen state.
    public var site: GeographicSite {
        switch viewpoint {
        case .stonehenge: .stonehenge
        case .here: Self.deviceSite
        }
    }

    /// The site implied by the device's time zone.
    ///
    /// Longitude from the zone's *standard* offset at 15° per hour — daylight
    /// saving removed first, since it shifts the clock and not the Earth.
    ///
    /// This is deliberately approximate and says so: a time zone can be 7.5°
    /// wide, which is half an hour of solar time, and some are drawn far from
    /// their meridian for political reasons. The alternative is asking for the
    /// user's location, and a monument that works in a field with no signal
    /// should not need permission to tell you where the sun is. Latitude stays
    /// Stonehenge's, because the monument's geometry — the Station Stone
    /// rectangle above all — is only a rectangle at 51.18°.
    public static let deviceSite: GeographicSite = {
        let zone = TimeZone.current
        let now = Date()
        let standardOffset = Double(zone.secondsFromGMT(for: now))
            - zone.daylightSavingTimeOffset(for: now)
        return GeographicSite(latitude: GeographicSite.stonehenge.latitude,
                              longitude: HengeAstro.Angle(degrees: standardOffset / 3600 * 15),
                              elevation: GeographicSite.stonehenge.elevation,
                              name: zone.identifier)
    }()

    /// Which civil zone the clock is read in.
    public var civilTimeZone: TimeZone {
        viewpoint == .here ? .current : Self.siteTimeZone
    }

    public var scene: MonumentScene {
        MonumentScene.complete(state: monumentState)
    }

    /// Salisbury Plain. Loaded once — a 1.18 MB heightfield is not something to
    /// re-read on every view update.
    public static let terrain: TerrainModel? = try? TerrainModel.salisburyPlain()

    /// Where the ground is under a point, so the camera can stand on it.
    public func groundHeight(east: Double, south: Double) -> Double {
        Self.terrain?.groundHeight(east: east, south: south) ?? 0
    }

    /// Which star the sky turns about at this date, and how closely.
    ///
    /// Not a constant: in 2500 BC it was Thuban, and Polaris was more than
    /// twenty degrees from the pole and no use to anyone.
    public var poleStar: String {
        guard let result = Precession.poleStar(at: time.terrestrialTime) else { return "—" }
        return String(format: "%@ %.1f°", result.star.name, result.separation.degrees)
    }

    public var moon: HorizontalCoordinate {
        Moon.horizontal(at: time, site: site)
    }

    public var moonPhase: LunarPhase {
        Moon.phase(at: time.terrestrialTime)
    }

    /// How wide the moon's swing is at this point in the 18.6-year cycle, and
    /// whether that is near a standstill.
    public var standstill: String {
        let declination = Moon.standstillDeclination(at: time.terrestrialTime).degrees
        let obliquity = EarthOrientation.meanObliquity(at: time.terrestrialTime).degrees
        if declination > obliquity + 4.6 { return "major standstill" }
        if declination < obliquity - 4.6 { return "minor standstill" }
        return String(format: "%.1f°", declination)
    }

    public var sun: HorizontalCoordinate {
        Sun.horizontal(at: time, site: site)
    }

    public var camera: Camera {
        let axis = Monument.axisAzimuth
        let eye = Station.eyeHeight

        /// A ground-level view from a point on the plain, looking along a bearing.
        func standing(at position: SIMD3<Double>, looking bearing: HengeAstro.Angle) -> Camera {
            let ground = groundHeight(east: position.x, south: position.z)
            let from = SIMD3<Float>(Float(position.x), Float(ground + eye), Float(position.z))
            // Look level, not at a point — a person on the plain looks at the
            // horizon, and aiming at the circle's centre would tip the sunrise
            // out of frame at exactly the moment it matters.
            let heading = (bearing + HengeAstro.Angle(degrees: lookBearingOffset)).normalized
            let forward = WorldAxes.direction(azimuth: heading)
            let rise = tan(HengeAstro.Angle(degrees: lookPitch).radians) * 60
            let to = from + SIMD3<Float>(Float(forward.x * 60),
                                         Float(rise),
                                         Float(forward.z * 60))
            return Camera(position: from, target: to,
                          fieldOfView: Float(fieldOfView) * .pi / 180)
        }

        switch station {
        case .aerial:
            return Camera.orbiting(distance: Float(cameraDistance),
                                   azimuthDegrees: Float(cameraAzimuth),
                                   elevationDegrees: Float(cameraElevation),
                                   target: SIMD3<Float>(0, 3, 0))

        case .altarStone:
            // The view the monument is about: from the Altar Stone, out
            // through the Great Trilithon and down the Avenue to the north-east.
            let apex = WorldAxes.direction(azimuth: (axis + HengeAstro.Angle(degrees: 180)).normalized)
            return standing(at: apex * 5.4, looking: axis)

        case .heelStone:
            // Standing at the Heel Stone looking back into the circle.
            return standing(at: WorldAxes.direction(azimuth: axis) * (Monument.heelStoneDistance + 4),
                            looking: (axis + HengeAstro.Angle(degrees: 180)).normalized)

        case .avenue:
            // Coming up the Avenue, as anyone arriving would have.
            return standing(at: WorldAxes.direction(azimuth: axis) * 190,
                            looking: (axis + HengeAstro.Angle(degrees: 180)).normalized)
        }
    }

    public var sceneState: SceneState {
        SceneState.at(time, site: site, camera: camera)
    }

    // ── the almanac ─────────────────────────────────────────────────────────

    public var calendarDate: CalendarDate { time.calendarDate }

    public var formattedDate: String {
        let d = calendarDate
        let day = Int(floor(d.day))
        let names = ["", "January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        let month = (1...12).contains(d.month) ? names[d.month] : "?"
        // Years before 1 are shown as BC, counting the astronomical year zero
        // as 1 BC — the convention every ephemeris uses.
        let year = d.year > 0 ? "\(d.year)" : "\(1 - d.year) BC"
        return "\(day) \(month) \(year)"
    }

    /// Civil time zone at the site. Wiltshire keeps London time.
    public static let siteTimeZone = TimeZone(identifier: "Europe/London") ?? .gmt

    /// Civil local time, with the zone named — BST through the summer, GMT
    /// through the winter.
    ///
    /// Returns nil outside the era in which civil time means anything. Britain
    /// had no standard time before the railways and no summer time before 1916,
    /// and extrapolating the current rules back to 2500 BC would be inventing a
    /// clock the builders did not have. `apparentSolarTime` is what serves
    /// then, and it is the truer answer at a monument anyway.
    public var formattedLocalTime: String? {
        let date = calendarDate
        guard date.year >= 1848 else { return nil }

        let moment = Date(timeIntervalSince1970: (time.value - 2440587.5) * 86400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = civilTimeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: moment)

        let zone = civilTimeZone
        let label = zone.abbreviation(for: moment)
            ?? (zone.isDaylightSavingTime(for: moment) ? "DST" : "STD")
        return String(format: "%02d:%02d:%02d %@",
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, label)
    }

    /// Local apparent solar time — the clock the monument itself keeps.
    public var formattedSolarTime: String {
        let hours = Sun.apparentSolarTime(at: time, site: site)
        let totalSeconds = Int((hours * 3600).rounded())
        return String(format: "%02d:%02d:%02d",
                      (totalSeconds / 3600) % 24, (totalSeconds % 3600) / 60,
                      totalSeconds % 60)
    }

    public var formattedTime: String {
        let fraction = calendarDate.day - floor(calendarDate.day)
        let totalSeconds = Int((fraction * 86400).rounded())
        return String(format: "%02d:%02d:%02d UT",
                      totalSeconds / 3600, (totalSeconds % 3600) / 60, totalSeconds % 60)
    }

    public var sunriseToday: JulianDay? {
        RiseSet.time(of: .rise, on: calendarDate, site: site)
    }

    public var sunsetToday: JulianDay? {
        RiseSet.time(of: .set, on: calendarDate, site: site)
    }

    public var sunriseAzimuth: HengeAstro.Angle? {
        RiseSet.sunriseAzimuth(on: calendarDate, site: site)
    }

    /// How far the sunrise bearing sits from the monument's built axis.
    ///
    /// Near zero on midsummer morning — and closer in 2500 BC than today,
    /// because the obliquity has shifted. That gap is the point, not an error.
    public var axisDeviation: HengeAstro.Angle? {
        guard let azimuth = sunriseAzimuth else { return nil }
        return azimuth.separation(to: Monument.axisAzimuth)
    }

    // ── gestures ────────────────────────────────────────────────────────────

    /// Drag. From the air this orbits the monument; on the ground it turns your
    /// head, because walking backwards through a stone circle to get a wider
    /// view is not a thing a person can do.
    public func drag(by translation: SIMD2<Double>) {
        if station == .aerial {
            cameraAzimuth = (cameraAzimuth - translation.x * 0.35)
                .truncatingRemainder(dividingBy: 360)
            if cameraAzimuth < 0 { cameraAzimuth += 360 }
            cameraElevation = min(max(cameraElevation + translation.y * 0.22, -2), 85)
        } else {
            lookBearingOffset -= translation.x * 0.22
            // Stop short of straight up and straight down: the look-at basis
            // degenerates there and the horizon rolls over.
            lookPitch = min(max(lookPitch + translation.y * 0.18, -35), 70)
        }
    }

    /// Pinch. From the air it changes range; on the ground it changes the field
    /// of view, which is the honest equivalent — you cannot move the ground.
    public func zoom(by scale: Double) {
        guard scale > 0 else { return }
        if station == .aerial {
            cameraDistance = min(max(cameraDistance / scale, 14), 420)
        } else {
            fieldOfView = min(max(fieldOfView / scale, 24), 96)
        }
    }

    /// Put the view back where the station intends it to point.
    public func recentre() {
        lookBearingOffset = 0
        lookPitch = 0
        fieldOfView = 62
        cameraElevation = 12
        cameraDistance = 92
    }

    // ── playback ────────────────────────────────────────────────────────────

    /// Advance by a wall-clock interval scaled by the current rate.
    public func advance(byRealSeconds seconds: Double) {
        guard isPlaying else { return }
        time = time + (seconds * rate) / 86400.0
    }

    public func jump(toDaysFromNow days: Double) {
        time = time + days
    }
}

public extension JulianDay {
    /// From a `Date`, via UTC. Dates are a modern convenience — everything
    /// before 1582 is entered as a `CalendarDate` instead.
    init(_ date: Date) {
        self.init(date.timeIntervalSince1970 / 86400.0 + 2440587.5)
    }
}
