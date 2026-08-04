import Foundation
import StoreKit

/// The app's one conversation with the App Store, and the owner of the
/// session clock.
///
/// Deliberately thin: every rule about what is allowed lives in `Access`,
/// which is a value type a test can construct by hand. What is left here is
/// the part that genuinely needs Apple on the other end — asking what has
/// been bought, buying it, and restoring it.
///
/// On a `directDownload` build this class does nothing at all. `start()`
/// returns immediately, no StoreKit call is ever made, and the entitlement
/// is `.full` from initialisation, so the Mac disk image never so much as
/// looks for a receipt it could not have.
@MainActor
@Observable
public final class PurchaseController {

    public let policy: StorePolicy

    public private(set) var entitlement: Entitlement
    public private(set) var clock = TrialClock()
    public private(set) var product: Product?
    public private(set) var isPurchasing = false

    /// Set when a purchase or restore failed in a way worth telling the user
    /// about. Cancelling is not a failure and never sets this.
    public private(set) var failure: String?

    private var updateListener: Task<Void, Never>?

    public init(policy: StorePolicy) {
        self.policy = policy
        // A build that sells nothing is whole from the first frame; there is
        // no state in which the Mac app is waiting to find out.
        self.entitlement = policy.isPaywalled ? .trial : .full
    }

    /// The current verdict, for every gate in the UI to read.
    public var access: Access {
        Access(policy: policy, entitlement: entitlement, clock: clock)
    }

    /// The price to put on the button. Localised by StoreKit for the user's
    /// storefront once the product has loaded.
    public var displayPrice: String {
        product?.displayPrice ?? StoreProducts.fallbackPrice
    }

    /// Spend session time. Called from the same clock that drives the
    /// time-lapse, so the countdown and the sky advance off one measurement.
    public func advance(byRealSeconds seconds: TimeInterval) {
        guard policy.isPaywalled, entitlement == .trial else { return }
        clock.advance(by: seconds)
    }

    public func dismissFailure() {
        failure = nil
    }

    // ── the store ───────────────────────────────────────────────────────────

    /// Ask what is owned, load the product, and keep listening.
    ///
    /// The listener matters as much as the initial check: a purchase made on
    /// another device, or an "Ask to Buy" approval that arrives an hour late,
    /// reaches the app through `Transaction.updates` and nowhere else.
    /// Test support: begin the session part-spent.
    ///
    /// The paywall has two states and one of them is fifteen minutes away,
    /// which is not a thing a UI test — or a person checking a screenshot —
    /// can afford to wait for. Same environment channel as the rebuild-card
    /// fixture in `RootView`, and inert in exactly the same way: nothing
    /// happens unless a harness asks for it by name.
    public func applyTestFixture(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        guard let raw = environment["HENGE_UITEST_TRIAL_CONSUMED"],
              let consumed = TimeInterval(raw) else { return }
        clock = TrialClock(consumed: consumed)
    }

    public func start() async {
        applyTestFixture()
        guard policy.isPaywalled else { return }

        updateListener?.cancel()
        updateListener = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.redeem(update)
            }
        }

        await refreshEntitlement()
        await loadProduct()
    }

    public func stop() {
        updateListener?.cancel()
        updateListener = nil
    }

    public func purchase() async {
        guard policy.isPaywalled, !isPurchasing else { return }

        // The product may not have loaded yet — a cold launch straight onto
        // the paywall, or a first attempt that failed on a dead network.
        if product == nil { await loadProduct() }
        guard let product else {
            failure = String(localized: "store.error.unavailable",
                             defaultValue: "The store is not answering. Check the connection and try again.",
                             bundle: .module)
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await redeem(verification)
            case .userCancelled:
                // Not a failure. Saying so would be scolding.
                break
            case .pending:
                failure = String(localized: "store.error.pending",
                                 defaultValue: "The purchase needs approval before it can finish. It will unlock here as soon as it does.",
                                 bundle: .module)
            @unknown default:
                break
            }
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Restore a purchase made on another device or before a reinstall.
    ///
    /// `AppStore.sync()` prompts for the Apple Account password, so it is
    /// only ever reached from a button the user pressed on purpose.
    public func restore() async {
        guard policy.isPaywalled, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if entitlement == .trial {
                failure = String(localized: "store.error.nothingToRestore",
                                 defaultValue: "No previous purchase found for this Apple Account.",
                                 bundle: .module)
            }
        } catch {
            failure = error.localizedDescription
        }
    }

    // ── plumbing ────────────────────────────────────────────────────────────

    private func loadProduct() async {
        do {
            product = try await Product
                .products(for: StoreProducts.all)
                .first { $0.id == StoreProducts.fullVersion }
        } catch {
            // Not surfaced: a product that will not load is only a problem
            // once someone tries to buy it, and `purchase()` says so then.
            product = nil
        }
    }

    private func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            await redeem(result, finishing: false)
        }
    }

    /// Accept a transaction if it is genuinely ours, genuinely verified, and
    /// has not been refunded.
    ///
    /// `.unverified` is dropped on the floor rather than trusted: it is the
    /// one case where StoreKit is telling us the signature did not check out.
    private func redeem(_ result: VerificationResult<Transaction>,
                        finishing: Bool = true) async {
        guard case .verified(let transaction) = result else { return }
        guard transaction.productID == StoreProducts.fullVersion else { return }

        if transaction.revocationDate == nil {
            entitlement = .full
        } else {
            // Refunded. The monument stays, the calendar closes.
            entitlement = .trial
        }

        if finishing {
            await transaction.finish()
        }
    }
}
