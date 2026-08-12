import Foundation

public struct NotificationPreferences: Equatable, Sendable, Codable {
    public var isEnabled: Bool
    /// Heure du digest quotidien (0…23).
    public var digestHour: Int
    /// Prévenir quand un aliment expire dans N jours ou moins.
    public var alertThresholdDays: Int
    /// Résumé de la semaine, le dimanche soir.
    public var weeklySummaryEnabled: Bool

    public static let `default` = NotificationPreferences(
        isEnabled: true,
        digestHour: 9,
        alertThresholdDays: 2,
        weeklySummaryEnabled: true
    )

    public init(isEnabled: Bool, digestHour: Int, alertThresholdDays: Int, weeklySummaryEnabled: Bool) {
        self.isEnabled = isEnabled
        self.digestHour = min(max(digestHour, 0), 23)
        self.alertThresholdDays = min(max(alertThresholdDays, 0), 7)
        self.weeklySummaryEnabled = weeklySummaryEnabled
    }
}

public struct PlannedNotification: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable, Hashable {
        case dailyDigest
        case weeklySummary
    }

    public let id: String
    public let kind: Kind
    public let fireDate: Date
    public let title: String
    public let body: String
    /// Identifiants des aliments concernés — permet aux actions rapides de la
    /// notification (« Consommé ») de savoir sur quoi agir.
    public let itemIDs: [UUID]

    public init(id: String, kind: Kind, fireDate: Date, title: String, body: String, itemIDs: [UUID]) {
        self.id = id
        self.kind = kind
        self.fireDate = fireDate
        self.title = title
        self.body = body
        self.itemIDs = itemIDs
    }
}

/// Décide **quoi** notifier et **quand**, sans rien connaître d'UserNotifications.
///
/// Les dates de péremption sont connues à l'avance : on peut donc calculer
/// aujourd'hui le contenu exact des 7 prochains digests. C'est ce qui permet à
/// EXPIRA de fonctionner avec des notifications 100 % locales — sans serveur,
/// sans jeton, sans réseau.
///
/// Trois règles, non négociables :
/// 1. **Une notification par jour maximum** (plus le résumé du dimanche).
/// 2. **Jamais de notification vide** : rien à signaler = rien d'envoyé.
/// 3. **Toujours actionnable** : on nomme les aliments et on propose une suite.
public struct NotificationPlanner: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .expira) {
        self.calendar = calendar
    }

    public func plan(
        items: [FoodItem],
        preferences: NotificationPreferences,
        asOf now: Date = Date(),
        horizonDays: Int = 7
    ) -> [PlannedNotification] {
        guard preferences.isEnabled else { return [] }
        let activeItems = items.active
        guard !activeItems.isEmpty else { return [] }

        var planned: [PlannedNotification] = []

        for offset in 0..<horizonDays {
            let day = calendar.adding(days: offset, to: now)
            let fireDate = calendar.date(calendar.startOfDay(for: day), atHour: preferences.digestHour)
            // On ne planifie jamais dans le passé : le digest du jour est ignoré
            // si l'heure est déjà passée.
            guard fireDate > now else { continue }

            if let digest = makeDigest(
                items: activeItems,
                preferences: preferences,
                fireDate: fireDate
            ) {
                planned.append(digest)
            }

            // Le résumé du dimanche est décalé en soirée pour ne jamais tomber
            // à la même minute que le digest du jour.
            if preferences.weeklySummaryEnabled,
               calendar.component(.weekday, from: fireDate) == 1 { // dimanche
                let summaryHour = preferences.digestHour == 18 ? 19 : 18
                let summaryDate = calendar.date(calendar.startOfDay(for: day), atHour: summaryHour)
                if summaryDate > now,
                   let summary = makeWeeklySummary(items: activeItems, fireDate: summaryDate) {
                    planned.append(summary)
                }
            }
        }

        return planned
    }

    // MARK: - Digest quotidien

    private func makeDigest(
        items: [FoodItem],
        preferences: NotificationPreferences,
        fireDate: Date
    ) -> PlannedNotification? {
        let threshold = preferences.alertThresholdDays
        let relevant = items
            .filter { item in
                let days = calendar.wholeDaysBetween(fireDate, and: item.expiryDate)
                // On ignore le passé lointain : un aliment périmé depuis une
                // semaine relève du nettoyage, pas de l'alerte.
                return days >= -2 && days <= threshold
            }
            .sortedByUrgency(asOf: fireDate, calendar: calendar)

        guard !relevant.isEmpty else { return nil }

        let (title, body) = digestCopy(for: relevant, asOf: fireDate)
        let dayKey = Self.dayKey(fireDate, calendar: calendar)

        return PlannedNotification(
            id: "digest-\(dayKey)",
            kind: .dailyDigest,
            fireDate: fireDate,
            title: title,
            body: body,
            itemIDs: relevant.map(\.id)
        )
    }

    /// Rédaction : concrète, nommée, jamais culpabilisante.
    private func digestCopy(for items: [FoodItem], asOf date: Date) -> (String, String) {
        let expiringToday = items.filter { $0.urgency(asOf: date, calendar: calendar) <= .today }

        if items.count == 1, let item = items.first {
            let days = item.daysRemaining(asOf: date, calendar: calendar)
            switch days {
            case ..<0:
                return (
                    "\(item.category.emoji) \(item.displayName)",
                    "C'était à consommer il y a \(-days) jour\(-days > 1 ? "s" : ""). Toujours dans le frigo ?"
                )
            case 0:
                return (
                    "\(item.category.emoji) \(item.displayName)",
                    "À consommer aujourd'hui. Envie d'une idée de recette ?"
                )
            default:
                return (
                    "\(item.category.emoji) \(item.displayName)",
                    "À consommer \(days == 1 ? "demain" : "dans \(days) jours"). On vous propose une recette ?"
                )
            }
        }

        if expiringToday.count >= 2 {
            let names = expiringToday.prefix(2).map(\.displayName).joined(separator: " et ")
            return (
                "⚠️ \(expiringToday.count) aliments à consommer aujourd'hui",
                "\(names)\(expiringToday.count > 2 ? "…" : ""). Voir un plan pour les sauver ?"
            )
        }

        let names = items.prefix(3).map { "\($0.category.emoji) \($0.displayName)" }.joined(separator: ", ")
        return (
            "🍳 \(items.count) aliments à utiliser bientôt",
            "\(names)\(items.count > 3 ? "…" : "")"
        )
    }

    // MARK: - Résumé hebdomadaire

    private func makeWeeklySummary(items: [FoodItem], fireDate: Date) -> PlannedNotification? {
        let upcoming = items.filter { item in
            let days = calendar.wholeDaysBetween(fireDate, and: item.expiryDate)
            return days >= 0 && days <= 7
        }
        guard upcoming.count >= 2 else { return nil }

        let dayKey = Self.dayKey(fireDate, calendar: calendar)
        return PlannedNotification(
            id: "weekly-\(dayKey)",
            kind: .weeklySummary,
            fireDate: fireDate,
            title: "🗓️ Votre semaine",
            body: "\(upcoming.count) aliments à utiliser d'ici dimanche prochain. On vous fait un plan ?",
            itemIDs: upcoming.map(\.id)
        )
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
