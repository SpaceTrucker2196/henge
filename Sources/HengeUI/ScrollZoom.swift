import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Scroll and trackpad-pinch zoom on the Mac.
///
/// `MagnifyGesture` covers the iPad, and covers a Mac trackpad pinch in
/// principle — but on the Mac the gesture people actually reach for is a
/// two-finger scroll, and SwiftUI has no gesture for it. Nor does the app get
/// one for free: the scene is an `MTKView` behind an `NSViewRepresentable`, and
/// scroll events route by hit-testing to whichever view is under the pointer.
///
/// A transparent overlay view could catch them, but only by being hit-testable,
/// which would mean it also swallowed the clicks the drag gesture needs. So
/// this uses a local event monitor instead: it sees the events before they are
/// dispatched, without taking part in hit-testing at all, and returns them
/// unchanged so nothing downstream is starved.
///
/// On iOS the modifier compiles to nothing.
struct ScrollZoom: ViewModifier {

    let onZoom: (Double) -> Void

    #if os(macOS)
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(
                    matching: [.scrollWheel, .magnify]
                ) { event in
                    MainActor.assumeIsolated {
                        switch event.type {
                        case .magnify:
                            let scale = 1 + event.magnification
                            if scale > 0 { onZoom(scale) }
                        default:
                            // A trackpad reports fine-grained deltas many times
                            // a second; a wheel reports coarse notches a few
                            // times. Scaling them the same way makes the wheel
                            // useless or the trackpad frantic, so each gets its
                            // own divisor. Exponential because zoom is
                            // multiplicative — a fixed step is huge when you
                            // are close and imperceptible when you are far.
                            let delta = event.hasPreciseScrollingDeltas
                                ? event.scrollingDeltaY / 260
                                : event.scrollingDeltaY / 9
                            if delta != 0 { onZoom(exp(delta)) }
                        }
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
    #else
    func body(content: Content) -> some View { content }
    #endif
}
