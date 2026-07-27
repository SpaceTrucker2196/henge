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
        #endif
    }
}
