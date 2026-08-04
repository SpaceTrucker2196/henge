import Foundation

/// The catalogue, such as it is: one non-consumable, bought once, owned for
/// good. No subscription — the monument has stood for four and a half
/// thousand years without billing anyone monthly.
public enum StoreProducts {

    /// Must match the product identifier in App Store Connect exactly. A
    /// mismatch is silent: `Product.products(for:)` simply returns nothing
    /// and the paywall shows its fallback price forever.
    public static let fullVersion = "io.river.henge.full"

    public static let all: [String] = [fullVersion]

    /// Shown only when the store has not answered yet. The real price is
    /// always `Product.displayPrice`, which is localised and correct for the
    /// user's storefront — this is scaffolding for the first half-second and
    /// for the Mac build, never a claim about what anyone will be charged.
    public static let fallbackPrice = "$4.99"
}
