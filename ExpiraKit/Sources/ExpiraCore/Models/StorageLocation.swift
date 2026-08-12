import Foundation

/// Le lieu de conservation change radicalement la durée de vie d'un aliment.
/// C'est l'unique variable « manuelle » qui vaut la peine d'être demandée —
/// et encore, elle est pré-remplie par catégorie.
public enum StorageLocation: String, Codable, CaseIterable, Sendable, Hashable {
    case fridge
    case freezer
    case pantry
    case counter

    public var displayName: String {
        switch self {
        case .fridge: return "Frigo"
        case .freezer: return "Congélateur"
        case .pantry: return "Placard"
        case .counter: return "À l'air libre"
        }
    }

    public var systemImageName: String {
        switch self {
        case .fridge: return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet"
        case .counter: return "basket"
        }
    }
}

/// Unités volontairement limitées : au-delà, la saisie devient un formulaire.
public enum QuantityUnit: String, Codable, CaseIterable, Sendable, Hashable {
    case piece
    case gram
    case kilogram
    case milliliter
    case liter
    case pack

    public var shortName: String {
        switch self {
        case .piece: return "u"
        case .gram: return "g"
        case .kilogram: return "kg"
        case .milliliter: return "mL"
        case .liter: return "L"
        case .pack: return "paquet"
        }
    }

    public var displayName: String {
        switch self {
        case .piece: return "Unité"
        case .gram: return "Grammes"
        case .kilogram: return "Kilos"
        case .milliliter: return "Millilitres"
        case .liter: return "Litres"
        case .pack: return "Paquet"
        }
    }
}

/// D'où vient la date affichée. **Le champ le plus important du modèle.**
///
/// Il garantit qu'EXPIRA n'affiche jamais une estimation comme une certitude.
/// Toute vue qui affiche une date doit consulter cette valeur.
public enum ExpiryDateSource: String, Codable, CaseIterable, Sendable, Hashable {
    /// Date lue sur l'emballage (OCR). Prioritaire sur tout le reste.
    case label
    /// Date saisie ou corrigée par l'utilisateur.
    case user
    /// Date calculée par EXPIRA à partir de la catégorie et du stockage.
    case estimated

    public var isEstimated: Bool { self == .estimated }

    public var displayName: String {
        switch self {
        case .label: return "Date sur l'emballage"
        case .user: return "Date saisie"
        case .estimated: return "Date estimée"
        }
    }

    /// Suffixe court accolé au badge d'urgence dans la liste.
    public var shortSuffix: String? {
        self == .estimated ? "estimée" : nil
    }

    /// Priorité relative : une source plus fiable ne doit jamais être écrasée
    /// silencieusement par une source moins fiable.
    public var trustRank: Int {
        switch self {
        case .label: return 3
        case .user: return 2
        case .estimated: return 1
        }
    }
}

public enum ItemStatus: String, Codable, CaseIterable, Sendable, Hashable {
    case active
    case consumed
    case discarded
    /// Périmé depuis longtemps sans action de l'utilisateur : retiré de la liste
    /// pour ne pas polluer le stock, mais jamais compté comme « jeté » puisqu'on
    /// ne sait pas ce qui s'est réellement passé.
    case archived
}
