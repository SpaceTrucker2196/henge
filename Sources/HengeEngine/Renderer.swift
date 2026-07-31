import Foundation
import Metal
import MetalKit
import simd
import HengeAstro
import HengeGeometry

/// The sky's mood, chosen rather than simulated.
///
/// Weather is dressing, not forecast: the user picks a condition and the
/// renderer draws its consequences. The *decisions* — how much cloud, how
/// much of the sun survives it, how wet the world is, when frost melts —
/// are pure functions here, where a test can hold each one, and the shader
/// only ever sees their results in a uniform. `clear` is the default and
/// contributes exactly nothing, which is what keeps every weather term out
/// of the shadow-agreement oracle's frames.
public enum Weather: String, Sendable, CaseIterable, Hashable {
    case clear
    case overcast
    case rain
    case frost

    /// Fraction of sky the cloud field aims to cover.
    public var cloudCover: Double {
        switch self {
        case .clear: 0
        case .overcast: 0.9
        case .rain: 1.0
        // A frost morning is a clear morning — that is why it froze. Zero,
        // exactly: the first cut gave it a decorative 0.12 veil, and the
        // render test rightly refused the contradiction — once the frost
        // melts, a frost day must be byte-identical to a clear one.
        case .frost: 0
        }
    }

    /// How much of the sun's radiance reaches the ground.
    ///
    /// Scaled *before* the shader sees the radiance, so the direct light,
    /// the shadows' contrast, the sun disc and the golden-hour beams all
    /// dim together without one of them being forgotten.
    public var sunTransmission: Double {
        switch self {
        case .clear, .frost: 1.0
        case .overcast: 0.32
        case .rain: 0.2
        }
    }

    /// How soaked the world is: rain wets everything the damp course wets,
    /// all the way up.
    public var wetness: Double { self == .rain ? 1 : 0 }

    /// Frost against the climbing sun: full through the night and dawn,
    /// gone by the time the sun stands 12° high — melted, as the real thing
    /// is by mid-morning. A Hermite fade from 4° so the going is gradual.
    public static func frostAmount(condition: Weather,
                                   sunAltitudeDegrees: Double) -> Double {
        guard condition == .frost else { return 0 }
        let t = min(max((sunAltitudeDegrees - 4) / 8, 0), 1)
        return 1 - t * t * (3 - 2 * t)
    }
}

/// Everything the renderer needs to know about the moment being drawn.
public struct SceneState: Sendable {

    /// Whether earth is banked against the stones' feet.
    ///
    /// Off in the opacity suite, which asks whether a stone's silhouette has
    /// holes in it by comparing pixels against the background. A soil bank in
    /// front of the base is a different colour from the stone and counts as a
    /// hole — the fourth detail layer to interfere with that measurement, and
    /// the reason each one gets its own switch rather than one blanket "plain"
    /// mode: a suite should turn off exactly what it must and no more.
    public var soilBanks: Bool

    /// Whether individual blades are drawn near the viewer.
    ///
    /// Off in the rendering tests, which measure ground luminance and would
    /// otherwise be measuring grass.
    public var grassBlades: Bool

    /// Wind speed at the surface, m/s. Zero stops the grass dead.
    ///
    /// Default 0.45 — barely a stir. It began at 4.5, the annual mean at 10 m
    /// over Salisbury Plain, which is correct for 10 m and wrong for the top of
    /// the sward: the wind profile falls off sharply through the boundary
    /// layer, and grass at ankle height feels a fraction of what an anemometer
    /// on a mast reads. It went to 1.8 on that reasoning and then to a quarter
    /// of that by eye, which is the right way round — the physics says the
    /// number is much smaller than the mast reading, and the eye says how much
    /// smaller. It also simply looked hurried against a monument whose whole
    /// subject is slowness.
    public var windSpeed: Float

    /// The bearing the wind blows *from*, degrees.
    ///
    /// 250° — south-westerly, which is the prevailing wind over southern
    /// England for most of the year. A detail nobody will name, and one that
    /// would be quietly wrong if the gusts crossed the plain the other way.
    public var windBearing: Double

    /// Seconds of wind, on the wall clock.
    ///
    /// **Not the astronomical clock, and this is the whole design.** Time in
    /// this app runs at up to a day a second. A wind that scaled with it would
    /// be a strobe; a wind frozen while time is paused would be a photograph.
    /// So the breeze keeps its own time, advancing in real seconds whether the
    /// sun is racing, crawling or stopped.
    public var windTime: Double

    /// Whether the stones carry four thousand years of weather.
    ///
    /// Separate from `surfaceTexturing` because it is a separate claim, and
    /// because the test that measures it needs to render the same stone both
    /// ways and compare.
    public var weathering: Bool

    /// Whether a carried torch lights the stones — the ceremony mode.
    ///
    /// Off by default: it is a mode you choose, like the overlay, not a
    /// state of the world. The torch rides at the camera's hand, so walking
    /// the circle carries the light with you.
    public var torchlight: Bool

    /// Whether the golden hours march light shafts through the haze.
    ///
    /// On everywhere the app runs; a switch because it is one more detail
    /// layer standing between a measurement test and the thing it measures,
    /// and each of those gets its own switch (see `soilBanks`). The pass also
    /// gates itself on the sun's altitude — see `Haze.twilightBoost` — so
    /// outside the golden hours this flag changes nothing at all.
    public var lightShafts: Bool

    /// Whether surfaces carry their photographic detail.
    ///
    /// On everywhere the app runs. Off in the tests that measure *geometry* —
    /// where a shadow's edge falls, how wide its penumbra is — and the reason
    /// is worth stating, because switching it off in a test is exactly the kind
    /// of move that hides a bug.
    ///
    /// Those tests read the shadow edge out of image luminance. Textured turf
    /// varies in luminance by more than the shadow does: the measured lit/shade
    /// contrast fell from comfortably past the guard threshold to 0.03–0.045,
    /// with grain of comparable amplitude sitting on top of it. The edge is
    /// still exactly where it was — but the instrument can no longer see it,
    /// and loosening the guard would have meant measuring noise and calling it
    /// agreement. So the geometry oracle renders untextured, and a separate
    /// test asserts the shipping path has texturing on.
    public var surfaceTexturing: Bool

    /// The sky's condition. See `Weather` — clear by default, and clear
    /// means every weather term is exactly absent.
    public var weather: Weather

    /// Whether the stars come out at night.
    ///
    /// A switch for the same reason the grass and the soil banks have one:
    /// the star field is several thousand bright points, and a test measuring
    /// darkness must be able to turn the sky's own lights off.
    public var stars: Bool

    /// The hand-drawn constellation figures, joined star to star. Off by
    /// default: the bare sky is the honest one, and the figures are a
    /// reading aid a viewer asks for.
    public var constellationLines: Bool = false

    /// The moment being drawn, as UT. The stars need it twice over: sidereal
    /// time turns the sky, and precession plus proper motion decide *which*
    /// sky — 2500 BC is not tonight with the labels changed.
    public var epoch: JulianDay
    /// Where the observer stands; latitude and longitude orient the sky.
    public var site: GeographicSite

    /// Where the sun is, from `HengeAstro`. Never set by hand — invariant 1.
    public var moon: HorizontalCoordinate
    /// Apparent angular radius of the moon, radians.
    public var moonAngularRadius: Double
    /// 0 new, 1 full.
    public var moonIllumination: Double
    /// The sun's apparent ecliptic longitude — where we are in the year.
    ///
    /// Drives the seasonal palette. Longitude rather than calendar month
    /// because in 2500 BC the June solstice falls in July, and a palette
    /// indexed by month would put high summer in the wrong season.
    public var solarLongitude: Angle
    public var sun: HorizontalCoordinate
    /// Apparent angular *radius* of the sun in radians.
    public var sunAngularRadius: Double
    public var camera: Camera
    /// Preetham turbidity: 2 is a clear day, 6 is hazy.
    public var turbidity: Float
    public var exposure: Float

    public init(sun: HorizontalCoordinate,
                moon: HorizontalCoordinate = HorizontalCoordinate(
                    altitude: Angle(degrees: -30), azimuth: .zero),
                moonAngularRadius: Double = 0.00452,
                moonIllumination: Double = 0,
                solarLongitude: Angle = Angle(degrees: 90),
                sunAngularRadius: Double = 0.00465,
                camera: Camera = Camera(),
                turbidity: Float = 2.4,
                exposure: Float = 1.6,
                surfaceTexturing: Bool = true,
                weathering: Bool = true,
                windSpeed: Float = 0.45,
                grassBlades: Bool = true,
                soilBanks: Bool = true,
                windBearing: Double = 250,
                windTime: Double = 0,
                lightShafts: Bool = true,
                torchlight: Bool = false,
                stars: Bool = true,
                epoch: JulianDay = JulianDay(2_451_545.0),
                site: GeographicSite = .stonehenge,
                weather: Weather = .clear) {
        self.sun = sun
        self.moon = moon
        self.moonAngularRadius = moonAngularRadius
        self.moonIllumination = moonIllumination
        self.solarLongitude = solarLongitude
        self.sunAngularRadius = sunAngularRadius
        self.camera = camera
        self.turbidity = turbidity
        self.exposure = exposure
        self.surfaceTexturing = surfaceTexturing
        self.weathering = weathering
        self.windSpeed = windSpeed
        self.grassBlades = grassBlades
        self.soilBanks = soilBanks
        self.windBearing = windBearing
        self.windTime = windTime
        self.lightShafts = lightShafts
        self.torchlight = torchlight
        self.stars = stars
        self.epoch = epoch
        self.site = site
        self.weather = weather
    }

