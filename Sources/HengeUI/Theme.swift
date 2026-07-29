import SwiftUI

/// "Mistletoe & Oak" — the design language, such as it is.
///
/// Two constraints shaped this more than taste did.
///
/// **No vendored fonts.** A typeface is data with a licence, and invariant 5
/// says data arrives with provenance settled first. So the druidic register is
/// built from `Font.Design.serif`, which on Apple platforms is New York — a
/// modern face with old bones, and nothing to license. Numbers stay monospaced
/// because an almanac that reflows its digits as time runs is unreadable.
///
/// **Nothing decorative may compete with the sky.** The chrome sits over a
/// physically-modelled sunrise. Anything with its own strong colour would lie
/// about the light, so the palette is desaturated stone, oak and bronze, and
/// the panels are glass — they take their colour from whatever is behind them,
/// which at dawn is the dawn.
public enum Henge {

    // ── colour ──────────────────────────────────────────────────────────────

    /// Weathered sarsen. The default ink.
    public static let stone = Color(red: 0.87, green: 0.85, blue: 0.80)
    /// Wet oak bark — the darker ink, for panels that need one.
    public static let oak = Color(red: 0.20, green: 0.16, blue: 0.13)
    /// Old bronze. The accent, and the only warm note.
    public static let bronze = Color(red: 0.72, green: 0.55, blue: 0.28)
    /// Mistletoe. Used sparingly, for the thing that is currently true.
    public static let mistletoe = Color(red: 0.62, green: 0.72, blue: 0.55)

    // ── type ────────────────────────────────────────────────────────────────

    /// Titles and names. Serif, because the register is bardic.
    public static func title(_ style: Font.TextStyle = .title3) -> Font {
        .system(style, design: .serif).weight(.medium)
    }

    /// Running text.
    public static func body(_ style: Font.TextStyle = .callout) -> Font {
        .system(style, design: .serif)
    }

    /// Anything with a number in it. Monospaced digits so a running clock does
    /// not jitter, and rounded rather than serif because a serif numeral at
    /// caption size on a bright sky is illegible.
    public static func figure(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .monospaced)
    }

    // ── the system ──────────────────────────────────────────────────────────
    //
    // The numbers below are the design language's whole vocabulary. The
    // chrome grew organically and every panel had its own paddings, radii
    // and fades — plausible one at a time, arbitrary in aggregate. A view
    // that needs a spacing not named here should argue for a new name, not
    // reach for a literal: the system stays a system only while its
    // vocabulary stays small.

    /// Spacing, on a 4-point rhythm. `hair` separates a label from its
    /// value; `tight` stacks rows; `element` separates controls; `panel`
    /// pads glass from its content; `margin` floats glass off the screen
    /// edge and off other glass.
    public enum Space {
        public static let hair: CGFloat = 2
        public static let tight: CGFloat = 6
        public static let element: CGFloat = 8
        public static let panel: CGFloat = 10
        public static let margin: CGFloat = 14
    }

    /// Two radii, deliberately: glass panels share one, and controls are
    /// capsules. A third radius is a design decision, not a tweak.
    public enum Radius {
        public static let panel: CGFloat = 14
    }

    /// Ink emphasis levels over glass. Full ink is the default; `dim` is
    /// supporting text; `faint` is provenance and units; `hairline` is a
    /// rule that should be sensed rather than read.
    public enum Ink {
        public static let dim = 0.75
        public static let faint = 0.65
        public static let hairline = 0.22
    }

    /// The two durations chrome is allowed: `quick` for state that flips,
    /// `settle` for things that travel. Both return nil under Reduce Motion
    /// so every call site honours the setting by construction — invariant 7
    /// as an API rather than a discipline.
    public static func quick(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    public static func settle(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.3)
    }
}

public extension View {

    /// A glass panel.
    ///
    /// Liquid Glass where the OS has it, `.ultraThinMaterial` everywhere else.
    /// The fallback is not a consolation prize — the material already takes its
    /// colour from the sky behind it, which is the property that matters here.
    @ViewBuilder
    func hengePanel(cornerRadius: CGFloat = Henge.Radius.panel) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Henge.stone.opacity(0.18), lineWidth: 1))
        }
    }

    /// A glass control — same material, tighter radius, for buttons and tabs.
    @ViewBuilder
    func hengeControl(isSelected: Bool = false) -> some View {
        let shape = Capsule(style: .continuous)
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(isSelected ? .regular.tint(Henge.bronze.opacity(0.45))
                                        : .regular,
                             in: shape)
        } else {
            self.background(isSelected ? AnyShapeStyle(Henge.bronze.opacity(0.35))
                                       : AnyShapeStyle(.ultraThinMaterial),
                            in: shape)
        }
    }
}

/// Wraps a cluster of glass elements so they behave as one material.
///
/// Liquid Glass is not a per-view backdrop blur — nearby glass elements are
/// meant to merge, refract together and share a single lensing pass. Without a
/// container each panel is its own island, which reads as several stacked
/// plates of frosted plastic rather than one piece of glass, and costs more to
/// draw besides. Everything else about the panels was already right; this is
/// what makes them look like the material they are asking for.
///
/// Below the OS versions that have it, this is a plain passthrough and the
/// `.ultraThinMaterial` fallback in `hengePanel` does the work.
public struct HengeGlass<Content: View>: View {

    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

