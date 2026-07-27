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

    public var site: GeographicSite
    public var monumentState: Monument.State
    /// Time-lapse multiplier. 1 is real time; 100,000 sweeps a year in minutes.
    public var rate: Double
    public var isPlaying: Bool

    public var cameraAzimuth: Double
    public var cameraElevation: Double
    public var cameraDistance: Double

    public init(time: JulianDay = JulianDay(Date()),
                site: GeographicSite = .stonehenge,
                monumentState: Monument.State = .asItWas) {
        self.time = time
        self.site = site
        self.monumentState = monumentState
        self.rate = 1
        self.isPlaying = false
        // Looking north-east down the axis from inside the circle: the view
        // the monument was built to be seen from.
        self.cameraAzimuth = 229.9
        self.cameraElevation = 12
        self.cameraDistance = 58
    }

    private func clampRate() {
        rate = min(max(rate, 1), 100_000)
    }

    public var scene: MonumentScene {
        MonumentScene.milestoneOne(state: monumentState)
    }

    public var sun: HorizontalCoordinate {
        Sun.horizontal(at: time, site: site)
    }

    public var camera: Camera {
        Camera.orbiting(distance: Float(cameraDistance),
                        azimuthDegrees: Float(cameraAzimuth),
                        elevationDegrees: Float(cameraElevation),
                        target: SIMD3<Float>(0, 3, 0))
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