    /// How hard the torch burns, before the shader's falloff.
    ///
    /// Two factors, both here rather than in MSL so a test can hold them:
    ///
    /// The **night gate** fades the torch out across dusk — full below the
    /// horizon, gone by 6° of sun. Physically a torch burns at noon too; it
    /// just cannot be *seen* against sunlight, and modelling that honestly
    /// would mean adding a light the eye must then fail to notice. Gating is
    /// the legible version of the same truth, and it makes "torch at noon
    /// changes nothing" a testable promise instead of a hope.
    ///
    /// The **flicker** runs on the wall clock, like the wind and for the
    /// same reason: at a day a second a fire that kept astronomical time
    /// would strobe. Three incommensurate sines, bounded well away from
    /// zero — a real flame gutters but does not go out.
    public static func torchIntensity(sunAltitudeDegrees: Double,
                                      flickerAt seconds: Double) -> Double {
        let t = min(max((sunAltitudeDegrees + 1) / 7, 0), 1)
        let night = 1 - t * t * (3 - 2 * t)
        // 90 is measured, not guessed: sarsen's delivered linear albedo is
        // dark (the texture calibration puts its mean near 0.03), and the
        // first cut at 14 lit a stone three metres off by four luminance
        // levels — a nightlight, not a ceremony. This figure puts roughly
        // forty levels on that face and lets the inverse square do the rest.
        return 90.0 * night * torchFlicker(at: seconds)
    }

    /// The flame's unsteadiness, 1 on average, never below 0.8.
    public static func torchFlicker(at seconds: Double) -> Double {
        0.95 + 0.09 * sin(seconds * 7.3) * sin(seconds * 3.1)
             + 0.06 * sin(seconds * 11.7 + 1.4)
    }

    /// Build the state for a moment in time at a site. This is the only path
    /// the app uses, so the sun in the sky and the sun in the almanac are by
    /// construction the same sun.
    public static func at(_ ut: JulianDay,
                          site: GeographicSite = .stonehenge,
                          camera: Camera = Camera()) -> SceneState {
        let tt = ut.terrestrialTime
        let sun = Sun.horizontal(at: ut, site: site)
        let position = Sun.position(at: tt)
        let moonPosition = Moon.position(at: tt)
        let phase = Moon.phase(at: tt)
        return SceneState(sun: sun,
                          moon: Moon.horizontal(at: ut, site: site),
                          moonAngularRadius: moonPosition.angularDiameter.radians / 2,
                          moonIllumination: phase.illuminatedFraction,
                          solarLongitude: position.apparentLongitude,
                          sunAngularRadius: position.angularDiameter.radians / 2,
                          camera: camera,
                          epoch: ut,
                          site: site)
    }

    /// Unit vector toward the moon in world axes.
    public var moonDirection: SIMD3<Float> {
        let v = moon.unitVector
        return SIMD3(Float(v.x), Float(v.y), Float(v.z))
    }

    /// Moonlight radiance. Faint, cool, and scaled by how much of the disc is
    /// lit — a full moon is roughly ten times a quarter moon, not twice, since
    /// the lit crescent is both smaller and more steeply lit.
    ///
    /// Strong enough to *model*: the first calibration put nearly all of a
    /// moonlit night's light into the unshadowed ambient palette and left
    /// this directional term a whisper — the cascades were duly fitted to
    /// the moon and the shadows duly drawn, then washed invisible by their
    /// own ambient. A full moon casts a shadow you can stand in; now the
    /// term carries enough of the night's energy to draw one.
    public var moonRadiance: SIMD3<Float> {
        let altitude = Float(moon.altitude.radians)
        guard altitude > -0.05 else { return .zero }
        let fraction = Float(moonIllumination)
        let brightness = pow(fraction, 2.2) * min(1, max(0, altitude * 4 + 0.2))
        return SIMD3<Float>(0.62, 0.72, 1.0) * brightness * 1.0
    }

    /// Unit vector toward the sun in world axes.
    public var sunDirection: SIMD3<Float> {
        let v = sun.unitVector
        return SIMD3(Float(v.x), Float(v.y), Float(v.z))
    }

    /// Sun radiance, reddening and dimming as it nears the horizon. Crude
    /// against a real transmittance model, but it is what makes the golden
    /// hour read as golden; M5 replaces it when the atmosphere gains depth.
    public var sunRadiance: SIMD3<Float> {
        let altitude = Float(max(sun.altitude.radians, -0.1))
        let airMass = 1.0 / max(sin(max(altitude, 0.01)), 0.05)
        let extinction = exp(-0.12 * airMass)
        let warm = SIMD3<Float>(1.0, 0.72 + 0.28 * min(1, altitude * 4),
                                0.42 + 0.58 * min(1, altitude * 3))
        return warm * extinction * 6.0
    }
}

/// A scene with every mesh built and nothing uploaded — the hand-off
/// between the background preparation and the main-actor buffer upload.
public struct PreparedScene: Sendable {
    struct Item: Sendable {
        let mesh: Mesh
        let albedo: SIMD4<Float>
        let label: String
        let castsShadow: Bool
        let kind: SurfaceTextures.Kind
        let seed: UInt64
    }
    let items: [Item]
    public let state: Monument.State
}

/// A block of geometry the renderer can draw in one call.
struct DrawItem {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var indexCount: Int
    var uniforms: DrawUniforms
    var castsShadow: Bool
    var surfaceKind: SurfaceTextures.Kind = .rock
}

extension Array {
    /// Bounds-checked lookup, for the texture slots — an absent material set
    /// must read as "draw it flat", not as a crash.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public enum RendererError: Error, CustomStringConvertible {
    case noDevice
    case shaderSourceMissing
    case shaderCompilationFailed(String)
    case pipelineCreationFailed(String)
    case resourceCreationFailed(String)

    public var description: String {
        switch self {
        case .noDevice: "No Metal device is available on this machine."
        case .shaderSourceMissing: "Henge.metal was not found in the package bundle."
        case .shaderCompilationFailed(let m): "Shader compilation failed: \(m)"
        case .pipelineCreationFailed(let m): "Pipeline creation failed: \(m)"
        case .resourceCreationFailed(let m): "Resource creation failed: \(m)"
        }
    }
}

/// The Metal 3 renderer.
///
/// Main-actor isolated: `MTKView` drives `draw(in:)` on the main thread, and
/// under Swift 6 strict concurrency that isolation has to be stated rather
/// than assumed. The GPU work itself is asynchronous — the actor guards the
/// CPU-side state, not the command buffer.
@MainActor
public final class HengeRenderer: NSObject, MTKViewDelegate {

    public static let colourFormat: MTLPixelFormat = .bgra8Unorm
    public static let depthFormat: MTLPixelFormat = .depth32Float
    public static let cascadeCount = 3
    public static let framesInFlight = 3

    public let device: MTLDevice
    public var state: SceneState

