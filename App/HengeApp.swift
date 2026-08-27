import SwiftUI
import HengeUI

/// One entry point, compiled into both the iOS and the macOS target.
///
/// `project.yml` lists `App/` in the sources of both, so this file is the
/// single definition of the app's structure; anything genuinely
/// platform-specific goes in `iOSApp/` or `macOSApp/`, or behind `#if os(...)`
/// in HengeUI.
@main
struct HengeApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
        // The Mac's keyboard and assistive route to every function the
        // floating rails offer. See `HengeCommands` and GitHub issue #1:
        // before this, a rail was the only way in, which for a keyboard-only
        // or Switch Control user is no way in at all.
        .commands { HengeCommands() }
        #endif
    }
}
