import Foundation
import Metal
import MetalKit
import simd
import HengeAstro
import HengeGeometry

/// Everything the renderer needs to know about the moment being drawn.
public struct SceneState: Sendable {

    /// Where the sun is, from `HengeAstro`. Never set by hand — invariant 1.
    public var sun: HorizontalCoordinate
    /// Apparent angular *radius* of the sun in radians.
    public var sunAngularRadius: Double
    public var camera: Camera
    /// Preetham turbidity: 2 is a clear day, 6 is hazy.
    public var turbidity: Float
    public var exposure: Float

    public init(sun: HorizontalCoordinate,
                sunAngularRadius: Double = 0.00465,
                camera: Camera = Camera(),
                turbidity: Float = 2.4,
                exposure: Float = 1.6) {
        self.sun = sun
        self.sunAngularRadius = sunAngularRadius
        self.camera = camera
        self.turbidity = turbidity
        self.exposure = exposure
    }

    /// Build the state for a moment in time at a site. This is the only path
    /// the app uses, so the sun in the sky and the sun in the almanac are by
    /// construction the same sun.
    public static func at(_ ut: JulianDay,
                          site: GeographicSite = .stonehenge,
                          camera: Camera = Camera()) -> SceneState {
        let sun = Sun.horizontal(at: ut, site: site)
        let position = Sun.position(at: ut.terrestrialTime)
        return SceneState(sun: sun,
                          sunAngularRadius: position.angularDiameter.radians / 2,
                          camera: camera)
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

/// A block of geometry the renderer can draw in one call.
struct DrawItem {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var indexCount: Int
    var uniforms: DrawUniforms
    var castsShadow: Bool
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
    private let shadowPipeline: MTLRenderPipelineState
    private let skyPipeline: MTLRenderPipelineState
    private let sceneDepthState: MTLDepthStencilState
    private let skyDepthState: MTLDepthStencilState
    private let shadowSampler: MTLSamplerState
    private let shadowMap: MTLTexture
    private let shadowResolution: Int

    /// Triple-buffered so the CPU can build frame N+1 while the GPU is still
    /// reading frame N's uniforms. Without this the CPU would have to wait on
    /// every frame, and the time-lapse would stutter exactly when it matters.
    private var frameUniformBuffers: [MTLBuffer] = []
    private var frameIndex = 0
    private let inFlightSemaphore = DispatchSemaphore(value: HengeRenderer.framesInFlight)

    private var drawItems: [DrawItem] = []
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
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 30
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
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
        self.shadowPipeline = try pipeline("shadow", vertex: "shadow_vertex",
                                           fragment: nil, colour: nil,
                                           depth: Self.depthFormat,
                                           useVertexDescriptor: true)
        self.skyPipeline = try pipeline("sky", vertex: "sky_vertex",
                                        fragment: "sky_fragment",
                                        colour: Self.colourFormat,
                                        depth: Self.depthFormat,
                                        useVertexDescriptor: false)

        let sceneDepth = MTLDepthStencilDescriptor()
        sceneDepth.depthCompareFunction = .less
        sceneDepth.isDepthWriteEnabled = true
        guard let sceneDepthState = device.makeDepthStencilState(descriptor: sceneDepth) else {
            throw RendererError.resourceCreationFailed("depth state")
        }
        self.sceneDepthState = sceneDepthState

        // The sky fills whatever the stones did not, and writes no depth.
        let skyDepth = MTLDepthStencilDescriptor()
        skyDepth.depthCompareFunction = .lessEqual
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
        var items: [DrawItem] = []

        for stone in scene.stones {
            // Chalk discs are flat and small; they do not need the tessellation
            // a seven-metre sarsen does.
            let detail = stone.material == .chalk ? 5 : subdivisions
            let mesh = StoneMeshBuilder.build(stone, subdivisions: detail,
                                              roughness: roughness, rounding: rounding)
            if let item = try makeDrawItem(mesh: mesh,
                                           albedo: SurfaceMaterial.albedo(for: stone.material),
                                           label: stone.id,
                                           // A disc flush in the turf casting a
                                           // shadow would be a hole, not a stone.
                                           castsShadow: stone.material != .chalk) {
                items.append(item)
            }
        }

        // Salisbury Plain itself, displaced by the surveyed heightfield.
        //
        // Reaching as far as the data does, so there is no edge of the world a
        // few hundred metres out. Resolution is spent where it is seen: the
        // grid is denser near the monument and coarsens outward, because the
        // ridge four kilometres away needs far fewer triangles per metre than
        // the turf underfoot.
        let ground = Self.groundMesh(terrain: terrain, divisions: 220)
        if let item = try makeDrawItem(mesh: ground, albedo: SurfaceMaterial.turf,
                                       label: "ground", castsShadow: false) {
            items.append(item)
        }

        drawItems = items
    }

    private func makeDrawItem(mesh: Mesh, albedo: SIMD4<Float>, label: String,
                              castsShadow: Bool = true) throws -> DrawItem? {
        guard !mesh.positions.isEmpty, !mesh.indices.isEmpty else { return nil }

        var vertices: [MeshVertex] = []
        vertices.reserveCapacity(mesh.positions.count)
        for i in mesh.positions.indices {
            vertices.append(MeshVertex(position: mesh.positions[i], normal: mesh.normals[i]))
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
                        uniforms: DrawUniforms(albedo: albedo),
                        castsShadow: castsShadow)
    }

    /// Ground mesh, optionally displaced by the terrain.
    ///
    /// Vertices are placed on a grid warped by a cubic, so spacing is fine near
    /// the monument and stretches toward the horizon. A uniform grid over 30 km
    /// would either be too coarse underfoot or ruinously dense at the edges.
    static func groundMesh(terrain: TerrainModel?, divisions: Int) -> Mesh {
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
                mesh.indices.append(contentsOf: [a, b, c, a, c, d])
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
    static func cascadeMatrix(camera: Camera, aspect: Float,
                              near: Float, far: Float,
                              lightDirection: SIMD3<Float>,
                              resolution: Int) -> float4x4 {
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

        let eye = snappedCentre + lightDirection * (radius * 2)
        let view = MetalMath.lookAt(eye: eye, target: snappedCentre,
                                    up: abs(lightDirection.y) > 0.99
                                        ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0, 1, 0))
        let projection = MetalMath.orthographic(left: -radius, right: radius,
                                                bottom: -radius, top: radius,
                                                near: 0.1, far: radius * 4.5)
        return projection * view
    }

    func buildFrameUniforms(aspect: Float) -> FrameUniforms {
        let view = state.camera.view()
        let projection = state.camera.projection(aspect: aspect)
        let viewProjection = projection * view
        let sunDirection = state.sunDirection

        let splits = SIMD4<Float>(24, 90, 320, 0)
        var matrices = (matrix_identity_float4x4, matrix_identity_float4x4, matrix_identity_float4x4)

        // Only fit cascades when the sun is actually up; below the horizon the
        // light direction degenerates and the fit produces garbage.
        if sunDirection.y > 0.01 {
            let m0 = Self.cascadeMatrix(camera: state.camera, aspect: aspect,
                                        near: state.camera.near, far: splits.x,
                                        lightDirection: sunDirection,
                                        resolution: shadowResolution)
            let m1 = Self.cascadeMatrix(camera: state.camera, aspect: aspect,
                                        near: splits.x, far: splits.y,
                                        lightDirection: sunDirection,
                                        resolution: shadowResolution)
            let m2 = Self.cascadeMatrix(camera: state.camera, aspect: aspect,
                                        near: splits.y, far: splits.z,
                                        lightDirection: sunDirection,
                                        resolution: shadowResolution)
            matrices = (m0, m1, m2)
        }

        let radiance = state.sunRadiance
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
                                 1.0 / Float(shadowResolution))
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
            encoder.setDepthStencilState(sceneDepthState)
            // Front-face culling in the shadow pass pushes peter-panning into
            // the stone rather than out onto the ground, which matters when the
            // ground shadow is the thing being measured.
            encoder.setCullMode(.front)

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

    private func encodeScenePass(_ encoder: MTLRenderCommandEncoder,
                                 uniformBuffer: MTLBuffer) {
        // Sky first, filling the frame; the stones then draw over it.
        encoder.setRenderPipelineState(skyPipeline)
        encoder.setDepthStencilState(skyDepthState)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        encoder.setRenderPipelineState(scenePipeline)
        encoder.setDepthStencilState(sceneDepthState)
        encoder.setCullMode(.back)
        encoder.setFragmentTexture(shadowMap, index: 0)
        encoder.setFragmentSamplerState(shadowSampler, index: 0)

        for item in drawItems {
            var draw = item.uniforms
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
        var uniforms = buildFrameUniforms(aspect: aspectRatio)
        uniformBuffer.contents().copyMemory(from: &uniforms,
                                            byteCount: MemoryLayout<FrameUniforms>.stride)

        encodeShadowPass(commandBuffer, uniforms: uniforms)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.label = "scene"
            encodeScenePass(encoder, uniformBuffer: uniformBuffer)
            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // ── headless ────────────────────────────────────────────────────────────

    /// Render one frame into a texture the CPU can read.
    ///
    /// This is the entry point for layer 2 of the oracle: it is how the test
    /// harness gets pixels to measure the shadow in, with no window, no
    /// drawable and no display attached.
    public func renderOffscreen(width: Int, height: Int) throws -> MTLTexture {
        let colourDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: Self.colourFormat, width: width, height: height, mipmapped: false)
        colourDescriptor.usage = [.renderTarget, .shaderRead]
        colourDescriptor.storageMode = .shared

        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: Self.depthFormat, width: width, height: height, mipmapped: false)
        depthDescriptor.usage = .renderTarget
        depthDescriptor.storageMode = .private

        guard let colour = device.makeTexture(descriptor: colourDescriptor),
              let depth = device.makeTexture(descriptor: depthDescriptor),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw RendererError.resourceCreationFailed("offscreen targets")
        }

        let aspect = Float(width) / Float(height)
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
        descriptor.depthAttachment.storeAction = .dontCare
        descriptor.depthAttachment.clearDepth = 1.0

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.label = "offscreen scene"
            encodeScenePass(encoder, uniformBuffer: uniformBuffer)
            encoder.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return colour
    }
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}