    private let commandQueue: MTLCommandQueue
    private let scenePipeline: MTLRenderPipelineState
    private let grassPipeline: MTLRenderPipelineState
    /// The one blade every instance shares, and the field of instances.
    private var grassShapeBuffer: MTLBuffer?
    private var grassIndexBuffer: MTLBuffer?
    private var grassInstanceBuffer: MTLBuffer?
    private var grassIndexCount = 0
    private var grassBladeCount = 0
    private let shadowPipeline: MTLRenderPipelineState
    private let skyPipeline: MTLRenderPipelineState
    private let hazePipeline: MTLRenderPipelineState
    private let starPipeline: MTLRenderPipelineState
    /// The Hipparcos naked-eye sky. Nil degrades to a starless night — the
    /// almanac does not die for want of decoration.
    private let starCatalog = StarCatalog.load()
    private var starBuffer: MTLBuffer?
    private var starCount = 0
    /// The epoch the star buffer was built for. Proper motion and precession
    /// move slowly, so the buffer stands until the drawn epoch drifts two
    /// years from it — a deep-time scrub rebuilds a few times per millennium
    /// crossed, never per frame.
    private var starEpoch = Double.infinity
    private let constellationPipeline: MTLRenderPipelineState
    private var constellationBuffer: MTLBuffer?
    private var constellationVertexCount = 0
    /// The figures resolved from HIP identifiers to catalogue indices, once:
    /// the same indices then read from whichever epoch's instances the star
    /// buffer was built from, so the figures precess with their stars for
    /// free.
    private lazy var constellationIndexPairs: [(Int, Int)] = {
        guard let catalog = starCatalog else { return [] }
        var indexByHIP: [Int: Int] = [:]
        indexByHIP.reserveCapacity(catalog.entries.count)
        for (index, entry) in catalog.entries.enumerated() {
            indexByHIP[entry.hip] = index
        }
        return ConstellationFigure.all.flatMap { figure in
            figure.segments.compactMap { segment in
                guard let a = indexByHIP[segment.0],
                      let b = indexByHIP[segment.1] else { return nil }
                return (a, b)
            }
        }
    }()
    private let sceneDepthState: MTLDepthStencilState
    private let shadowDepthState: MTLDepthStencilState
    private let skyDepthState: MTLDepthStencilState
    private let shadowSampler: MTLSamplerState
    /// Repeat-addressed, mipmapped, anisotropic — the opposite of the shadow
    /// sampler in every respect, and for good reason: this one is filtering
    /// colour, where averaging is the whole point.
    private let surfaceSampler: MTLSamplerState
    /// Rock and grass maps. Optional throughout: a missing texture must degrade
    /// to the flat-shaded look the renderer had before, not take the app down.
    /// The almanac is still correct without a photograph of a rock.
    private var surfaces: [SurfaceTextures] = []
    /// The Moon's own face — NASA's LRO colour map (public domain; see
    /// SECURITY.md). Optional like every photograph here: absent, the disc
    /// falls back to the plain lit sphere it was.
    private var moonTexture: MTLTexture?
    private let shadowMap: MTLTexture
    private let shadowResolution: Int

    /// Triple-buffered so the CPU can build frame N+1 while the GPU is still
    /// reading frame N's uniforms. Without this the CPU would have to wait on
    /// every frame, and the time-lapse would stutter exactly when it matters.
    private var frameUniformBuffers: [MTLBuffer] = []
    private var frameIndex = 0
    private let inFlightSemaphore = DispatchSemaphore(value: HengeRenderer.framesInFlight)

    private var drawItems: [DrawItem] = []
    /// The geometry overlay's pieces, kept apart from the monument so a mode
    /// switch can swap them without rebuilding eighty stones.
    private var overlayItems: [DrawItem] = []
    private var aspectRatio: Float = 16.0 / 9.0

    public init(device: MTLDevice? = nil,
                state: SceneState,
                shadowResolution: Int = 2048) throws {
        guard let device = device ?? MTLCreateSystemDefaultDevice() else {
            throw RendererError.noDevice
        }
        guard let queue = device.makeCommandQueue() else {
            throw RendererError.resourceCreationFailed("command queue")
        }
        self.device = device
        self.commandQueue = queue
        self.state = state
        self.shadowResolution = shadowResolution

        let library = try Self.makeLibrary(device: device)

        // Vertex layout, matching MeshVertex and the MSL `Vertex` struct.
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 30
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 30
        vertexDescriptor.layouts[30].stride = MemoryLayout<MeshVertex>.stride

        func pipeline(_ label: String, vertex: String, fragment: String?,
                      colour: MTLPixelFormat?, depth: MTLPixelFormat,
                      useVertexDescriptor: Bool) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = label
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            if let fragment { descriptor.fragmentFunction = library.makeFunction(name: fragment) }
            if useVertexDescriptor { descriptor.vertexDescriptor = vertexDescriptor }
            if let colour { descriptor.colorAttachments[0].pixelFormat = colour }
            descriptor.depthAttachmentPixelFormat = depth
            do {
                return try device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                throw RendererError.pipelineCreationFailed("\(label): \(error)")
            }
        }

        self.scenePipeline = try pipeline("scene", vertex: "scene_vertex",
                                          fragment: "scene_fragment",
                                          colour: Self.colourFormat,
                                          depth: Self.depthFormat,
                                          useVertexDescriptor: true)
        // Blended, because the outermost blades fade into the textured ground
        // rather than ending the field at a visible circle. Depth writes stay
        // on: a blade is opaque everywhere except that outer ring, and turning
        // them off would let near blades draw behind far ones.
        let grassDescriptor = MTLRenderPipelineDescriptor()
        grassDescriptor.label = "grass"
        grassDescriptor.vertexFunction = library.makeFunction(name: "grass_vertex")
        grassDescriptor.fragmentFunction = library.makeFunction(name: "grass_fragment")
        grassDescriptor.colorAttachments[0].pixelFormat = Self.colourFormat
        grassDescriptor.colorAttachments[0].isBlendingEnabled = true
        grassDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        grassDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        grassDescriptor.depthAttachmentPixelFormat = Self.depthFormat
        do {
            self.grassPipeline = try device.makeRenderPipelineState(descriptor: grassDescriptor)
        } catch {
            throw RendererError.pipelineCreationFailed("grass: \(error)")
        }

        self.shadowPipeline = try pipeline("shadow", vertex: "shadow_vertex",
                                           fragment: nil, colour: nil,
                                           depth: Self.depthFormat,
                                           useVertexDescriptor: true)
        self.skyPipeline = try pipeline("sky", vertex: "sky_vertex",
                                        fragment: "sky_fragment",
                                        colour: Self.colourFormat,
                                        depth: Self.depthFormat,
                                        useVertexDescriptor: false)

        // The light-shaft pass draws over the finished frame with no depth
        // attachment of its own — it *samples* the scene's depth instead. The
        // blend is `inscatter + transmittance × frame`: source factor one,
        // destination factor source-alpha, with alpha carrying transmittance.
        let hazeDescriptor = MTLRenderPipelineDescriptor()
        hazeDescriptor.label = "light shafts"
        hazeDescriptor.vertexFunction = library.makeFunction(name: "sky_vertex")
        hazeDescriptor.fragmentFunction = library.makeFunction(name: "haze_fragment")
        hazeDescriptor.colorAttachments[0].pixelFormat = Self.colourFormat
        hazeDescriptor.colorAttachments[0].isBlendingEnabled = true
        hazeDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        hazeDescriptor.colorAttachments[0].destinationRGBBlendFactor = .sourceAlpha
        hazeDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .zero
        hazeDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        hazeDescriptor.depthAttachmentPixelFormat = .invalid
        do {
            self.hazePipeline = try device.makeRenderPipelineState(descriptor: hazeDescriptor)
        } catch {
            throw RendererError.pipelineCreationFailed("light shafts: \(error)")
        }

        // Stars: point sprites blended additively over the finished sky.
        let starDescriptor = MTLRenderPipelineDescriptor()
        starDescriptor.label = "stars"
        starDescriptor.vertexFunction = library.makeFunction(name: "star_vertex")
        starDescriptor.fragmentFunction = library.makeFunction(name: "star_fragment")
        starDescriptor.colorAttachments[0].pixelFormat = Self.colourFormat
        starDescriptor.colorAttachments[0].isBlendingEnabled = true
        starDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        starDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        starDescriptor.depthAttachmentPixelFormat = Self.depthFormat
        do {
            self.starPipeline = try device.makeRenderPipelineState(descriptor: starDescriptor)
        } catch {
            throw RendererError.pipelineCreationFailed("stars: \(error)")
        }

        // The constellation figures: line segments between catalogue stars,
        // blended the same additive way — they are more of the same light.
        let constellationDescriptor = MTLRenderPipelineDescriptor()
        constellationDescriptor.label = "constellations"
        constellationDescriptor.vertexFunction =
            library.makeFunction(name: "constellation_vertex")
        constellationDescriptor.fragmentFunction =
            library.makeFunction(name: "constellation_fragment")
        constellationDescriptor.colorAttachments[0].pixelFormat = Self.colourFormat
        constellationDescriptor.colorAttachments[0].isBlendingEnabled = true
        constellationDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        constellationDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        constellationDescriptor.depthAttachmentPixelFormat = Self.depthFormat
        do {
            self.constellationPipeline = try device.makeRenderPipelineState(
                descriptor: constellationDescriptor)
        } catch {
            throw RendererError.pipelineCreationFailed("constellations: \(error)")
        }

        // The camera renders reverse-Z, so nearer means *greater*.
        let sceneDepth = MTLDepthStencilDescriptor()
        sceneDepth.depthCompareFunction = .greater
        sceneDepth.isDepthWriteEnabled = true
        guard let sceneDepthState = device.makeDepthStencilState(descriptor: sceneDepth) else {
            throw RendererError.resourceCreationFailed("depth state")
        }
        self.sceneDepthState = sceneDepthState

