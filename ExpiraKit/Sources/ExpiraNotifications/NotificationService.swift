import Foundation
import UserNotifications
import ExpiraCore

/// Planification des notifications locales.
///
/// EXPIRA n'utilise **aucune** notification distante : les dates de péremption
/// sont connues à l'avance, donc les 7 prochains digests peuvent être calculés
/// et programmés localement. Pas de serveur, pas de jeton, pas de donnée envoyée,
/// et ça marche en avion.
public actor NotificationService {
    public enum Authorization: Equatable, Sendable {
        case authorized
        case denied
        case notDetermined
    }

    /// Identifiant de catégorie portant les actions rapides.
    public static let digestCategoryID = "expira.digest"
    public static let actionMarkConsumed = "expira.action.consumed"
    public static let actionShowRecipes = "expira.action.recipes"

    private let center: UNUserNotificationCenter
    private let planner: NotificationPlanner

    public init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .expira) {
        self.center = center
        self.planner = NotificationPlanner(calendar: calendar)
    }

    // MARK: - Autorisation

    public func authorizationStatus() async -> Authorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    /// Demande l'autorisation. L'écran d'explication qui précède ce prompt fait
    /// plus pour le taux d'acceptation que n'importe quel réglage technique.
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted { registerCategories() }
            return granted
        } catch {
            return false
        }
    }

    public func registerCategories() {
        let consumed = UNNotificationAction(
            identifier: Self.actionMarkConsumed,
            title: "C'est consommé",
            options: []
        )
        let recipes = UNNotificationAction(
            identifier: Self.actionShowRecipes,
            title: "Voir une recette",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.digestCategoryID,
            actions: [consumed, recipes],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Planification

    /// Remplace intégralement la programmation existante.
    ///
    /// Appelée au lancement et après chaque modification du stock : la
    /// programmation reflète donc toujours l'état réel du frigo, sans historique
    /// obsolète qui déclencherait une notification fausse.
    @discardableResult
    public func refreshSchedule(
        items: [FoodItem],
        preferences: NotificationPreferences,
        asOf date: Date = Date()
    ) async -> Int {
        center.removeAllPendingNotificationRequests()
        guard preferences.isEnabled else { return 0 }
        guard await authorizationStatus() == .authorized else { return 0 }

        let planned = planner.plan(items: items, preferences: preferences, asOf: date)
        var scheduled = 0

        for notification in planned {
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default
            content.categoryIdentifier = Self.digestCategoryID
            content.userInfo = [
                "kind": notification.kind.rawValue,
                "itemIDs": notification.itemIDs.map(\.uuidString),
            ]
            // Un badge égal au nombre d'aliments urgents : informatif, jamais
            // un compteur artificiel destiné à faire rouvrir l'app.
            content.badge = NSNumber(value: notification.itemIDs.count)

            let components = Calendar.expira.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notification.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: notification.id,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                continue
            }
        }
        return scheduled
    }

    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    public func clearBadge() async {
        try? await center.setBadgeCount(0)
    }
}
