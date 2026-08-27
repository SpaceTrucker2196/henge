#if os(macOS)
import SwiftUI

/// The Mac menu bar, and the second half of invariant 7.
///
/// Raised by GitHub issue #1. The app's controls live in glass rails floating
/// over the monument, and on the Mac that was the *only* way to reach any of
/// them: no menu carried them, and no keyboard shortcut existed. For a
/// keyboard-only user, or anyone driving the app through Voice Control or
/// Switch Control, a floating rail is not a hard route to a function — it is
/// the absence of one.
///
/// So every model-backed function the rail offers is repeated here, named with
/// the *same* catalogue key the rail's own accessibility label uses. Two
/// routes, one vocabulary: what VoiceOver calls the control is what the menu
/// calls the command, in all nine languages, and neither can drift from the
/// other without the other changing too.
///
/// Reaching the model takes `focusedSceneValue` rather than a shared instance:
/// `RootView` owns its `SkyModel` and should keep owning it, and a Mac can
/// have two windows open on two different moments.
public struct HengeModelKey: FocusedValueKey {
    public typealias Value = SkyModel
}

public extension FocusedValues {
    var hengeModel: SkyModel? {
        get { self[HengeModelKey.self] }
        set { self[HengeModelKey.self] = newValue }
    }
}

public struct HengeCommands: Commands {

    @FocusedValue(\.hengeModel) private var model

    public init() {}

    /// A menu item that flips something on the model.
    ///
    /// Named from the catalogue, and named for what the command *does* rather
    /// than for what is currently true — "Show the zodiac" when it is hidden —
    /// so the menu reads the same way the rail's VoiceOver label does.
    @ViewBuilder
    private func item(_ key: LocalizedStringKey,
                      _ shortcut: KeyEquivalent,
                      modifiers: EventModifiers = [.command, .option],
                      action: @escaping (SkyModel) -> Void) -> some View {
        Button {
            if let model { action(model) }
        } label: {
            Text(key, bundle: .module)
        }
        .keyboardShortcut(shortcut, modifiers: modifiers)
        .disabled(model == nil)
    }

    public var body: some Commands {
        // A menu of its own rather than additions to View: these are the
        // app's subject matter, not window furniture.
        CommandMenu(String(localized: "menu.monument", bundle: .module)) {

            // ── where you stand ─────────────────────────────────────────────
            ForEach(Array(SkyModel.Station.allCases.enumerated()), id: \.element) {
                index, station in
                Button {
                    model?.station = station
                } label: {
                    Text(station.localizedName)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")),
                                  modifiers: .command)
                .disabled(model == nil)
            }

            Divider()

            item("scene.action.recentre", "0", modifiers: .command) {
                $0.recentre()
            }

            // ── what is drawn on it ─────────────────────────────────────────
            Divider()

            item(model?.showsAlignmentOverlay == true
                 ? "toggle.overlay.hide" : "toggle.overlay.show", "a") {
                $0.showsAlignmentOverlay.toggle()
            }
            item(model?.showsLunarMarkers == true
                 ? "toggle.markers.hide" : "toggle.markers.show", "m") {
                $0.showsLunarMarkers.toggle()
            }
            item(model?.torchlight == true
                 ? "toggle.torch.out" : "toggle.torch.light", "t") {
                $0.torchlight.toggle()
            }
            item(model?.showsStarLabels == true
                 ? "toggle.starLabels.hide" : "toggle.starLabels.show", "n") {
                $0.showsStarLabels.toggle()
            }
            item(model?.showsConstellationLines == true
                 ? "toggle.constellations.hide" : "toggle.constellations.show", "c") {
                $0.showsConstellationLines.toggle()
            }
            item(model?.showsZodiac == true
                 ? "toggle.zodiac.hide" : "toggle.zodiac.show", "z") {
                $0.showsZodiac.toggle()
            }
            // Not the rail's key here. The rail's label states what is on
            // screen — "Showing the monument as built" — which is right for a
            // toggle button and wrong for a menu, where every other line is an
            // instruction. A menu item has to say what picking it will do.
            item(model?.monumentState == .asItWas
                 ? "menu.monument.showRuin" : "menu.monument.showBuilt", "r") {
                $0.requestState($0.monumentState == .asItWas ? .asItStands : .asItWas,
                                animated: true)
            }

            // ── how it moves ────────────────────────────────────────────────
            Divider()

            item(model?.smoothPan == true
                 ? "toggle.smoothPan.off" : "toggle.smoothPan.on", "p") {
                $0.smoothPan.toggle()
                if !$0.smoothPan { $0.stopDrifting() }
            }

            Divider()

            item(model?.isPlaying == true
                 ? "control.play.pause" : "control.play.run", "y",
                 modifiers: .command) {
                $0.isPlaying.toggle()
            }
            item("control.backOneDay", "[", modifiers: .command) {
                $0.jump(toDaysFromNow: -1)
            }
            item("control.forwardOneDay", "]", modifiers: .command) {
                $0.jump(toDaysFromNow: 1)
            }
        }
    }
}
#endif
