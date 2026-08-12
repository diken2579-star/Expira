import Foundation

/// Événement analytique **anonyme**.
///
/// Contrainte absolue : aucun identifiant personnel, aucun nom d'aliment, aucune
/// donnée exploitable pour profiler quelqu'un. Ce qu'on mesure, c'est l'entonnoir,
/// pas les gens.
public struct AnalyticsEvent: Equatable, Hashable, Sendable {
    public let name: String
    public let parameters: [String: String]

    public init(name: String, parameters: [String: String] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}

public extension AnalyticsEvent {
    // MARK: Onboarding
    static let appInstalled = AnalyticsEvent(name: "app_installed")
    static let onboardingStarted = AnalyticsEvent(name: "onboarding_started")
    static func onboardingStepCompleted(_ step: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "onboarding_step_completed", parameters: ["step": String(step)])
    }
    static func wasteBaselineSelected(_ bucket: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "waste_baseline_selected", parameters: ["bucket": bucket])
    }
    static let onboardingCompleted = AnalyticsEvent(name: "onboarding_completed")

    // MARK: Permissions
    static func notificationPermission(granted: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "notification_permission", parameters: ["granted": String(granted)])
    }
    static func cameraPermission(granted: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "camera_permission", parameters: ["granted": String(granted)])
    }

    // MARK: Ajout d'aliments
    static func firstItemAdded(method: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "first_item_added", parameters: ["method": method])
    }
    static func itemAdded(method: String, expirySource: ExpiryDateSource) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "item_added",
            parameters: ["method": method, "expiry_source": expirySource.rawValue]
        )
    }
    static func itemResolved(kind: HistoryEvent.Kind, daysBeforeExpiry: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "item_resolved",
            parameters: ["kind": kind.rawValue, "days_before_expiry": String(daysBeforeExpiry)]
        )
    }

    // MARK: Scan
    static func scanStarted(type: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "scan_started", parameters: ["type": type])
    }
    static func scanSucceeded(type: String, durationMS: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "scan_succeeded",
            parameters: ["type": type, "duration_ms": String(durationMS)]
        )
    }
    static func scanFailed(type: String, reason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "scan_failed", parameters: ["type": type, "reason": reason])
    }
    static func productLookup(found: Bool, cached: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "product_lookup",
            parameters: ["found": String(found), "cached": String(cached)]
        )
    }
    static func dateOCR(result: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "date_ocr", parameters: ["result": result])
    }

    // MARK: Notifications
    static func notificationScheduled(type: String, count: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "notification_scheduled",
            parameters: ["type": type, "count": String(count)]
        )
    }
    static func notificationOpened(type: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "notification_opened", parameters: ["type": type])
    }

    // MARK: Recettes & sauvetage
    static let recipeListViewed = AnalyticsEvent(name: "recipe_list_viewed")
    static func recipeOpened(id: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "recipe_opened", parameters: ["recipe_id": id])
    }
    static func recipeCooked(id: String, itemsSaved: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "recipe_cooked",
            parameters: ["recipe_id": id, "items_saved": String(itemsSaved)]
        )
    }
    static func rescuePlanGenerated(itemsAtRisk: Int, daysPlanned: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "rescue_plan_generated",
            parameters: ["items_at_risk": String(itemsAtRisk), "days_planned": String(daysPlanned)]
        )
    }

    // MARK: Monétisation
    static func paywallShown(trigger: PaywallTrigger) -> AnalyticsEvent {
        AnalyticsEvent(name: "paywall_shown", parameters: ["trigger": trigger.rawValue])
    }
    static func paywallDismissed(trigger: PaywallTrigger, seconds: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "paywall_dismissed",
            parameters: ["trigger": trigger.rawValue, "seconds": String(seconds)]
        )
    }
    static func subscriptionStarted(productID: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "subscription_started", parameters: ["product_id": productID])
    }
    static func subscriptionCancelled(productID: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "subscription_cancelled", parameters: ["product_id": productID])
    }
    static func purchaseFailed(reason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "purchase_failed", parameters: ["reason": reason])
    }

    // MARK: Rétention
    static func dayActive(_ day: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "day\(day)_active")
    }
}

/// Contrat de tracking. Une seule implémentation réelle en V1 (locale), mais le
/// protocole permet de brancher un fournisseur plus tard sans toucher aux écrans.
public protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent)
}

/// Doublure neutre — utilisée dans les aperçus SwiftUI et quand l'utilisateur a
/// désactivé la mesure d'audience dans les réglages.
public struct NoopAnalyticsTracker: AnalyticsTracking {
    public init() {}
    public func track(_ event: AnalyticsEvent) {}
}
