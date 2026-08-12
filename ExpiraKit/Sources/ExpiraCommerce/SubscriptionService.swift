import Foundation
import Observation
import StoreKit
import ExpiraCore

/// Identifiants des abonnements EXPIRA Premium.
///
/// Un seul groupe d'abonnement : l'utilisateur peut passer du mensuel à l'annuel
/// sans rien perdre, et Apple gère la proration.
public enum ExpiraProduct {
    public static let monthly = "app.expira.premium.monthly"
    public static let annual = "app.expira.premium.annual"
    public static let all = [annual, monthly]
}

/// État de l'abonnement et achats.
///
/// Le droit d'accès est mis en cache localement : si l'App Store est injoignable
/// au lancement, un abonné reste un abonné. On ne coupe jamais l'accès à
/// quelqu'un qui a payé parce que le réseau est mauvais.
@MainActor
@Observable
public final class SubscriptionService {
    public enum PurchaseOutcome: Equatable, Sendable {
        case purchased
        case cancelled
        case pending
        case failed(String)
    }

    public private(set) var products: [Product] = []
    public private(set) var isPremium: Bool
    public private(set) var isLoadingProducts = false
    public private(set) var activeProductID: String?
    /// Renseigné quand le catalogue n'a pas pu être chargé : le paywall affiche
    /// alors un message honnête plutôt qu'un écran vide.
    public private(set) var loadError: String?

    private let defaults: UserDefaults
    private let entitlementKey = "expira.premium.cached"
    private let activeProductKey = "expira.premium.product"
    private var updatesTask: Task<Void, Never>?
    private let analytics: AnalyticsTracking

    public init(defaults: UserDefaults = .standard, analytics: AnalyticsTracking = NoopAnalyticsTracker()) {
        self.defaults = defaults
        self.analytics = analytics
        self.isPremium = defaults.bool(forKey: entitlementKey)
        self.activeProductID = defaults.string(forKey: activeProductKey)
    }

    // MARK: - Cycle de vie

    /// À appeler une fois au lancement.
    public func start() {
        listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    public func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: ExpiraProduct.all)
            // L'annuel d'abord : c'est l'offre mise en avant.
            products = loaded.sorted { lhs, rhs in
                Self.displayRank(lhs.id) < Self.displayRank(rhs.id)
            }
            loadError = loaded.isEmpty ? "Les offres ne sont pas disponibles pour le moment." : nil
        } catch {
            products = []
            loadError = "Impossible de charger les offres. Vérifiez votre connexion."
        }
    }

    public func refreshEntitlements() async {
        var entitled = false
        var productID: String?
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard ExpiraProduct.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                entitled = true
                productID = transaction.productID
            }
        }
        applyEntitlement(entitled, productID: productID)
    }

    // MARK: - Achat

    public func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    analytics.track(.purchaseFailed(reason: "unverified"))
                    return .failed("La transaction n'a pas pu être vérifiée.")
                }
                await transaction.finish()
                applyEntitlement(true, productID: transaction.productID)
                analytics.track(.subscriptionStarted(productID: transaction.productID))
                return .purchased
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Achat impossible pour le moment.")
            }
        } catch {
            analytics.track(.purchaseFailed(reason: "store_error"))
            return .failed("L'achat n'a pas pu aboutir. Réessayez dans un instant.")
        }
    }

    /// Restauration explicite — toujours visible sur le paywall, exigée par Apple
    /// et de toute façon indispensable à un utilisateur qui change de téléphone.
    public func restorePurchases() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlements()
        return isPremium
    }

    // MARK: - Présentation

    public var annualProduct: Product? {
        products.first { $0.id == ExpiraProduct.annual }
    }

    public var monthlyProduct: Product? {
        products.first { $0.id == ExpiraProduct.monthly }
    }

    /// Économie de l'annuel par rapport à 12 mensualités, en pourcentage entier.
    /// Calculée à partir des prix réels de l'App Store : jamais codée en dur, et
    /// jamais affichée si elle n'est pas positive.
    public var annualSavingsPercent: Int? {
        guard let annual = annualProduct, let monthly = monthlyProduct else { return nil }
        let yearlyIfMonthly = monthly.price * Decimal(12)
        guard yearlyIfMonthly > 0, annual.price < yearlyIfMonthly else { return nil }
        let ratio = (yearlyIfMonthly - annual.price) / yearlyIfMonthly
        let percent = Int((ratio as NSDecimalNumber).doubleValue * 100)
        return percent > 0 ? percent : nil
    }

    private static func displayRank(_ productID: String) -> Int {
        productID == ExpiraProduct.annual ? 0 : 1
    }

    /// Prix mensuel équivalent de l'offre annuelle, pour que la comparaison soit
    /// honnête et immédiate.
    public func monthlyEquivalent(for product: Product) -> String? {
        guard product.id == ExpiraProduct.annual else { return nil }
        let perMonth = product.price / Decimal(12)
        return product.priceFormatStyle.format(perMonth)
    }

    public func introductoryOfferDescription(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer else { return nil }
        let period = offer.period
        let unit: String
        switch period.unit {
        case .day: unit = period.value > 1 ? "jours" : "jour"
        case .week: unit = period.value > 1 ? "semaines" : "semaine"
        case .month: unit = period.value > 1 ? "mois" : "mois"
        case .year: unit = period.value > 1 ? "ans" : "an"
        @unknown default: return nil
        }
        guard offer.paymentMode == .freeTrial else { return nil }
        return "\(period.value) \(unit) offerts"
    }

    // MARK: - Interne

    private func listenForTransactions() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    private func applyEntitlement(_ entitled: Bool, productID: String?) {
        let wasPremium = isPremium
        let previousProductID = activeProductID

        isPremium = entitled
        activeProductID = productID
        defaults.set(entitled, forKey: entitlementKey)
        defaults.set(productID, forKey: activeProductKey)

        if wasPremium, !entitled {
            analytics.track(.subscriptionCancelled(productID: previousProductID ?? "unknown"))
        }
    }
}
