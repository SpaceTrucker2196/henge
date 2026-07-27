import SwiftUI
import HengeCore

/// The shared surface both apps present. Platform differences belong behind
/// `#if os(...)` here rather than in duplicated view code in the app targets —
/// the app targets stay thin shells so there is one place for the UI to live.
///
/// SCAFFOLD: this view exists so both targets build, launch and show something
/// on first run. It is the first thing the opening production order replaces.
public struct RootView: View {

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            Text(Henge.name.uppercased())
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .kerning(6)

            Text("v\(Henge.version.description)")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider()
                .frame(maxWidth: 220)

            Text("Scaffold. The mission is not written yet.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }
}

#Preview {
    RootView()
}