        // The shadow cascades are orthographic, where precision is uniform and
        // there is nothing to gain by reversing. Kept conventional so the
        // comparison in the shader stays the obvious way round.
        let shadowDepth = MTLDepthStencilDescriptor()
        shadowDepth.depthCompareFunction = .less
        shadowDepth.isDepthWriteEnabled = true
        guard let shadowDepthState = device.makeDepthStencilState(descriptor: shadowDepth) else {
            throw RendererError.resourceCreationFailed("shadow depth state")
        }
        self.shadowDepthState = shadowDepthState

        // The sky fills whatever the stones did not, and writes no depth.
        let skyDepth = MTLDepthStencilDescriptor()
        skyDepth.depthCompareFunction = .greaterEqual
        skyDepth.isDepthWriteEnabled = false
        guard let skyDepthState = device.makeDepthStencilState(descriptor: skyDepth) else {
            throw RendererError.resourceCreationFailed("sky depth state")
        }
        self.skyDepthState = skyDepthState

        // Nearest, not linear. A linear sampler on a depth texture averages
        // *depths* across the shadow edge and only then compares, which drags
        // the boundary toward the caster — a third of a metre on a ten-metre
        // shadow here, and immune to bias tuning because it is a filtering
        // artefact rather than a depth one. The 3×3 comparison in the shader
        // does the percentage-closer filtering instead, which is what PCF
        // actually means.
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw RendererError.resourceCreationFailed("sampler")
        }
        self.shadowSampler = sampler

        let surfaceDescriptor = MTLSamplerDescriptor()
        surfaceDescriptor.minFilter = .linear
        surfaceDescriptor.magFilter = .linear
        surfaceDescriptor.mipFilter = .linear
        surfaceDescriptor.sAddressMode = .repeat
        surfaceDescriptor.tAddressMode = .repeat
        // Grazing views along the ground plane are the common case here — the
        // whole app is about standing at eye height and looking at a horizon —
        // and that is precisely where isotropic filtering turns turf to mush.
        surfaceDescriptor.maxAnisotropy = 8
        guard let colourSampler = device.makeSamplerState(descriptor: surfaceDescriptor) else {
            throw RendererError.resourceCreationFailed("surface sampler")
        }
        self.surfaceSampler = colourSampler
        self.surfaces = SurfaceTextures.Kind.allCases.compactMap {
            SurfaceTextures.load($0, device: device)
        }
        self.moonTexture = {
            guard let url = Bundle.module.url(forResource: "moon-albedo",
                                              withExtension: "jpg") else { return nil }
            return try? MTKTextureLoader(device: device).newTexture(URL: url, options: [
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                .generateMipmaps: NSNumber(value: true),
                .SRGB: NSNumber(value: true)
            ])
        }()

        let shadowDescriptor = MTLTextureDescriptor()
        shadowDescriptor.textureType = .type2DArray
        shadowDescriptor.pixelFormat = Self.depthFormat
        shadowDescriptor.width = shadowResolution
        shadowDescriptor.height = shadowResolution
        shadowDescriptor.arrayLength = Self.cascadeCount
        shadowDescriptor.usage = [.renderTarget, .shaderRead]
        shadowDescriptor.storageMode = .private
        guard let shadowMap = device.makeTexture(descriptor: shadowDescriptor) else {
            throw RendererError.resourceCreationFailed("shadow map")
        }
        shadowMap.label = "shadow cascades"
        self.shadowMap = shadowMap

        super.init()

        for i in 0..<Self.framesInFlight {
            guard let buffer = device.makeBuffer(length: MemoryLayout<FrameUniforms>.stride,
                                                 options: .storageModeShared) else {
                throw RendererError.resourceCreationFailed("frame uniforms \(i)")
            }
            buffer.label = "frame uniforms \(i)"
            frameUniformBuffers.append(buffer)
        }
    }

    /// Compile the shaders from the package resource.
    ///
    /// SwiftPM does not build a `default.metallib` for a library target, so
    /// rather than depending on the app bundle — which would leave the engine
    /// untestable from `swift test` — the source travels as a resource and is
    /// compiled at start. Costs a fraction of a second once; buys a renderer
    /// the oracle can actually drive. FACTORY.md records the trade.
    static func makeLibrary(device: MTLDevice) throws -> MTLLibrary {
        guard let url = Bundle.module.url(forResource: "Henge", withExtension: "metal",
                                          subdirectory: "Shaders")
                ?? Bundle.module.url(forResource: "Henge", withExtension: "metal") else {
            throw RendererError.shaderSourceMissing
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        // Default math, not fast math. The shadow pass is measured against an
        // analytic solution to a stated tolerance (MISSION.md invariant 2), and
        // relaxed floating point would spend part of that budget for a saving
        // this renderer does not currently need.
        let options = MTLCompileOptions()
        do {
            return try device.makeLibrary(source: source, options: options)
        } catch {
            throw RendererError.shaderCompilationFailed("\(error)")
        }
    }

    // ── scene ───────────────────────────────────────────────────────────────

    /// Upload a monument. Called once per change of state, not per frame.
    /// - Parameter roughness: displacement amplitude. Zero yields exact boxes,
    ///   which is what the shadow-agreement test needs so that the rendered
    ///   silhouette and the analytic outline describe the same solid.
    /// The plain the monument stands on. Nil renders a flat world, which is
    /// what the shadow-agreement test wants — a sloping receiver would move the
    /// measured shadow for reasons that have nothing to do with the renderer.
    public var terrain: TerrainModel?

    public func load(scene: MonumentScene, subdivisions: Int = 18,
                     roughness: Double = 0.06, rounding: Double = 0.13) throws {
        let prepared = Self.prepare(scene: scene, terrain: terrain,
                                    soilBanks: state.soilBanks,
                                    subdivisions: subdivisions,
                                    roughness: roughness, rounding: rounding)
        try load(prepared: prepared)
    }

    /// The CPU half of a scene load: every mesh built and seated, nothing
    /// uploaded. Pure geometry, callable off the main actor — which is what
    /// lets the ruin/whole switch show a real progress bar instead of a
    /// silent freeze: eighty stones of displaced mesh are most of a second,
    /// and they used to be built mid-frame on the main thread.
    ///
    /// `progress` is called after each stone and once for the ground,
    /// climbing monotonically to 1.
    nonisolated public static func prepare(scene: MonumentScene,
                                           terrain: TerrainModel?,
                                           soilBanks: Bool,
                                           subdivisions: Int = 18,
                                           roughness: Double = 0.06,
                                           rounding: Double = 0.13,
                                           progress: @Sendable (Double) -> Void = { _ in })
        -> PreparedScene {
        var items: [PreparedScene.Item] = []
        let total = Double(scene.stones.count + 1)

        for (index, stone) in scene.stones.enumerated() {
            // Chalk discs are flat and small; they do not need the tessellation
            // a seven-metre sarsen does.
            let detail = stone.material == .chalk ? 5 : subdivisions
            var mesh = StoneMeshBuilder.build(stone, subdivisions: detail,
                                              roughness: roughness, rounding: rounding)
            mesh = Self.seat(mesh, of: stone, on: terrain)
            // The soil banked against its foot, as its own small mesh so it
            // can take the ground material rather than the stone's.
            if soilBanks {
                let skirt = SoilSkirt.build(around: stone, groundHeight: { x, z in
                    Float(terrain?.groundHeight(east: Double(x), south: Double(z)) ?? 0)
                })
                if !skirt.indices.isEmpty {
                    items.append(PreparedScene.Item(
                        mesh: skirt, albedo: SurfaceMaterial.soil,
                        label: "\(stone.id) soil", castsShadow: false,
                        kind: .grass, seed: stone.seed))
                }
            }
            items.append(PreparedScene.Item(
                mesh: mesh, albedo: SurfaceMaterial.albedo(for: stone.material),
                label: stone.id,
                // A disc flush in the turf casting a shadow would be a hole,
                // not a stone.
                castsShadow: stone.material != .chalk,
                kind: .rock, seed: stone.seed))
            progress(Double(index + 1) / total)
        }

        // Salisbury Plain itself, displaced by the surveyed heightfield.
        //
        // Reaching as far as the data does, so there is no edge of the world a
        // few hundred metres out. Resolution is spent where it is seen: the
        // grid is denser near the monument and coarsens outward, because the
        // ridge four kilometres away needs far fewer triangles per metre than
        // the turf underfoot.
        items.append(PreparedScene.Item(
            mesh: Self.groundMesh(terrain: terrain, divisions: 220),
            albedo: SurfaceMaterial.turf, label: "ground",
            castsShadow: false, kind: .grass, seed: 0))

        // The enclosure ditch and bank, as their own fine ring painted over
        // the base grid — several-metre terrain vertices cannot hold a
        // six-metre ditch, so the ring samples the real terrain far more
        // finely and simply floats a constant few centimetres proud of it
        // (`Earthwork.lift`), which needs no carved hole to seam against.
        // State-aware: fresh chalk as dug, silted swell today.
        items.append(PreparedScene.Item(
            mesh: Earthwork.build(state: scene.state, groundHeight: { east, south in
                terrain?.groundHeight(east: east, south: south) ?? 0
            }),
            albedo: SurfaceMaterial.turf, label: "earthwork",
            castsShadow: false, kind: .grass, seed: 0))
        progress(1)
        return PreparedScene(items: items, state: scene.state)
    }

    /// The GPU half: buffers made and the scene swapped in. Fast — the
    /// meshes already exist — so the frame the bar disappears on is the
    /// frame the new monument stands.
    public func load(prepared: PreparedScene) throws {
        var items: [DrawItem] = []
        for piece in prepared.items {
            if let item = try makeDrawItem(mesh: piece.mesh, albedo: piece.albedo,
                                           label: piece.label,
                                           castsShadow: piece.castsShadow,
                                           kind: piece.kind, seed: piece.seed) {
                items.append(item)
            }
        }
        drawItems = items
        loadGrass()
    }

    /// Load (or clear, with an empty array) the geometry overlay.
    ///
    /// Overlay pieces render unlit — `reflectance.w` is the flag the shader
    /// reads — and cast no shadows: a diagram must not move a penumbra the
    /// agreement suite is measuring, and gold lines throwing gold shade
    /// would claim a physicality the overlay exactly does not have.
    public func loadOverlay(_ pieces: [GeometryOverlay.Piece]) {
        overlayItems = pieces.compactMap { piece in
            guard var item = try? makeDrawItem(mesh: piece.mesh,
                                               albedo: piece.colour,
                                               label: piece.name,
                                               castsShadow: false) else { return nil }
            item.uniforms.reflectance.w = 1
            return item
        }
    }

    /// Build the blade mesh and scatter the field.
    ///
    /// Silent on failure for the same reason the textures are: a machine that
    /// cannot allocate the instance buffer should still show a correct almanac
    /// over an untufted plain, not refuse to start.
    private func loadGrass() {
        guard state.grassBlades else {
            grassBladeCount = 0
            return
        }
        let shape = GrassField.bladeMesh()
        let blades = GrassField.scatter(terrain: terrain)
        guard !blades.isEmpty,
              let shapeBuffer = device.makeBuffer(
                bytes: shape.vertices,
                length: MemoryLayout<GrassVertex>.stride * shape.vertices.count,
                options: .storageModeShared),
              let indexBuffer = device.makeBuffer(
                bytes: shape.indices,
                length: MemoryLayout<UInt16>.stride * shape.indices.count,
                options: .storageModeShared),
              let instanceBuffer = device.makeBuffer(
                bytes: blades,
                length: MemoryLayout<GrassBlade>.stride * blades.count,
                options: .storageModeShared) else {
            grassBladeCount = 0
            return
        }
        shapeBuffer.label = "grass blade"
        instanceBuffer.label = "grass field"
        grassShapeBuffer = shapeBuffer
        grassIndexBuffer = indexBuffer
        grassInstanceBuffer = instanceBuffer
        grassIndexCount = shape.indices.count
        grassBladeCount = blades.count
    }

    private func makeDrawItem(mesh: Mesh, albedo: SIMD4<Float>, label: String,
                              castsShadow: Bool = true,
                              kind: SurfaceTextures.Kind = .rock,
                              seed: UInt64 = 0) throws -> DrawItem? {
        guard !mesh.positions.isEmpty, !mesh.indices.isEmpty else { return nil }

        var vertices: [MeshVertex] = []
        vertices.reserveCapacity(mesh.positions.count)
        for i in mesh.positions.indices {
            vertices.append(MeshVertex(position: mesh.positions[i],
                                       normal: mesh.normals[i],
                                       blend: mesh.blends.isEmpty ? 1 : mesh.blends[i]))
        }

        guard let vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<MeshVertex>.stride * vertices.count,
                options: .storageModeShared),
              let indexBuffer = device.makeBuffer(
                bytes: mesh.indices,
                length: MemoryLayout<UInt32>.stride * mesh.indices.count,
                options: .storageModeShared) else {
            throw RendererError.resourceCreationFailed("buffers for \(label)")
        }
        vertexBuffer.label = "\(label) vertices"
        indexBuffer.label = "\(label) indices"

        // Meshes are already in world space, so the model matrix is identity.
        return DrawItem(vertexBuffer: vertexBuffer, indexBuffer: indexBuffer,
                        indexCount: mesh.indices.count,
                        uniforms: DrawUniforms(
                            albedo: albedo,
                            surface: SIMD4(kind == .grass ? 1 : 0,
                                           kind.metresPerTile,
                                           kind.normalStrength, 1),
                            // The foot is measured off the mesh rather than
                            // taken from the stone's nominal position: the
                            // meshes are already in world space and sit on
                            // displaced terrain, so a stone on a slope has a
                            // foot that is not where its centre says it is.
                            weather: SIMD4(mesh.positions.map(\.y).min() ?? 0,
                                           kind == .grass ? 0 : 1,
                                           0.55,
                                           Float(seed % 997)),
                            reflectance: kind == .grass
                                ? SurfaceMaterial.turfReflectance
                                : SurfaceMaterial.stoneReflectance),
                        castsShadow: castsShadow,
                        surfaceKind: kind)
    }

    /// Put a stone on the ground it is actually standing on.
    ///
    /// `MonumentScene` places stones on a flat datum: their `position.y` is a
    /// height above local ground, because the archaeology records where stones
    /// are on the plan and how tall they are, not what the contour does under
    /// each one. The ground mesh, meanwhile, is displaced by the real
    /// heightfield. On Salisbury Plain that is a metre or so of relief across
    /// the monument — so the near stones looked fine and the outer ones
    /// floated, the Heel Stone at 77 m and the Station Stones at 43 m being
    /// furthest from the datum point.
    ///
    /// The fix is to lift each stone by the ground height under its own root,
    /// then sink it a little. The sink is not a fudge for cracks: megaliths are
    /// set in sockets, and a stone resting exactly on the surface reads as
    /// dropped there this morning.
    nonisolated static func seat(_ mesh: Mesh, of stone: Stone, on terrain: TerrainModel?) -> Mesh {
        guard let terrain else { return mesh }
        let lift = Float(terrain.groundHeight(east: Double(stone.position.x),
                                              south: Double(stone.position.z)))
        // Chalk discs are flush features, not standing stones; sinking one
        // would put it under the turf and out of sight.
        let sink: Float = stone.material == .chalk ? 0 : 0.12
        var seated = mesh
        for i in seated.positions.indices {
            seated.positions[i].y += lift - sink
        }
        return seated
    }

    /// Ground mesh, optionally displaced by the terrain.
    ///
    /// Vertices are placed on a grid warped by a cubic, so spacing is fine near
    /// the monument and stretches toward the horizon. A uniform grid over 30 km
    /// would either be too coarse underfoot or ruinously dense at the edges.
    nonisolated static func groundMesh(terrain: TerrainModel?, divisions: Int) -> Mesh {
        var mesh = Mesh()
        let extent = Float(terrain?.extent ?? 15_000)

        func coordinate(_ i: Int) -> Float {
            let t = Float(i) / Float(divisions) * 2 - 1     // −1…1
            return t * abs(t) * abs(t) * extent             // cubic: dense in the middle
        }

        for i in 0...divisions {
            for j in 0...divisions {
                let x = coordinate(i), z = coordinate(j)
                let y = terrain.map { Float($0.groundHeight(east: Double(x), south: Double(z))) } ?? 0
                mesh.positions.append(SIMD3(x, y, z))
                mesh.normals.append(SIMD3(0, 1, 0))
            }
        }
        for i in 0..<divisions {
            for j in 0..<divisions {
                let a = UInt32(i * (divisions + 1) + j)
                let b = UInt32((i + 1) * (divisions + 1) + j)
                let c = UInt32((i + 1) * (divisions + 1) + j + 1)
                let d = UInt32(i * (divisions + 1) + j + 1)
                // Counter-clockwise seen from above, matching the stones. The
                // obvious ordering winds the other way and produces a ground
                // plane that faces the earth's core: invisible from above the
                // moment the front-facing convention is stated correctly.
                mesh.indices.append(contentsOf: [a, c, b, a, d, c])
            }
        }

        // Real normals from the displaced surface, or the lighting on the plain
        // is uniformly flat and the landform disappears.
        if terrain != nil {
            var accumulated = [SIMD3<Float>](repeating: .zero, count: mesh.positions.count)
            for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
                let i0 = Int(mesh.indices[triangle])
                let i1 = Int(mesh.indices[triangle + 1])
                let i2 = Int(mesh.indices[triangle + 2])
                let normal = cross(mesh.positions[i1] - mesh.positions[i0],
                                   mesh.positions[i2] - mesh.positions[i0])
                accumulated[i0] += normal
                accumulated[i1] += normal
                accumulated[i2] += normal
            }
            for i in accumulated.indices {
                let length = simd_length(accumulated[i])
                mesh.normals[i] = length > 1e-9 ? accumulated[i] / length : SIMD3(0, 1, 0)
            }
        }
        return mesh
    }

    // ── cascades ────────────────────────────────────────────────────────────

    /// Fit an orthographic light frustum to a slice of the view frustum.
    ///
    /// The bounding *sphere* rather than the box is deliberate: a sphere does
    /// not change size as the camera turns, so the cascade keeps a constant
    /// world-to-texel ratio. Combined with snapping the centre to the texel
    /// grid, that is what stops the shadow edges crawling during a time-lapse —
    /// which would be fatal here, because the crawling would look exactly like
    /// the sun moving.
    /// How far back along the light the shadow camera sits, in cascade radii,
    /// and how deep its box runs. Shared with the shader through
    /// `cascadeRadii.w`, because PCSS turns depth differences back into metres
    /// and would silently mis-scale every penumbra if the two drifted apart.
    static let shadowPullback: Float = 6
    static let shadowDepthSpan: Float = 13

    static func cascadeMatrix(camera: Camera, aspect: Float,
                              near: Float, far: Float,
                              lightDirection: SIMD3<Float>,
                              resolution: Int) -> (matrix: float4x4, radius: Float) {
        let forward = normalize(camera.target - camera.position)
        let right = normalize(cross(forward, SIMD3<Float>(0, 1, 0)))
        let up = cross(right, forward)

        let tanHalf = tan(camera.fieldOfView * 0.5)
        var corners: [SIMD3<Float>] = []
        for depth in [near, far] {
            let halfHeight = depth * tanHalf
            let halfWidth = halfHeight * aspect
            let centre = camera.position + forward * depth
            for sx in [-1, 1] as [Float] {
                for sy in [-1, 1] as [Float] {
                    corners.append(centre + right * (halfWidth * sx) + up * (halfHeight * sy))
                }
            }
        }

        var centre = SIMD3<Float>.zero
        for c in corners { centre += c }
        centre /= Float(corners.count)

        var radius: Float = 0
        for c in corners { radius = max(radius, length(c - centre)) }
        radius = ceil(radius * 16) / 16   // quantise so it does not jitter

        // Snap the centre to whole shadow texels.
        let texelsPerWorldUnit = Float(resolution) / (radius * 2)
        let lightView = MetalMath.lookAt(eye: centre + lightDirection * (radius * 2),
                                         target: centre,
                                         up: abs(lightDirection.y) > 0.99
                                             ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0, 1, 0))
        var centreLightSpace = lightView * SIMD4<Float>(centre, 1)
        centreLightSpace.x = floor(centreLightSpace.x * texelsPerWorldUnit) / texelsPerWorldUnit
        centreLightSpace.y = floor(centreLightSpace.y * texelsPerWorldUnit) / texelsPerWorldUnit
        let snappedCentre = (lightView.inverse * centreLightSpace).xyz

        // Pull the light's eye a long way back along its own direction.
        //
        // A cascade box fitted to the view frustum contains only what the
        // camera can see — but a *caster* need not be visible to throw a shadow
        // into frame, and at a grazing sun it usually is not. Standing at the
        // Altar Stone at sunrise, the thing shadowing you is behind you. With
        // the eye at 2× the radius, a stone thirty metres upwind fell outside
        // the box, never reached the depth pass, and cast nothing: a
        // differential test showed a receiving stone darkening by 0.0%.
        //
        // Six radii of pullback and thirteen of depth span cover the casters
        // that matter without the box growing so deep that a 32-bit float
        // starts to lose the near geometry.
        let eye = snappedCentre + lightDirection * (radius * Self.shadowPullback)
        let view = MetalMath.lookAt(eye: eye, target: snappedCentre,
                                    up: abs(lightDirection.y) > 0.99
                                        ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0, 1, 0))
        let projection = MetalMath.orthographic(left: -radius, right: radius,
                                                bottom: -radius, top: radius,
                                                near: 0.1, far: radius * Self.shadowDepthSpan)
        return (projection * view, radius)
    }

    func buildFrameUniforms(aspect: Float) -> FrameUniforms {
        let view = state.camera.view()
        let projection = state.camera.projection(aspect: aspect)
        let viewProjection = projection * view
        let sunDirection = state.sunDirection

        let splits = SIMD4<Float>(24, 90, 320, 0)
        var matrices = (matrix_identity_float4x4, matrix_identity_float4x4, matrix_identity_float4x4)
        var radii = SIMD4<Float>(splits.x, splits.y, splits.z, Self.shadowDepthSpan)

        // Which light is casting.
        //
        // One shadow map, and at night the sun is not using it. A full moon
        // gives about a quarter of a lux — enough to throw a shadow with an
        // edge you can see, and standing among the stones under one is a large
        // part of why people come. So when the sun is down and the moon is up
        // and bright enough to matter, the cascades are fitted to the moon
        // instead and the fragment shader applies them to the moonlight term.
        //
        // The threshold is on *illuminated fraction*, not altitude alone: a
        // crescent casts nothing a person would call a shadow, and fitting
        // cascades to it would spend the frame's shadow budget on nothing.
        let moonDirection = state.moonDirection
        let moonCasts = sunDirection.y <= 0.0002
            && moonDirection.y > 0.05
            && state.moonIllumination > 0.45
        let shadowDirection = moonCasts ? moonDirection : sunDirection

        // Fit cascades whenever the sun is above the horizon at all.
        //
        // This threshold used to be 0.01, which is an altitude of 0.573° — so
        // the monument cast no shadow whatever between the sun's appearing and
        // its clearing half a degree of sky. That is the definition-of-done
        // moment and its mirror at midwinter sunset: the two instants the whole
        // app is built around, and the two it drew flat. The comment said the
        // fit "produces garbage" below the horizon, which is true, but 0.573°
        // is not below the horizon.
        //
        // The epsilon that remains is a thousandth of that — 0.011° — and
        // exists only so the orthographic box cannot collapse to zero depth
        // exactly at grazing incidence. `state.sun` is already refracted, so
        // this is measured against the *apparent* horizon, which is the one you
        // see the sun rise over.
        if shadowDirection.y > 0.0002 {
            let m0 = Self.cascadeMatrix(camera: state.camera, aspect: aspect,
                                        near: state.camera.near, far: splits.x,
                                        lightDirection: shadowDirection,
                                        resolution: shadowResolution)
            let m1 = Self.cascadeMatrix(camera: state.camera, aspect: aspect,
                                        near: splits.x, far: splits.y,
                                        lightDirection: shadowDirection,
                                        resolution: shadowResolution)
            let m2 = Self.cascadeMatrix(camera: state.camera, aspect: aspect,
                                        near: splits.y, far: splits.z,
                                        lightDirection: shadowDirection,
                                        resolution: shadowResolution)
            matrices = (m0.matrix, m1.matrix, m2.matrix)
            radii = SIMD4(m0.radius, m1.radius, m2.radius, Self.shadowDepthSpan)
        }

        // The weather takes its cut of the sun before anything downstream
        // sees it: direct light, shadow contrast, the drawn disc and the
        // golden-hour beams all dim by the same factor, because they all
        // read this one value.
        let radiance = state.sunRadiance * Float(state.weather.sunTransmission)
        let frost = Weather.frostAmount(condition: state.weather,
                                        sunAltitudeDegrees: state.sun.altitude.degrees)
        return FrameUniforms(
            viewProjection: viewProjection,
            view: view,
            projection: projection,
            cameraPosition: SIMD4(state.camera.position, 1),
            sunDirection: SIMD4(sunDirection, 0),
            sunRadiance: SIMD4(radiance, Float(state.sunAngularRadius)),
            shadowMatrices: matrices,
            inverseViewProjection: viewProjection.inverse,
            cascadeSplits: splits,
            skyParameters: SIMD4(state.turbidity, state.exposure, 0,
                                 1.0 / Float(shadowResolution)),
            // The drawn moon is twice its true angular size — a legibility
            // choice the owner made with eyes on the sky, like the night
            // floor: the honest half-degree read as a distant dot, and the
            // moon illusion means everyone's memory disagrees with the
            // protractor. The *almanac's* numbers stay true; only the disc
            // is enlarged, and the sun — the ruler the definition of done is
            // measured with — keeps its exact size.
            moonDirection: SIMD4(state.moonDirection, Float(state.moonAngularRadius * 2)),
            // The deck takes the same cut of moonlight it takes of sunlight
            // — the review's sharpest finding was a rain that ceased to
            // exist at sunset, full moon and stars blazing through solid
            // cover.
            moonLight: SIMD4(state.moonRadiance * Float(state.weather.sunTransmission),
                             Float(state.moonIllumination)),
            cascadeRadii: radii,
            wind: {
                // Bearing is where the wind comes *from*; the shader wants the
                // direction it travels, so this is the reciprocal. Getting it
                // backwards would send every gust upwind, which is the sort of
                // thing that looks subtly wrong and is hard to name.
                let towards = (state.windBearing + 180) * .pi / 180
                return SIMD4(Float(sin(towards)), state.windSpeed,
                             Float(-cos(towards)), Float(state.windTime))
            }(),
            grass: SIMD4(GrassField.radius, GrassField.fade, 0, 0),
            night: NightPalette.colour(illuminatedFraction: state.moonIllumination,
                                       moonAltitude: state.moon.altitude),
            season: {
                let palette = SeasonPalette.colour(atSolarLongitude: state.solarLongitude)
                return SIMD4(palette.tint, palette.dryness)
            }(),
            shadowSource: SIMD4(moonCasts ? 1 : 0, 0, 0, 0),
            haze: {
                // The boost is hard zero at 0.2° altitude — above both the
                // cascade-fit threshold and the moon-cast handover at ~0.011°
                // (HazeTests pins the ordering) — so the beams can never
                // march against identity matrices or the moon's shadow map.
                // The gate here is belt and braces on top of that arithmetic,
                // and unlike the curve it cannot cause a visible pop, because
                // when it fires the curve has already been zero for a fifth
                // of a degree.
                // Cloud cover closes the beams: a crepuscular shaft is
                // direct sunlight made visible, and a deck that hides the
                // disc admits none. Scaled rather than gated so a broken
                // sky keeps a fraction of its rays.
                let boost = moonCasts || !state.lightShafts
                    ? 0 : Haze.twilightBoost(sunAltitude: state.sun.altitude)
                        * (1 - state.weather.cloudCover)
                // 0.0085 m⁻¹ at full boost: an optical depth of about 0.4
                // over the ninety-metre march — mist you notice the sun in,
                // not fog you lose the stones behind.
                return SIMD4(Float(boost) * 0.0085, 90, 12, 0)
            }(),
            torch: {
                guard state.torchlight else { return .zero }
                // At the hand: half a pace ahead of the eye and a little
                // below it, so the light models the stones from where a
                // carried flame actually rides.
                let forward = simd_normalize(state.camera.target - state.camera.position)
                let position = state.camera.position + forward * 0.45
                    + SIMD3<Float>(0, -0.2, 0)
                let intensity = SceneState.torchIntensity(
                    sunAltitudeDegrees: state.sun.altitude.degrees,
                    flickerAt: state.windTime)
                return SIMD4(position, Float(intensity))
            }(),
            weatherState: SIMD4(Float(state.weather.cloudCover),
                                Float(state.weather.wetness),
                                Float(frost),
                                // w doubles as "the moon's photograph is
                                // bound": an unbound texture samples as
                                // zero, which would render the disc black
                                // rather than plain.
                                moonTexture == nil ? 0 : 1)
        )
    }

    // ── drawing ─────────────────────────────────────────────────────────────

    private func encodeShadowPass(_ commandBuffer: MTLCommandBuffer,
                                  uniforms: FrameUniforms) {
        let matrices = [uniforms.shadowMatrices.0, uniforms.shadowMatrices.1,
                        uniforms.shadowMatrices.2]
        for cascade in 0..<Self.cascadeCount {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.depthAttachment.texture = shadowMap
            descriptor.depthAttachment.slice = cascade
            descriptor.depthAttachment.loadAction = .clear
            descriptor.depthAttachment.storeAction = .store
            descriptor.depthAttachment.clearDepth = 1.0

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            else { continue }
            encoder.label = "shadow cascade \(cascade)"
            encoder.setRenderPipelineState(shadowPipeline)
            encoder.setDepthStencilState(shadowDepthState)
            encoder.setFrontFacing(.counterClockwise)
            encoder.setCullMode(.back)

            var matrix = matrices[cascade]
            encoder.setVertexBytes(&matrix, length: MemoryLayout<float4x4>.stride, index: 2)

            for item in drawItems where item.castsShadow {
                var draw = item.uniforms
                encoder.setVertexBuffer(item.vertexBuffer, offset: 0, index: 30)
                encoder.setVertexBytes(&draw, length: MemoryLayout<DrawUniforms>.stride, index: 1)
                encoder.drawIndexedPrimitives(type: .triangle,
                                              indexCount: item.indexCount,
                                              indexType: .uint32,
                                              indexBuffer: item.indexBuffer,
                                              indexBufferOffset: 0)
            }
            encoder.endEncoding()
        }
    }

    /// Rebuild the star buffer when the drawn epoch has drifted far enough
    /// for precession and proper motion to matter.
    private func refreshStarsIfNeeded() {
        guard state.stars, let catalog = starCatalog else {
            starCount = 0
            // Forget the epoch too, or re-enabling within two simulated
            // years finds the drift guard satisfied and the count still
            // zero — a permanently starless night the review caught.
            starEpoch = .infinity
            return
        }
        guard abs(state.epoch.value - starEpoch) > 730 else { return }
        let instances = catalog.instances(at: state.epoch.terrestrialTime)
        let vertices = instances.map { star in
            StarVertex(direction: SIMD4(SIMD3<Float>(star.direction),
                                        Float(star.magnitude)),
                       colour: SIMD4(star.colour, 0))
        }
        starBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<StarVertex>.stride * vertices.count,
            options: .storageModeShared)
        starBuffer?.label = "stars"
        starCount = starBuffer == nil ? 0 : vertices.count
        starEpoch = state.epoch.value

        // The figures ride the same instances, so a deep-time scrub that
        // precesses the stars carries their lines along by construction.
        let lineVertices = constellationIndexPairs.flatMap { pair in
            [pair.0, pair.1].map { index in
                StarVertex(direction: SIMD4(SIMD3<Float>(instances[index].direction), 0),
                           colour: SIMD4<Float>(0, 0, 0, 0))
            }
        }
        if lineVertices.isEmpty {
            constellationBuffer = nil
            constellationVertexCount = 0
        } else {
            constellationBuffer = device.makeBuffer(
                bytes: lineVertices,
                length: MemoryLayout<StarVertex>.stride * lineVertices.count,
                options: .storageModeShared)
            constellationBuffer?.label = "constellations"
            constellationVertexCount = constellationBuffer == nil
                ? 0 : lineVertices.count
        }
    }

    private func encodeScenePass(_ encoder: MTLRenderCommandEncoder,
                                 uniformBuffer: MTLBuffer) {
        // Sky first, filling the frame; the stones then draw over it.
        encoder.setRenderPipelineState(skyPipeline)
        encoder.setDepthStencilState(skyDepthState)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        if let moon = moonTexture {
            encoder.setFragmentTexture(moon, index: 1)
            encoder.setFragmentSamplerState(surfaceSampler, index: 1)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        // The stars, over the sky and under the stones. Skipped whenever the
        // brightest star could not survive the twilight — the vertex shader
        // would cull every point anyway, and the encoder is cheaper unissued.
        if state.stars, starCount > 0, let stars = starBuffer,
           state.sun.altitude.degrees < -1.5 {
            encoder.setRenderPipelineState(starPipeline)
            encoder.setDepthStencilState(skyDepthState)
            encoder.setVertexBuffer(stars, offset: 0, index: 1)
            var equatorialToWorld = Self.starMatrix(state: state)
            encoder.setVertexBytes(&equatorialToWorld,
                                   length: MemoryLayout<float4x4>.stride, index: 2)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: starCount)

            // The wanderers, rebuilt every frame because wandering is the
            // whole point. Five vertices ride inline; the shader knows them
            // by the flag in colour.w and holds them steady — the eye tells
            // a planet from a star by exactly that steadiness.
            var planets = Self.planetVertices(at: state.epoch.terrestrialTime)
            encoder.setVertexBytes(&planets,
                                   length: MemoryLayout<StarVertex>.stride * planets.count,
                                   index: 1)
            encoder.drawPrimitives(type: .point, vertexStart: 0,
                                   vertexCount: planets.count)

            // The hand-drawn figures, joined star to star from the same
            // instance buffer, so they precess with the sky they annotate.
            if state.constellationLines, constellationVertexCount > 0,
               let lines = constellationBuffer {
                encoder.setRenderPipelineState(constellationPipeline)
                encoder.setVertexBuffer(lines, offset: 0, index: 1)
                encoder.drawPrimitives(type: .line, vertexStart: 0,
                                       vertexCount: constellationVertexCount)
            }
        }

        encoder.setRenderPipelineState(scenePipeline)
        encoder.setDepthStencilState(sceneDepthState)
        // State the winding rather than inheriting Metal's default.
        //
        // Metal treats CLOCKWISE as front-facing unless told otherwise. The
        // meshes here are built counter-clockwise seen from outside — the
        // right-hand rule, so that the cross product of two edges points out —
        // which meant .back culled exactly the faces pointing at the camera and
        // drew the ones behind them. Every coverage test still passed, because
        // the silhouette was just as full; what you saw was the inside of the
        // stone's back wall, and it read as the front being transparent.
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.back)
        encoder.setFragmentTexture(shadowMap, index: 0)
        encoder.setFragmentSamplerState(shadowSampler, index: 0)
        encoder.setFragmentSamplerState(surfaceSampler, index: 1)

        for item in drawItems + overlayItems {
            var draw = item.uniforms

            // Bind whichever material set this item wants. When the textures
            // failed to load the slots stay empty and the shader's samples come
            // back as zero — which would render the world black, so the flag
            // that selects textured shading is cleared instead and the item
            // falls back to flat albedo. A missing photograph must not be able
            // to take the almanac down with it.
            if state.surfaceTexturing, let set = surfaces[safe: item.surfaceKind.rawValue] {
                encoder.setFragmentTexture(set.albedo, index: 1)
                encoder.setFragmentTexture(set.normal, index: 2)
                encoder.setFragmentTexture(set.roughness, index: 3)
            } else {
                // Tell the *shader* to take the flat branch. Merely leaving the
                // texture slots empty is not enough — an unbound sample reads
                // as zero and multiplies the whole surface to black.
                draw.surface.w = 0
            }
            if !state.weathering { draw.weather.y = 0 }
            encoder.setVertexBuffer(item.vertexBuffer, offset: 0, index: 30)
            encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&draw, length: MemoryLayout<DrawUniforms>.stride, index: 1)
            encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.setFragmentBytes(&draw, length: MemoryLayout<DrawUniforms>.stride, index: 1)
            encoder.drawIndexedPrimitives(type: .triangle,
                                          indexCount: item.indexCount,
                                          indexType: .uint32,
                                          indexBuffer: item.indexBuffer,
                                          indexBufferOffset: 0)
        }

        // Blades last, over the finished ground. They are two-sided — a blade
        // is thin enough that which face you see is close to arbitrary, and
        // culling would blank half the field.
        if grassBladeCount > 0,
           let shape = grassShapeBuffer,
           let indices = grassIndexBuffer,
           let instances = grassInstanceBuffer {
            encoder.setRenderPipelineState(grassPipeline)
            encoder.setCullMode(.none)
            encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(shape, offset: 0, index: 1)
            encoder.setVertexBuffer(instances, offset: 0, index: 2)
            encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.drawIndexedPrimitives(type: .triangle,
                                          indexCount: grassIndexCount,
                                          indexType: .uint16,
                                          indexBuffer: indices,
                                          indexBufferOffset: 0,
                                          instanceCount: grassBladeCount)
        }
    }

    /// The five naked-eye planets as star vertices, in the same
    /// equatorial-of-date frame the star buffer uses. `colour.w = 1` is the
    /// planet flag the shader reads to withhold the twinkle.
    static func planetVertices(at tt: JulianDay) -> [StarVertex] {
        PlanetEphemeris.all(at: tt).map { entry in
            let direction = StarField.unitVector(
                rightAscension: entry.place.rightAscension,
                declination: entry.place.declination)
            return StarVertex(direction: SIMD4(SIMD3<Float>(direction),
                                               Float(entry.place.magnitude)),
                              colour: SIMD4(entry.planet.colour, 1))
        }
    }

    /// The rotation carrying equatorial star vectors into world axes, from
    /// sidereal time and the site — `StarField.worldRows` as a matrix the
    /// GPU can apply. Rows become columns of the transpose; simd's
    /// row-constructor keeps the intent readable.
    static func starMatrix(state: SceneState) -> float4x4 {
        let sidereal = Sidereal.greenwichMean(at: state.epoch)
        let rows = StarField.worldRows(siderealTime: sidereal, site: state.site)
        return float4x4(rows: [
            SIMD4<Float>(SIMD3<Float>(rows.east), 0),
            SIMD4<Float>(SIMD3<Float>(rows.up), 0),
            SIMD4<Float>(SIMD3<Float>(rows.south), 0),
            SIMD4<Float>(0, 0, 0, 1)
        ])
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspectRatio = size.height > 0 ? Float(size.width / size.height) : 1
    }

    public func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        inFlightSemaphore.wait()
        let semaphore = inFlightSemaphore
        commandBuffer.addCompletedHandler { _ in semaphore.signal() }

        frameIndex = (frameIndex + 1) % Self.framesInFlight
        let uniformBuffer = frameUniformBuffers[frameIndex]
        refreshStarsIfNeeded()
        var uniforms = buildFrameUniforms(aspect: aspectRatio)
        uniformBuffer.contents().copyMemory(from: &uniforms,
                                            byteCount: MemoryLayout<FrameUniforms>.stride)

        encodeShadowPass(commandBuffer, uniforms: uniforms)

        // The light shafts need the finished depth buffer, so when they are
        // due the scene's depth is kept rather than discarded. The view's
        // depth texture must have been made sampleable by the bridge; when a
        // host has not done that, the beams are skipped rather than crashed.
        let depthTexture = descriptor.depthAttachment.texture
        let wantsHaze = uniforms.haze.x > 0
            && depthTexture?.usage.contains(.shaderRead) == true
        if wantsHaze { descriptor.depthAttachment.storeAction = .store }

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.label = "scene"
            encodeScenePass(encoder, uniformBuffer: uniformBuffer)
            encoder.endEncoding()
        }

        if wantsHaze, let depthTexture {
            encodeHazePass(commandBuffer, colour: drawable.texture,
                           depth: depthTexture, uniformBuffer: uniformBuffer)
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// The fullscreen light-shaft pass, blended over the finished frame.
    private func encodeHazePass(_ commandBuffer: MTLCommandBuffer,
                                colour: MTLTexture, depth: MTLTexture,
                                uniformBuffer: MTLBuffer) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = colour
        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }
        encoder.label = "light shafts"
        encoder.setRenderPipelineState(hazePipeline)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(shadowMap, index: 0)
        encoder.setFragmentTexture(depth, index: 1)
        encoder.setFragmentSamplerState(shadowSampler, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    // ── headless ────────────────────────────────────────────────────────────

    /// Render one frame into a texture the CPU can read.
    ///
    /// This is the entry point for layer 2 of the oracle: it is how the test
    /// harness gets pixels to measure the shadow in, with no window, no
    /// drawable and no display attached.
    public func renderOffscreen(width: Int, height: Int) throws -> MTLTexture {
        try renderOffscreen(width: width, height: height, keepDepth: false).colour
    }

    /// Render, optionally keeping the depth buffer readable.
    ///
    /// Depth is what settles whether the surface you are looking at is the near
    /// one. Colour cannot: if the near faces were culled and the far ones drawn,
    /// the silhouette is still filled and every coverage test still passes,
    /// while you are in fact seeing the inside of the back wall.
    public func renderOffscreen(width: Int, height: Int,
                                keepDepth: Bool) throws -> (colour: MTLTexture,
                                                            depth: MTLTexture?) {
        let colourDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: Self.colourFormat, width: width, height: height, mipmapped: false)
        colourDescriptor.usage = [.renderTarget, .shaderRead]
        colourDescriptor.storageMode = .shared

        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: Self.depthFormat, width: width, height: height, mipmapped: false)
        // Always sampleable: the light-shaft pass reads it back even when the
        // caller has no use for the depth. Shared storage only when the CPU
        // will look at it.
        depthDescriptor.usage = [.renderTarget, .shaderRead]
        depthDescriptor.storageMode = keepDepth ? .shared : .private

        guard let colour = device.makeTexture(descriptor: colourDescriptor),
              let depth = device.makeTexture(descriptor: depthDescriptor),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw RendererError.resourceCreationFailed("offscreen targets")
        }

        let aspect = Float(width) / Float(height)
        refreshStarsIfNeeded()
        var uniforms = buildFrameUniforms(aspect: aspect)
        let uniformBuffer = frameUniformBuffers[0]
        uniformBuffer.contents().copyMemory(from: &uniforms,
                                            byteCount: MemoryLayout<FrameUniforms>.stride)

        encodeShadowPass(commandBuffer, uniforms: uniforms)

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = colour
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        descriptor.depthAttachment.texture = depth
        descriptor.depthAttachment.loadAction = .clear
        let wantsHaze = uniforms.haze.x > 0
        descriptor.depthAttachment.storeAction = keepDepth || wantsHaze ? .store : .dontCare
        // Reverse-Z: the far plane is zero.
        descriptor.depthAttachment.clearDepth = 0.0

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.label = "offscreen scene"
            encodeScenePass(encoder, uniformBuffer: uniformBuffer)
            encoder.endEncoding()
        }

        if wantsHaze {
            encodeHazePass(commandBuffer, colour: colour, depth: depth,
                           uniformBuffer: uniformBuffer)
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return (colour, keepDepth ? depth : nil)
    }

    /// Recover view-space distance from a reverse-Z depth sample.
    ///
    /// z_ndc = near / distance, so distance = near / z_ndc.
    public static func distance(fromReverseZ depth: Float, near: Float) -> Float {
        depth > 1e-9 ? near / depth : .infinity
    }
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}
