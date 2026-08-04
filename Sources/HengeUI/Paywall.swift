import SwiftUI
import HengeStore

/// The offer, and the two places it is made.
///
/// One `PurchaseOffer` serves both, deliberately. The paywall that stands when
/// the session ends and the panel inside the time machine are the same offer
/// in different frames, and writing them twice is how a price ends up
/// disagreeing with itself in a screenshot.
///
/// The tone is the app's: what is bought is stated plainly, once, without a
/// countdown badgering the reader or a struck-through price that was never
/// charged. The monument has stood for four and a half thousand years without
/// billing anyone monthly, and the purchase is the same shape — paid once,
/// owned after.
struct PurchaseOffer: View {

    let store: PurchaseController
    /// What brought the reader here; the rest of the offer is identical.
    let headline: LocalizedStringKey
    let blurb: LocalizedStringKey
    /// The three-line summary of what the money buys. Dropped inside the time
    /// machine, where the reader is already standing in front of the feature
    /// and does not need it described back to them.
    var showsBenefits = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Henge.Space.panel) {
            Text(headline, bundle: .module)
                .font(Henge.title(.title3))

            Text(blurb, bundle: .module)
                .font(Henge.body(.caption))
                .opacity(Henge.Ink.dim)
                .fixedSize(horizontal: false, vertical: true)

            if showsBenefits {
                VStack(alignment: .leading, spacing: Henge.Space.tight) {
                    offerRow("infinity",
                             "paywall.benefit.unlimited")
                    offerRow("calendar",
                             "paywall.benefit.timeTravel")
                    offerRow("checkmark.seal",
                             "paywall.benefit.once")
                }
            }

            if let failure = store.failure {
                Text(failure)
                    .font(Henge.body(.caption2))
                    .foregroundStyle(Henge.bronze)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isStaticText)
            }

            Button {
                Task { await store.purchase() }
            } label: {
                HStack(spacing: Henge.Space.tight) {
                    if store.isPurchasing {
                        ProgressView().controlSize(.small)
                    }
                    // The price is StoreKit's own `displayPrice`, so it is
                    // right for the reader's storefront and currency rather
                    // than right for ours.
                    Text("paywall.buy \(store.displayPrice)", bundle: .module)
                        .font(Henge.body(.callout))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .hengeControl(isSelected: true)
            .disabled(store.isPurchasing)

            Button {
                Task { await store.restore() }
            } label: {
                Text("paywall.restore", bundle: .module)
                    .font(Henge.body(.caption2))
                    .opacity(Henge.Ink.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.isPurchasing)
        }
        .foregroundStyle(Henge.stone)
        .tint(Henge.bronze)
        .animation(Henge.quick(reduceMotion), value: store.failure)
    }

    private func offerRow(_ symbol: String,
                          _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Henge.Space.element) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .frame(width: 16)
                .opacity(Henge.Ink.dim)
                .accessibilityHidden(true)
            Text(text, bundle: .module)
                .font(Henge.body(.caption))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// What stands when the fifteen minutes are gone.
///
/// The monument stays visible behind it, dimmed rather than hidden. That is
/// not a flourish: the thing being sold is the view, and covering it entirely
/// to ask for money would be arguing against the product. There is no dismiss
/// — the session is genuinely over — but Restore is always reachable, because
/// someone who has already paid must never be trapped behind a wall they
/// bought their way past on another device.
struct PaywallView: View {

    let store: PurchaseController

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.45))
                .ignoresSafeArea()
                // Swallow every touch: the scene below is closed.
                .contentShape(Rectangle())
                .onTapGesture {}

            PurchaseOffer(store: store,
                          headline: "paywall.expired.title",
                          blurb: "paywall.expired.blurb")
                .padding(Henge.Space.margin + 8)
                .frame(maxWidth: 420)
                .hengeCard()
                .padding(Henge.Space.margin)
        }
        .transition(.opacity)
    }
}

/// The purchase button, and the clock it carries.
///
/// One control doing two jobs on purpose: while the session runs it is the
/// honest statement of how much is left, and pressing it is how anyone who
/// has decided already gets to the offer without waiting for the wall. It
/// disappears the moment the app is unlocked — an owner should never be shown
/// the clock they bought their way out of.
struct UnlockPill: View {

    let store: PurchaseController
    let action: () -> Void

    /// The pill stacks its glyph over its digits rather than setting them in a
    /// row, and that is a layout constraint rather than a preference: the
    /// almanac strip reserves exactly one control's width plus its margins
    /// down the trailing edge, and the rail lives in that lane. A pill wide
    /// enough to set "🔒 14:41" horizontally does not fit the lane, and the
    /// first build of it came to rest on the year bar's top edge on iPhone
    /// while sitting in clear air on iPad. Stacked, it fits every screen.
    private static let width = Henge.Hit.control

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: "lock")
                    .font(.system(size: 10, weight: .semibold))
                    .accessibilityHidden(true)
                Text(store.clock.formattedRemaining)
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
            }
            .frame(width: Self.width, height: Henge.Hit.controlHeight)
            .hengeControl()
            .frame(width: Self.width, height: Henge.Hit.control)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Henge.stone)
        .accessibilityLabel(Text("paywall.pill.label", bundle: .module))
        .accessibilityValue(Text("paywall.pill.value \(store.clock.formattedRemaining)",
                                 bundle: .module))
        .accessibilityHint(Text("paywall.pill.hint", bundle: .module))
    }
}
