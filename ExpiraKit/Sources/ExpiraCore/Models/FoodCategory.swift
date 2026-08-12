import Foundation

/// Les 16 catégories couvertes par EXPIRA.
///
/// La catégorie sert à trois choses, et à rien d'autre :
/// 1. estimer une durée de conservation,
/// 2. estimer une valeur en euros (bilan « argent économisé »),
/// 3. donner un repère visuel instantané (emoji) dans la liste.
///
/// On garde volontairement une liste courte : une taxonomie fine ne rendrait pas
/// l'utilisateur plus rapide, elle le ralentirait au moment de la saisie.
public enum FoodCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case poultry
    case meat
    case fish
    case dairy
    case cheese
    case eggs
    case vegetables
    case fruits
    case bakery
    case deli
    case leftovers
    case prepared
    case frozen
    case pantry
    case beverages
    case other

    public var displayName: String {
        switch self {
        case .poultry: return "Volaille"
        case .meat: return "Viande"
        case .fish: return "Poisson"
        case .dairy: return "Produits laitiers"
        case .cheese: return "Fromage"
        case .eggs: return "Œufs"
        case .vegetables: return "Légumes"
        case .fruits: return "Fruits"
        case .bakery: return "Boulangerie"
        case .deli: return "Charcuterie"
        case .leftovers: return "Restes"
        case .prepared: return "Plat préparé"
        case .frozen: return "Surgelé"
        case .pantry: return "Épicerie"
        case .beverages: return "Boissons"
        case .other: return "Autre"
        }
    }

    public var emoji: String {
        switch self {
        case .poultry: return "🍗"
        case .meat: return "🥩"
        case .fish: return "🐟"
        case .dairy: return "🥛"
        case .cheese: return "🧀"
        case .eggs: return "🥚"
        case .vegetables: return "🥬"
        case .fruits: return "🍎"
        case .bakery: return "🥖"
        case .deli: return "🥓"
        case .leftovers: return "🍲"
        case .prepared: return "🍱"
        case .frozen: return "🧊"
        case .pantry: return "🥫"
        case .beverages: return "🧃"
        case .other: return "🛒"
        }
    }

    /// Ordre d'affichage dans la grille de sélection : les catégories les plus
    /// périssables — donc les plus souvent saisies — d'abord.
    public static var selectionOrder: [FoodCategory] {
        [
            .vegetables, .fruits, .dairy, .cheese, .poultry, .meat, .fish, .eggs,
            .bakery, .deli, .leftovers, .prepared, .frozen, .pantry, .beverages, .other,
        ]
    }
}
