import Foundation
import Observation
import ExpiraCore

/// Préférences locales de l'utilisateur.
///
/// Stockées dans `UserDefaults` : ce sont des réglages, pas des données. Aucune
/// n'est envoyée où que ce soit.
@MainActor
@Observable
public final class UserPreferences {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.wasteBaselineEUR = defaults.object(forKey: Keys.wasteBaselineEUR) as? Double
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.digestHour = defaults.object(forKey: Keys.digestHour) as? Int ?? 9
        self.alertThresholdDays = defaults.object(forKey: Keys.alertThresholdDays) as? Int ?? 2
        self.weeklySummaryEnabled = defaults.object(forKey: Keys.weeklySummaryEnabled) as? Bool ?? true
        self.analyticsEnabled = defaults.object(forKey: Keys.analyticsEnabled) as? Bool ?? true
        self.rescuePlansUsed = defaults.integer(forKey: Keys.rescuePlansUsed)
        if let stored = defaults.object(forKey: Keys.firstUseDate) as? Date {
            self.firstUseDate = stored
        } else {
            let now = Date()
            defaults.set(now, forKey: Keys.firstUseDate)
            self.firstUseDate = now
        }
    }

    // MARK: - Valeurs

    public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    /// Estimation déclarée à l'onboarding (« combien jetez-vous par mois ? »).
    /// Sert à contextualiser les économies, jamais à les remplacer.
    public var wasteBaselineEUR: Double? {
        didSet { defaults.set(wasteBaselineEUR, forKey: Keys.wasteBaselineEUR) }
    }

    public var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    public var digestHour: Int {
        didSet { defaults.set(digestHour, forKey: Keys.digestHour) }
    }

    public var alertThresholdDays: Int {
        didSet { defaults.set(alertThresholdDays, forKey: Keys.alertThresholdDays) }
    }

    public var weeklySummaryEnabled: Bool {
        didSet { defaults.set(weeklySummaryEnabled, forKey: Keys.weeklySummaryEnabled) }
    }

    /// Mesure d'audience anonyme. Désactivable, et respectée immédiatement.
    public var analyticsEnabled: Bool {
        didSet { defaults.set(analyticsEnabled, forKey: Keys.analyticsEnabled) }
    }

    public var rescuePlansUsed: Int {
        didSet { defaults.set(rescuePlansUsed, forKey: Keys.rescuePlansUsed) }
    }

    public private(set) var firstUseDate: Date

    // MARK: - Dérivés

    public var notificationPreferences: NotificationPreferences {
        NotificationPreferences(
            isEnabled: notificationsEnabled,
            digestHour: digestHour,
            alertThresholdDays: alertThresholdDays,
            weeklySummaryEnabled: weeklySummaryEnabled
        )
    }

    public func canGenerateRescuePlan(isPremium: Bool) -> Bool {
        isPremium || rescuePlansUsed < FreeTierLimits.freeRescuePlans
    }

    public func resetAll() {
        for key in Keys.all {
            defaults.removeObject(forKey: key)
        }
        hasCompletedOnboarding = false
        wasteBaselineEUR = nil
        notificationsEnabled = true
        digestHour = 9
        alertThresholdDays = 2
        weeklySummaryEnabled = true
        analyticsEnabled = true
        rescuePlansUsed = 0
        firstUseDate = Date()
        defaults.set(firstUseDate, forKey: Keys.firstUseDate)
    }

    /// Exposée pour que les services non isolés au `MainActor` (le tracker
    /// analytique, par exemple) puissent lire le consentement sans passer par
    /// cette classe : `UserDefaults` est thread-safe, pas `@MainActor`.
    public static var analyticsEnabledKey: String { Keys.analyticsEnabled }

    private enum Keys {
        static let hasCompletedOnboarding = "expira.onboarding.completed"
        static let wasteBaselineEUR = "expira.waste.baseline"
        static let notificationsEnabled = "expira.notifications.enabled"
        static let digestHour = "expira.notifications.hour"
        static let alertThresholdDays = "expira.notifications.threshold"
        static let weeklySummaryEnabled = "expira.notifications.weekly"
        static let analyticsEnabled = "expira.analytics.enabled"
        static let rescuePlansUsed = "expira.rescue.used"
        static let firstUseDate = "expira.firstUse"

        static let all = [
            hasCompletedOnboarding, wasteBaselineEUR, notificationsEnabled, digestHour,
            alertThresholdDays, weeklySummaryEnabled, analyticsEnabled, rescuePlansUsed,
            firstUseDate,
        ]
    }
}
