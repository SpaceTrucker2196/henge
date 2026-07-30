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
        var overlayKey: Int = 0
        var overlayRebuiltAt: Date = .distantPast
        var rebuild: Task<Void, Never>?
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
        // The launch screen's pre-dawn slate, held until the first frame
        // draws over it — without this the gap between the two is a flash
        // of bare window white.
        #if canImport(UIKit)
        view.backgroundColor = UIColor(red: 0.098, green: 0.153,
                                       blue: 0.231, alpha: 1)
        #else
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor(red: 0.098, green: 0.153,
                                              blue: 0.231, alpha: 1)
        #endif

        do {
            let renderer = try HengeRenderer(state: model.sceneState)
            renderer.terrain = SkyModel.terrain
            // Launch opens on the plain, not on a blank frame: the terrain
            // and sky load here (quick), and `loadedState` is left nil so
            // the first update pass finds the monument missing and raises
            // the stones through the same asynchronous path the ruin/whole
            // switch uses — progress card and all. Before this, eighty
            // stone meshes built synchronously inside the first frame, and
            // launch was seconds of blank white after the launch screen.
            try renderer.load(scene: MonumentScene(stones: []))
            context.coordinator.renderer = renderer
            context.coordinator.loadedState = nil
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
        if context.coordinator.loadedState != model.monumentState,
           context.coordinator.rebuild == nil {
            // The rebuild happens off the main actor so the progress card
            // can actually move — eighty displaced stone meshes are most of
            // a second, and building them mid-frame froze the app with no
            // explanation. The upload at the end is quick; the frame the
            // bar vanishes on is the frame the new monument stands.
            let coordinator = context.coordinator
            let target = model.monumentState
            let scene = model.scene
            let terrain = SkyModel.terrain
            let soilBanks = renderer.state.soilBanks
            let model = self.model
            model.rebuildProgress = 0
            coordinator.rebuild = Task {
                let prepared = await Task.detached(priority: .userInitiated) {
                    HengeRenderer.prepare(scene: scene, terrain: terrain,
                                          soilBanks: soilBanks) { fraction in
                        Task { @MainActor in model.rebuildProgress = fraction }
                    }
                }.value
                try? renderer.load(prepared: prepared)
                coordinator.loadedState = target
                model.rebuildProgress = nil
                coordinator.rebuild = nil
            }
        }
        // The overlay rebuilds only when its key moves — a mode switch, a
        // marker changing disc, a bearing drifting past half a degree — and
        // never more than five times a second regardless. At a day a second
        // the sun's bearing steps past the key's quantum on every tick, and
        // without the wall-clock floor the diagram would rebuild meshes and
        // reallocate buffers at frame rate for as long as the time-lapse ran.
        let key = model.overlayKey
        if context.coordinator.overlayKey != key,
           Date().timeIntervalSince(context.coordinator.overlayRebuiltAt) > 0.2 {
            renderer.loadOverlay(model.overlayPieces())
            context.coordinator.overlayKey = key
            context.coordinator.overlayRebuiltAt = Date()
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
