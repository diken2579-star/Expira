import Foundation
import ExpiraCore

/// Table des durées de conservation embarquée dans l'app.
///
/// Codée en Swift plutôt que chargée depuis un JSON : la table est vérifiée à la
/// compilation, ne peut pas échouer au démarrage et n'impose aucune gestion de
/// ressources de bundle. C'est un fichier de données, pas un fichier de code —
/// il se relit et se modifie aussi facilement qu'un tableau.
///
/// ⚠️ Ces valeurs sont des **repères de conservation domestique**, pas des règles
/// sanitaires. EXPIRA les présente toujours comme des estimations et une date
/// lue sur l'emballage les remplace systématiquement.
public struct ShelfLifeCatalog: ShelfLifeProviding {
    public init() {}

    public func rule(for category: FoodCategory, storage: StorageLocation) -> ShelfLifeRule {
        let entry = Self.table[category] ?? Self.fallback
        let value = entry[storage] ?? entry[.fridge] ?? (days: 7, opened: 4)
        return ShelfLifeRule(
            category: category,
            storage: storage,
            days: value.days,
            daysWhenOpened: value.opened
        )
    }

    public func defaultStorage(for category: FoodCategory) -> StorageLocation {
        switch category {
        case .bakery: return .counter
        case .frozen: return .freezer
        case .pantry, .beverages: return .pantry
        default: return .fridge
        }
    }

    public func averagePriceEUR(for category: FoodCategory) -> Double {
        Self.averagePrices[category] ?? 3.0
    }

    // MARK: - Données

    private typealias Durations = (days: Int, opened: Int)

    private static let fallback: [StorageLocation: Durations] = [
        .fridge: (7, 4), .freezer: (120, 60), .pantry: (60, 30), .counter: (5, 3),
    ]

    /// `(durée fermé, durée entamé)` en jours.
    private static let table: [FoodCategory: [StorageLocation: Durations]] = [
        .poultry: [.fridge: (2, 1), .freezer: (270, 60), .pantry: (1, 1), .counter: (1, 1)],
        .meat: [.fridge: (4, 2), .freezer: (300, 90), .pantry: (1, 1), .counter: (1, 1)],
        .fish: [.fridge: (1, 1), .freezer: (180, 60), .pantry: (1, 1), .counter: (1, 1)],
        .dairy: [.fridge: (10, 3), .freezer: (60, 30), .pantry: (90, 3), .counter: (2, 1)],
        .cheese: [.fridge: (21, 7), .freezer: (120, 60), .pantry: (7, 3), .counter: (3, 2)],
        .eggs: [.fridge: (28, 21), .freezer: (90, 90), .pantry: (21, 14), .counter: (14, 10)],
        .vegetables: [.fridge: (7, 4), .freezer: (240, 90), .pantry: (14, 7), .counter: (5, 3)],
        .fruits: [.fridge: (8, 5), .freezer: (240, 90), .pantry: (10, 6), .counter: (5, 3)],
        .bakery: [.fridge: (5, 3), .freezer: (60, 30), .pantry: (3, 2), .counter: (2, 2)],
        .deli: [.fridge: (5, 3), .freezer: (60, 30), .pantry: (30, 3), .counter: (1, 1)],
        .leftovers: [.fridge: (3, 2), .freezer: (60, 30), .pantry: (1, 1), .counter: (1, 1)],
        .prepared: [.fridge: (3, 2), .freezer: (90, 45), .pantry: (180, 2), .counter: (1, 1)],
        .frozen: [.fridge: (2, 1), .freezer: (180, 90), .pantry: (1, 1), .counter: (1, 1)],
        .pantry: [.fridge: (180, 14), .freezer: (365, 180), .pantry: (540, 60), .counter: (180, 30)],
        .beverages: [.fridge: (30, 5), .freezer: (120, 60), .pantry: (365, 5), .counter: (60, 3)],
        .other: [.fridge: (7, 4), .freezer: (120, 60), .pantry: (60, 30), .counter: (5, 3)],
    ]

    /// Prix moyens indicatifs pour une portion / un article courant, en euros.
    /// Servent **uniquement** à estimer les économies affichées — toujours
    /// présentées comme des estimations.
    private static let averagePrices: [FoodCategory: Double] = [
        .poultry: 6.5, .meat: 8.0, .fish: 7.5, .dairy: 2.0, .cheese: 4.0, .eggs: 3.0,
        .vegetables: 2.2, .fruits: 2.8, .bakery: 1.5, .deli: 3.5, .leftovers: 3.0,
        .prepared: 4.5, .frozen: 4.0, .pantry: 2.5, .beverages: 2.0, .other: 3.0,
    ]
}
