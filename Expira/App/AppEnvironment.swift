import Foundation
import Observation
import SwiftData
import ExpiraCore
import ExpiraCatalog
import ExpiraData
import ExpiraCommerce
import ExpiraAnalytics
import ExpiraNotifications

/// Racine de composition de l'application.
///
/// Tout est instancié ici, une seule fois, et injecté dans les vues via
/// l'environnement SwiftUI. Aucun singleton, aucune dépendance cachée : on peut
/// remplacer n'importe quel service (par une doublure de test, un aperçu, une
/// future implémentation serveur) sans toucher à un écran.
@MainActor
@Observable
public final class AppEnvironment {
    // Données
    public let fridge: FridgeStore
    public let preferences: UserPreferences

    // Services
    public let subscriptions: SubscriptionService
    public let notifications: NotificationService
    public let productLookup: CachedProductLookupService
    public let analytics: AnalyticsTracking

    // Moteurs (fonctions pures)
    public let estimator: ExpiryEstimator
    public let matcher: RecipeMatcher
    public let rescuePlanner: RescuePlanner
    public let insights: InsightsEngine
    public let dateParser: ExpiryDateParser

    /// `true` si la base locale n'a pas pu être ouverte : l'app fonctionne mais
    /// les données ne survivront pas à la fermeture. On le dit à l'utilisateur.
    public let isUsingTemporaryStorage: Bool

    /// Paywall présenté globalement : n'importe quel écran peut le déclencher
    /// sans avoir à connaître sa présentation.
    public var paywallTrigger: PaywallTrigger?

    /// Destination demandée depuis l'extérieur de l'app (action de notification).
    public enum DeepLink: Equatable, Sendable {
        case fridge
        case recipes
    }

    public var pendingDeepLink: DeepLink?

    private let container: ModelContainer
    private let funnelTracker: LocalFunnelTracker

    public init(inMemory: Bool = false) {
        let containerResult = ExpiraModelContainer.make(inMemory: inMemory)
        self.container = containerResult.container
        self.isUsingTemporaryStorage = containerResult.isFallback && !inMemory

        let preferences = UserPreferences()
        self.preferences = preferences
        self.fridge = FridgeStore(context: ModelContext(containerResult.container))

        // Le tracker relit le consentement à chaque événement, directement dans
        // `UserDefaults` : couper la mesure d'audience dans les réglages prend
        // effet immédiatement, et la lecture reste sûre depuis n'importe quel fil.
        let defaults = UserDefaults.standard
        let consentKey = UserPreferences.analyticsEnabledKey
        let tracker = LocalFunnelTracker(isEnabled: {
            defaults.object(forKey: consentKey) as? Bool ?? true
        })
        self.funnelTracker = tracker
        let analytics = CompositeAnalyticsTracker([tracker, ConsoleAnalyticsTracker()])
        self.analytics = analytics

        self.subscriptions = SubscriptionService(analytics: analytics)
        self.notifications = NotificationService()
        self.productLookup = CachedProductLookupService()

        let shelfLife = ShelfLifeCatalog()
        self.estimator = ExpiryEstimator(provider: shelfLife)
        self.matcher = RecipeMatcher()
        self.rescuePlanner = RescuePlanner()
        self.insights = InsightsEngine()
        self.dateParser = ExpiryDateParser()
    }

    // MARK: - Cycle de vie

    /// Appelé une fois au lancement, puis à chaque retour au premier plan.
    public func onLaunch() {
        subscriptions.start()
        funnelTracker.trackRetentionMilestones()
        analytics.track(.appInstalled)

        // Entretien du stock : les périmés oubliés quittent la liste pour qu'elle
        // reste crédible. Sans cela, l'utilisateur cesse d'y croire, puis part.
        fridge.archiveStaleItems()

        Task { await refreshNotifications() }
    }

    public func onEnterForeground() {
        fridge.reload()
        fridge.archiveStaleItems()
        Task {
            await notifications.clearBadge()
            await refreshNotifications()
        }
    }

    /// Reprogramme les notifications à partir de l'état réel du stock.
    /// Appelée après **chaque** modification : une notification ne peut donc
    /// jamais parler d'un aliment déjà consommé.
    public func refreshNotifications() async {
        let count = await notifications.refreshSchedule(
            items: fridge.activeItems,
            preferences: preferences.notificationPreferences
        )
        if count > 0 {
            analytics.track(.notificationScheduled(type: "digest", count: count))
        }
    }

    // MARK: - Droits d'accès

    public var isPremium: Bool { subscriptions.isPremium }

    /// Vérifie un droit et, s'il manque, ouvre le paywall au bon endroit.
    /// Renvoie `true` quand l'action peut se poursuivre.
    @discardableResult
    public func requirePremium(for trigger: PaywallTrigger) -> Bool {
        guard !isPremium else { return true }
        presentPaywall(trigger)
        return false
    }

    public func presentPaywall(_ trigger: PaywallTrigger) {
        paywallTrigger = trigger
        analytics.track(.paywallShown(trigger: trigger))
    }

    public func canAddItem() -> Bool {
        fridge.canAddItem(isPremium: isPremium)
    }

    // MARK: - Journal analytique local (affiché dans les réglages)

    public func analyticsLog() -> [String] {
        funnelTracker.exportLog()
    }

    public func clearAnalyticsLog() {
        funnelTracker.clearLog()
    }
}
