import Foundation
import simd
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

    // ── the geometry overlay ────────────────────────────────────────────────

    /// Whether the researched lines — cardinals, axis, station rectangle,
    /// Avenue, and the live sun and moon bearings — are drawn on the turf.
    public var showsAlignmentOverlay = false
    /// Whether Hoyle's gold markers stand in the Aubrey holes. A modern
    /// hypothesis, badged as one — see `Lore` and research/lunar-markers.md.
    public var showsLunarMarkers = false

    /// Changes exactly when the overlay's geometry must be rebuilt: on a mode
    /// switch, when a marker changes *disc*, or when a bearing line has
    /// drifted half a degree — about the ribbon's own width at its far end.
    ///
    /// Two lessons from review are load-bearing here. The markers hash the
    /// same `discIndex` rounding the geometry uses — hashing the raw hole
    /// value left the moon's marker standing one hole behind its disc for
    /// three quarters of every cycle, because the two roundings transition at
    /// different phases. And at time-lapse rates the bearings step every
    /// tick, so `SceneView` additionally rate-limits rebuilds on the wall
    /// clock; this key alone is not the whole throttle.
    public var overlayKey: Int {
        guard showsAlignmentOverlay || showsLunarMarkers else { return 0 }
        var hasher = Hasher()
        hasher.combine(showsAlignmentOverlay)
        hasher.combine(showsLunarMarkers)
        if showsAlignmentOverlay {
            hasher.combine(sun.altitude.degrees > -0.8
                           ? Int((sun.azimuth.degrees * 2).rounded()) : -1)
            hasher.combine(moon.altitude.degrees > -0.8
                           ? Int((moon.azimuth.degrees * 2).rounded()) : -1)
        }
        if showsLunarMarkers {
            let markers = aubrey
            hasher.combine(GeometryOverlay.discIndex(forHole: markers.sun))
            hasher.combine(GeometryOverlay.discIndex(forHole: markers.moon))
            hasher.combine(GeometryOverlay.discIndex(forHole: markers.node))
        }
        return hasher.finalize()
    }

    /// The survey lines never move, and draping them samples the terrain a
    /// thousand times — built once, not per rebuild. Ignored by observation
    /// (a cache is not state the UI reacts to) and memoised by hand rather
    /// than `lazy`, because a lazy initialiser runs outside the main-actor
    /// isolation `groundHeight` needs.
    @ObservationIgnored private var cachedSurveyPieces: [GeometryOverlay.Piece]?

    private func surveyPieces() -> [GeometryOverlay.Piece] {
        if let cached = cachedSurveyPieces { return cached }
        let pieces = GeometryOverlay.surveyPieces(ground: groundHeight)
        cachedSurveyPieces = pieces
        return pieces
    }

    /// Everything the overlay currently draws.
    public func overlayPieces() -> [GeometryOverlay.Piece] {
        guard showsAlignmentOverlay || showsLunarMarkers else { return [] }
        var pieces: [GeometryOverlay.Piece] = []
        if showsAlignmentOverlay {
            pieces += surveyPieces()
            // A bearing line for a body below the horizon would point at
            // nothing you could check by looking.
            if sun.altitude.degrees > -0.8 {
                pieces.append(GeometryOverlay.sunRay(azimuth: sun.azimuth,
                                                     ground: groundHeight))
            }
            if moon.altitude.degrees > -0.8 {
                pieces.append(GeometryOverlay.moonRay(azimuth: moon.azimuth,
                                                      ground: groundHeight))
            }
        }
        if showsLunarMarkers {
            pieces += GeometryOverlay.markerStones(at: time.terrestrialTime,
                                                   ground: groundHeight)
        }
        return pieces
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

    /// How far the eye must clear the turf, metres.
    ///
    /// Not zero: a camera exactly on the ground plane sees the horizon through
    /// the grass and clips into the soil banked around the stones.
    public static let minimumClearance = 0.35

    /// Keep the eye above the ground it is actually over.
    ///
    /// The orbit camera could be pitched below the horizon far enough to put
    /// the eye under Salisbury Plain, at which point you are looking up at the
    /// underside of the terrain mesh — which is unlit, single-sided and reads
    /// as the world having been turned off. On a heightfield "below ground" is
    /// a different number at every point, so this asks the terrain rather than
    /// clamping against zero.
    private func liftAboveGround(_ camera: Camera) -> Camera {
        let ground = groundHeight(east: Double(camera.position.x),
                                  south: Double(camera.position.z))
        let floor = Float(ground + SkyModel.minimumClearance)
        guard camera.position.y < floor else { return camera }

        var lifted = camera
        // Raise the target with the eye, so the view direction is preserved and
        // the camera does not swing to look at its own feet as it is clamped.
        let rise = floor - camera.position.y
        lifted.position.y = floor
        lifted.target.y += rise
        return lifted
    }

    public var camera: Camera {
        liftAboveGround(rawCamera)
    }

    private var rawCamera: Camera {
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
            var orbit = Camera.orbiting(distance: Float(cameraDistance),
                                        azimuthDegrees: Float(cameraAzimuth),
                                        elevationDegrees: Float(cameraElevation),
                                        target: SIMD3<Float>(0, 3, 0))
            orbit.fieldOfView = Float(fieldOfView) * .pi / 180
            return orbit

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

    /// Wall-clock seconds the wind has been blowing this session.
    ///
    /// Advanced from real elapsed time, never from the astronomical clock, and
    /// never gated on `isPlaying` — the breeze does not stop because you paused
    /// the sun. See `SceneState.windTime`.
    public var windTime: Double = 0

    /// How hard it is blowing at the top of the sward, m/s. Zero for a still
    /// day. See `SceneState.windSpeed` for why this is so much smaller than any
    /// figure a weather station would give.
    public var windSpeed: Double = 0.45

    /// Whether the ceremony torch is lit. See `SceneState.torchlight`.
    public var torchlight = false

    /// The sky's condition — dressing the user chooses, defaulting clear.
    public var weather: Weather = .clear

    /// Fraction of the monument rebuilt during a ruin/whole switch, nil
    /// when no rebuild is running. Drives the progress card — the rebuild
    /// happens off the main actor precisely so this can move.
    public var rebuildProgress: Double?

    /// Whether the named stars carry their names on screen.
    public var showsStarLabels = false

    /// Whether the zodiac constellations carry their glyphs on the sky.
    public var showsZodiac = false

    /// Whether the hand-drawn constellation figures are joined on the sky.
    public var showsConstellationLines = false

    // ── the year bar ────────────────────────────────────────────────────────

    /// The solved civil year, cached until the shown date leaves it — the
    /// syzygy search is thirty root-finds, which is nothing once and a
    /// frame-rate tax if recomputed per draw.
    @ObservationIgnored private var cachedYear: YearAlmanac.Year?

    public var yearAlmanac: YearAlmanac.Year {
        let shown = calendarDate.year
        if let cached = cachedYear, cached.year == shown { return cached }
        let solved = YearAlmanac.solve(year: shown)
        cachedYear = solved
        return solved
    }

    /// Where the shown moment falls along its civil year, 0...1.
    public var yearFraction: Double {
        max(0, min(1, yearAlmanac.fraction(of: time)))
    }

    /// Scrub along the year by whole days, so the hour of day — a sunrise
    /// being watched — survives the jump.
    public func scrubYear(toFraction fraction: Double) {
        let year = yearAlmanac
        let clamped = max(0, min(1, fraction))
        let target = year.start.value
            + clamped * (year.end.value - year.start.value)
        time = time + (target - time.value).rounded()
    }

    /// The star catalogue, loaded once beside the terrain.
    private static let starCatalog = StarCatalog.load()

    /// One on-screen star label: name and unit-fraction position.
    public struct StarLabel: Identifiable {
        public let id: String
        public let x: Double
        public let y: Double
    }

    /// A label pinned to a point on the turf, with the measurement it names.
    public struct GroundLabel: Identifiable, Hashable {
        public let id: String
        public let detail: String?
        public let x: Double
        public let y: Double
        /// Cardinal letters draw larger than measurements.
        public let isCardinal: Bool
    }

    /// The ground plan's own labels: cardinals, the surveyed features, and
    /// their measurements, projected onto the terrain the way the star
    /// labels project onto the sky. Shown with the geometry overlay —
    /// the lines say where, these say what and how large. Figures are the
    /// surveyed ones from `Monument` and `Earthwork` (Cleal et al. 1995);
    /// the wiki's geometry page holds the sources and the tiers.
    public func groundLabels(aspect: Double) -> [GroundLabel] {
        guard showsAlignmentOverlay else { return [] }
        let eye = camera
        let terrain = Self.terrain

        func project(east: Double, south: Double, lift: Double = 0.4)
            -> (x: Double, y: Double)? {
            let height = (terrain?.groundHeight(east: east, south: south) ?? 0)
                + lift
            let world = SIMD3<Float>(Float(east), Float(height), Float(south))
            let direction = world - eye.position
            guard length(direction) > 0.5 else { return nil }
            return eye.screenFraction(of: normalize(direction),
                                      aspect: Float(aspect))
        }

        var labels: [GroundLabel] = []
        func add(_ name: String, _ detail: String?, east: Double,
                 south: Double, cardinal: Bool = false) {
            if let point = project(east: east, south: south) {
                labels.append(GroundLabel(id: name, detail: detail,
                                          x: point.x, y: point.y,
                                          isCardinal: cardinal))
            }
        }

        // Cardinals on the turf just beyond the earthwork, from true north.
        let cardinalRadius = 70.0
        add("N", nil, east: 0, south: -cardinalRadius, cardinal: true)
        add("E", nil, east: cardinalRadius, south: 0, cardinal: true)
        add("S", nil, east: 0, south: cardinalRadius, cardinal: true)
        add("W", nil, east: -cardinalRadius, south: 0, cardinal: true)

        // The features, each with its surveyed figure.
        let axis = Monument.axisAzimuth.degrees * Double.pi / 180
        add("Axis", "az \(Monument.axisAzimuth.degrees)°",
            east: 30 * sin(axis), south: -30 * cos(axis))
        add("Sarsen circle",
            "\(Int(Monument.sarsenCircleDiameter)) m across",
            east: 0, south: Monument.sarsenCircleDiameter / 2 + 2)
        add("Aubrey ring",
            "\(Int(Monument.aubreyCircleDiameter)) m · 56 holes",
            east: -Monument.aubreyCircleDiameter / 2 * 0.7071,
            south: Monument.aubreyCircleDiameter / 2 * 0.7071)
        add("Enclosure",
            "\(Int(Earthwork.ditchCentre * 2)) m across",
            east: -Earthwork.ditchCentre * 0.7071,
            south: -Earthwork.ditchCentre * 0.7071)
        add("Heel Stone",
            "\(Int(Monument.heelStoneDistance)) m out",
            east: Monument.heelStoneDistance * sin(axis),
            south: -Monument.heelStoneDistance * cos(axis))
        add("Avenue",
            "\(Int(Monument.avenueWidth)) m wide",
            east: 110 * sin(axis), south: -110 * cos(axis))

        return labels
    }

    /// The labels currently on screen.
    ///
    /// Star names only after dark — a name floating on a starless sky would
    /// label nothing — and only for stars above the horizon. The Moon is
    /// different: it hangs in the daytime sky half the month, drawn at its
    /// true topocentric place, so its label rides whenever the disc is up.
    public func starLabels(aspect: Double) -> [StarLabel] {
        guard showsStarLabels || showsZodiac else { return [] }
        let eye = camera
        var labels: [StarLabel] = []

        if showsStarLabels, moon.altitude.degrees > 1.5 {
            let v = moon.unitVector
            if let point = eye.screenFraction(of: SIMD3(Float(v.x), Float(v.y), Float(v.z)),
                                              aspect: Float(aspect)) {
                labels.append(StarLabel(id: "Moon", x: point.x, y: point.y))
            }
        }

        if sun.altitude.degrees < -3, showsZodiac {
            let rows = StarField.worldRows(
                siderealTime: Sidereal.greenwichMean(at: time), site: site)
            labels += ZodiacConstellation.all.compactMap { sign in
                // Centres precess with their stars — the same route the
                // catalogue takes, minus proper motion, which a region
                // spanning tens of degrees does not feel.
                let dated = StarField.equatorialOfDate(
                    rightAscension: sign.rightAscension,
                    declination: sign.declination,
                    at: time.terrestrialTime)
                let d = StarField.unitVector(rightAscension: dated.rightAscension,
                                             declination: dated.declination)
                let world = SIMD3<Double>(
                    rows.east.x * d.x + rows.east.y * d.y + rows.east.z * d.z,
                    rows.up.x * d.x + rows.up.y * d.y + rows.up.z * d.z,
                    rows.south.x * d.x + rows.south.y * d.y + rows.south.z * d.z)
                guard world.y > 0.05 else { return nil }
                guard let point = eye.screenFraction(of: SIMD3<Float>(world),
                                                     aspect: Float(aspect)) else { return nil }
                return StarLabel(id: "\(sign.symbol) \(sign.name)",
                                 x: point.x, y: point.y)
            }
        }

        if sun.altitude.degrees < -3, showsStarLabels, let catalog = Self.starCatalog {
            let rows = StarField.worldRows(
                siderealTime: Sidereal.greenwichMean(at: time), site: site)

            // The wanderers carry their names beside the fixed stars'.
            labels += PlanetEphemeris.all(at: time.terrestrialTime).compactMap { entry in
                let d = StarField.unitVector(
                    rightAscension: entry.place.rightAscension,
                    declination: entry.place.declination)
                let world = SIMD3<Double>(
                    rows.east.x * d.x + rows.east.y * d.y + rows.east.z * d.z,
                    rows.up.x * d.x + rows.up.y * d.y + rows.up.z * d.z,
                    rows.south.x * d.x + rows.south.y * d.y + rows.south.z * d.z)
                guard world.y > 0.03 else { return nil }
                guard let point = eye.screenFraction(of: SIMD3<Float>(world),
                                                     aspect: Float(aspect)) else { return nil }
                return StarLabel(id: entry.planet.name, x: point.x, y: point.y)
            }

            labels += catalog.namedStars(at: time.terrestrialTime).compactMap { star in
                let world = SIMD3<Double>(
                    rows.east.x * star.direction.x + rows.east.y * star.direction.y
                        + rows.east.z * star.direction.z,
                    rows.up.x * star.direction.x + rows.up.y * star.direction.y
                        + rows.up.z * star.direction.z,
                    rows.south.x * star.direction.x + rows.south.y * star.direction.y
                        + rows.south.z * star.direction.z)
                guard world.y > 0.03 else { return nil }
                guard let point = eye.screenFraction(of: SIMD3<Float>(world),
                                                     aspect: Float(aspect)) else { return nil }
                return StarLabel(id: star.name, x: point.x, y: point.y)
            }
        }
        return labels
    }

    public var sceneState: SceneState {
        var state = SceneState.at(time, site: site, camera: camera)
        state.windTime = windTime
        state.windSpeed = Float(windSpeed)
        // A torch is carried, and nobody carries one four hundred metres up:
        // from the aerial station the same light would hang sourceless in
        // the night sky and wash the monument warm. It relights the moment
        // you stand back on the ground.
        state.torchlight = torchlight && station != .aerial
        state.weather = weather
        state.constellationLines = showsConstellationLines
        return state
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

    /// Pinch is a lens, everywhere — the owner's order: zooming out widens
    /// the field of view so more of the sky comes into frame, like backing
    /// a lens off toward wide-angle, at every station including the air.
    /// The wide stop at 110° is where a rectilinear projection starts to
    /// smear the corners; the long stop at 22° is a decent birding lens.
    public func zoom(by scale: Double) {
        guard scale > 0 else { return }
        fieldOfView = min(max(fieldOfView / scale, 22), 110)
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
    ///
    /// The wind is advanced first and unconditionally: it keeps wall-clock
    /// time, so it must not be scaled by the rate and must not stop when the
    /// astronomical clock is paused.
    public func advance(byRealSeconds seconds: Double) {
        windTime += seconds
        guard isPlaying else { return }
        time = time + (seconds * rate) / 86400.0
    }

    // ── the shape of the day ────────────────────────────────────────────────

    /// Hours the site's clock runs ahead of UT.
    ///
    /// Falls back to the longitude when civil time means nothing — there were
    /// no time zones in 2500 BC, and the honest local day there is the solar
    /// one, 15° to the hour.
    public var clockOffsetHours: Double {
        let year = calendarDate.year
        if year > 1900, year < 2100 {
            let date = Date(timeIntervalSince1970: (time.value - 2_440_587.5) * 86_400)
            return Double(civilTimeZone.secondsFromGMT(for: date)) / 3600
        }
        return site.longitude.degrees / 15
    }

    /// Julian Day of local midnight beginning the day currently shown.
    public var dayStart: JulianDay {
        let offset = clockOffsetHours / 24
        // JD begins at noon, so shift by half a day before flooring.
        return JulianDay((time.value + offset + 0.5).rounded(.down) - 0.5 - offset)
    }

    /// Where in the day we are, 0 at local midnight to 1 at the next.
    public var fractionOfDay: Double {
        min(max(time.value - dayStart.value, 0), 1)
    }

    /// The sun's altitude across the whole local day.
    ///
    /// Sampled rather than solved. Solving for each twilight boundary means six
    /// root-finds that can all fail — inside the polar circles the sun may
    /// never cross a threshold at all, and this app runs anywhere and across
    /// five millennia. Sampling the altitude and colouring by band is
    /// unconditional: it draws a correct bar for a Wiltshire equinox and for a
    /// polar summer without a special case for either.
    public func dayProfile(samples: Int = 144) -> [Double] {
        let start = dayStart
        let site = self.site
        return (0..<samples).map { step in
            let moment = start + Double(step) / Double(samples)
            return Sun.horizontal(at: moment, site: site).altitude.degrees
        }
    }

    /// Move to a fraction through the local day, keeping the date.
    public func scrub(toFractionOfDay fraction: Double) {
        time = dayStart + min(max(fraction, 0), 1)
    }

    // ── alignment ───────────────────────────────────────────────────────────

    /// The horizon the monument actually looks at, along a given bearing.
    ///
    /// Only meaningful at the real site; anywhere else the heightfield is the
    /// wrong hill.
    public func horizon(along bearing: HengeAstro.Angle) -> HengeAstro.Angle {
        guard viewpoint == .stonehenge else { return .zero }
        return SkyModel.terrain?.horizonAltitude(azimuth: bearing) ?? .zero
    }

    /// How far each alignment is from true today, and whether it is on.
    ///
    /// Recomputed per read like `upcoming`, and for the same reason: the date
    /// can be anywhere in five millennia.
    public var alignments: [(alignment: HengeGeometry.Alignment,
                             deviation: HengeAstro.Angle, isOn: Bool)] {
        // Qualified because SwiftUI has an `Alignment` of its own — the same
        // collision `Angle` has, handled the same way rather than by an import
        // order that could change under someone.
        HengeGeometry.Alignment.allCases.compactMap { alignment in
            let horizon = horizon(along: alignment.bearing)
            guard let deviation = AlignmentSolver.deviation(
                of: alignment, on: calendarDate, site: site,
                horizonAltitude: horizon) else { return nil }
            return (alignment, deviation,
                    deviation.degrees <= AlignmentSolver.solarDiameter.degrees)
        }
    }

    /// Jump to the morning the sun reaches its extreme — the day the monument
    /// is built around, found rather than assumed.
    public func jumpToExtreme(of alignment: HengeGeometry.Alignment) {
        let horizon = horizon(along: alignment.bearing)
        guard let extreme = AlignmentSolver.extreme(
            for: alignment, year: calendarDate.year,
            site: site, horizonAltitude: horizon) else { return }
        time = RiseSet.time(of: alignment.isRising ? .rise : .set,
                            on: extreme.date, site: site,
                            horizonAltitude: horizon) ?? JulianDay(extreme.date)
    }

    // ── what is coming ──────────────────────────────────────────────────────

    /// The next few months of sky, solved fresh from the current moment.
    ///
    /// Not cached: the model's whole job is that the time can be anywhere in
    /// five millennia, and a cache keyed on "now" would be wrong the moment
    /// anyone scrubbed. A hundred and twenty days costs a few milliseconds.
    public var upcoming: [AstronomicalEvent] {
        Events.upcoming(from: time, days: 120)
    }

    /// Where the sun, moon and lunar nodes fall on the fifty-six holes, and
    /// whether the ring would call this an eclipse season.
    ///
    /// A toy, and labelled one wherever it appears — see `AubreyRing`.
    public var aubrey: AubreyRing.Markers {
        AubreyRing.markers(at: time.terrestrialTime)
    }

    public var isAubreyEclipseSeason: Bool {
        AubreyRing.isEclipseSeason(at: time.terrestrialTime)
    }

    // ── the wheel of the year ───────────────────────────────────────────────

    /// The next station of the year, and how far off it is.
    ///
    /// Computed from where the sun actually is, so it keeps working in 2500 BC
    /// where the June solstice falls in July.
    public var nextStation: (station: WheelStation, instant: JulianDay) {
        Wheel.nextStation(after: time)
    }

    public var formattedNextStation: String {
        let next = nextStation
        let days = next.instant.value - time.value
        if days < 1 {
            return String(format: "%@ in %.0f h", next.station.name, days * 24)
        }
        return String(format: "%@ in %.0f d", next.station.name, days)
    }

    /// What the app is prepared to say about the coming station, tier and all.
    public var stationNote: LoreNote {
        Lore.note(for: nextStation.station)
    }

    /// Jump to a station of the year. Lands on the instant the sun reaches it,
    /// not on a calendar date — the distinction the whole module exists for.
    public func jump(to station: WheelStation, year: Int? = nil) {
        time = Wheel.universalInstant(of: station, year: year ?? time.calendarDate.year)
    }

    /// Jump to the next occurrence of a station, whichever year that falls in.
    public func jumpToNext(_ station: WheelStation) {
        let thisYear = Wheel.universalInstant(of: station, year: time.calendarDate.year)
        time = thisYear.value > time.value
            ? thisYear
            : Wheel.universalInstant(of: station, year: time.calendarDate.year + 1)
    }

    /// Dawn on the day of a station, at the site being shown — the moment the
    /// monument is actually about. Falls back to the station's own instant
    /// inside the polar circles, where the sun may not rise that day.
    public func jumpToSunrise(of station: WheelStation) {
        let instant = Wheel.universalInstant(of: station, year: time.calendarDate.year)
        // Measured off the baked heightfield rather than assumed flat: the ridge
        // the midsummer sun clears is about seven tenths of a degree up, which
        // moves the bearing by more than a degree. Only meaningful when the
        // terrain is the one under the monument.
        let horizon: HengeAstro.Angle = viewpoint == .stonehenge
            ? (SkyModel.terrain?.horizonAltitude(azimuth: Monument.axisAzimuth) ?? .zero)
            : .zero
        time = RiseSet.time(of: .rise, on: instant.calendarDate,
                            site: site, horizonAltitude: horizon) ?? instant
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
