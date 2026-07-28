import SwiftUI
import MetalKit
import HengeAstro
import HengeGeometry
import HengeEngine

#if os(macOS)
public typealias PlatformViewRepresentable = NSViewRepresentable
#else
public typealias PlatformViewRepresentable = UIViewRepresentable
#endif

/// The one place SwiftUI and Metal meet.
///
/// `HengeEngine` never imports SwiftUI — that rule is what keeps the renderer
/// testable from a command line with no UI — so the bridge lives here instead.
public struct HengeSceneView: PlatformViewRepresentable {

    @Bindable public var model: SkyModel

    public init(model: SkyModel) {
        self.model = model
    }

    public final class Coordinator {
        var renderer: HengeRenderer?
        var loadedState: Monument.State?
        var failure: String?
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    private func makeMTKView(context: Context) -> MTKView {
        let view = MTKView()
        view.colorPixelFormat = HengeRenderer.colourFormat
        view.depthStencilPixelFormat = HengeRenderer.depthFormat
        // Reverse-Z: clear to the far plane, which is zero.
        view.clearDepth = 0
        // The light-shaft pass samples the scene's depth after the scene has
        // drawn; without shader-read here the renderer quietly skips the
        // beams, which is exactly the wrong kind of graceful.
        view.depthStencilAttachmentTextureUsage = [.renderTarget, .shaderRead]
        view.preferredFramesPerSecond = 120     // ProMotion where it exists
        view.isPaused = false
        view.enableSetNeedsDisplay = false

        do {
            let renderer = try HengeRenderer(state: model.sceneState)
            renderer.terrain = SkyModel.terrain
            try renderer.load(scene: model.scene)
            context.coordinator.renderer = renderer
            context.coordinator.loadedState = model.monumentState
            view.device = renderer.device
            view.delegate = renderer
        } catch {
            // A machine with no Metal device, or a shader that will not
            // compile. Record it rather than crashing: the almanac numbers are
            // still correct and still worth showing.
            context.coordinator.failure = String(describing: error)
        }
        return view
    }

    private func update(_ view: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.state = model.sceneState
        if context.coordinator.loadedState != model.monumentState {
            try? renderer.load(scene: model.scene)
            context.coordinator.loadedState = model.monumentState
        }
    }

    #if os(macOS)
    public func makeNSView(context: Context) -> MTKView { makeMTKView(context: context) }
    public func updateNSView(_ view: MTKView, context: Context) { update(view, context: context) }
    #else
    public func makeUIView(context: Context) -> MTKView { makeMTKView(context: context) }
    public func updateUIView(_ view: MTKView, context: Context) { update(view, context: context) }
    #endif
}
