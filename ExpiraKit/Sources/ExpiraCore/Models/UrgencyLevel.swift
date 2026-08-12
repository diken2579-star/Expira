import Foundation

/// Niveau d'urgence d'un aliment.
///
/// Accessibilité : l'urgence est portée par **trois** canaux redondants —
/// un texte (`label`), une icône (`systemImageName`) et une position dans la
/// hiérarchie visuelle. La couleur n'est qu'un quatrième canal, jamais le seul.
public enum UrgencyLevel: Int, Codable, CaseIterable, Sendable, Hashable, Comparable {
    case expired = 0
    case today = 1
    case tomorrow = 2
    case thisWeek = 3
    case later = 4

    public static func < (lhs: UrgencyLevel, rhs: UrgencyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Titre de section sur l'écran Frigo.
    public var sectionTitle: String {
        switch self {
        case .expired: return "Expiré"
        case .today: return "Aujourd'hui"
        case .tomorrow: return "Demain"
        case .thisWeek: return "Cette semaine"
        case .later: return "Plus tard"
        }
    }

    public var systemImageName: String {
        switch self {
        case .expired: return "xmark.octagon.fill"
        case .today: return "exclamationmark.triangle.fill"
        case .tomorrow: return "clock.fill"
        case .thisWeek: return "calendar"
        case .later: return "checkmark.circle"
        }
    }

    /// Ces trois niveaux déclenchent les notifications et la section « URGENT ».
    public var requiresAttention: Bool {
        self <= .tomorrow
    }

    /// Poids utilisé par les moteurs de recettes et de plan de sauvetage.
    public var weight: Double {
        switch self {
        case .expired: return 1.0
        case .today: return 1.0
        case .tomorrow: return 0.85
        case .thisWeek: return 0.5
        case .later: return 0.1
        }
    }

    public static func from(daysRemaining days: Int) -> UrgencyLevel {
        switch days {
        case ..<0: return .expired
        case 0: return .today
        case 1: return .tomorrow
        case 2...7: return .thisWeek
        default: return .later
        }
    }

    /// Libellé complet affiché sur le badge, ex. « Dans 3 jours ».
    public static func badgeLabel(daysRemaining days: Int) -> String {
        switch days {
        case ..<(-1):
            return "Périmé depuis \(-days) jours"
        case -1:
            return "Périmé depuis hier"
        case 0:
            return "Aujourd'hui"
        case 1:
            return "Demain"
        case 2...13:
            return "Dans \(days) jours"
        case 14...29:
            let weeks = days / 7
            return "Dans \(weeks) semaine\(weeks > 1 ? "s" : "")"
        default:
            let months = days / 30
            return "Dans \(months) mois"
        }
    }
}
