import Foundation

/// Trace immuable d'une sortie de stock.
///
/// Conservée même si l'aliment est supprimé : c'est la seule source de vérité du
/// bilan mensuel, de la série sans gaspillage et des économies estimées.
public struct HistoryEvent: Identifiable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable, Hashable {
        case consumed
        case discarded

        public var displayName: String {
            switch self {
            case .consumed: return "Consommé"
            case .discarded: return "Jeté"
            }
        }

        public var systemImageName: String {
            switch self {
            case .consumed: return "checkmark.circle.fill"
            case .discarded: return "trash.fill"
            }
        }
    }

    public let id: UUID
    public let itemID: UUID
    public let itemName: String
    public let category: FoodCategory
    public let kind: Kind
    public let date: Date
    public let estimatedValueEUR: Double
    /// Négatif si l'aliment était déjà périmé au moment de la sortie.
    public let daysBeforeExpiry: Int

    public init(
        id: UUID = UUID(),
        itemID: UUID,
        itemName: String,
        category: FoodCategory,
        kind: Kind,
        date: Date = Date(),
        estimatedValueEUR: Double,
        daysBeforeExpiry: Int
    ) {
        self.id = id
        self.itemID = itemID
        self.itemName = itemName
        self.category = category
        self.kind = kind
        self.date = date
        self.estimatedValueEUR = estimatedValueEUR
        self.daysBeforeExpiry = daysBeforeExpiry
    }

    public static func from(
        item: FoodItem,
        kind: Kind,
        at date: Date = Date(),
        calendar: Calendar = .expira
    ) -> HistoryEvent {
        HistoryEvent(
            itemID: item.id,
            itemName: item.displayName,
            category: item.category,
            kind: kind,
            date: date,
            estimatedValueEUR: item.estimatedValueEUR,
            daysBeforeExpiry: item.daysRemaining(asOf: date, calendar: calendar)
        )
    }
}
