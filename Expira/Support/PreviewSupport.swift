#if DEBUG
import Foundation
import SwiftUI
import ExpiraCore
import ExpiraCatalog

/// Jeu de données de démonstration pour les aperçus Xcode.
///
/// Compilé uniquement en `DEBUG` : rien de tout cela n'atteint la version
/// distribuée. Les aliments couvrent délibérément **tous** les niveaux d'urgence
/// et les deux sources de date — c'est la seule façon de voir d'un coup d'œil si
/// la hiérarchie visuelle tient.
enum SampleData {
    static let calendar = Calendar.expira
    private static let estimator = ExpiryEstimator(provider: ShelfLifeCatalog())

    static func item(
        _ name: String,
        brand: String? = nil,
        category: FoodCategory,
        expiresIn days: Int,
        source: ExpiryDateSource = .estimated,
        quantity: Double = 1,
        unit: QuantityUnit = .piece,
        isOpened: Bool = false,
        storage: StorageLocation = .fridge,
        asOf reference: Date = Date()
    ) -> FoodItem {
        FoodItem(
            name: name,
            brand: brand,
            category: category,
            storage: storage,
            quantity: quantity,
            unit: unit,
            purchaseDate: calendar.adding(days: -3, to: reference),
            expiryDate: calendar.startOfDay(for: calendar.adding(days: days, to: reference)),
            expirySource: source,
            isOpened: isOpened,
            estimatedValueEUR: estimator.estimatedValueEUR(for: category, quantity: quantity, unit: unit)
        )
    }

    /// Un frigo réaliste : quelque chose de périmé, quelque chose d'urgent,
    /// et de quoi faire tourner le moteur de recettes.
    static var fridge: [FoodItem] {
        [
            item("Salade verte", brand: "Bio Village", category: .vegetables, expiresIn: -1),
            item("Blanc de poulet", brand: "Le Gaulois", category: .poultry, expiresIn: 0,
                 source: .label, quantity: 400, unit: .gram),
            item("Lait demi-écrémé", brand: "Lactel", category: .dairy, expiresIn: 1,
                 source: .label, quantity: 1, unit: .liter, isOpened: true),
            item("Courgettes", category: .vegetables, expiresIn: 3, quantity: 2),
            item("Crème fraîche épaisse", brand: "Elle & Vire", category: .dairy, expiresIn: 4, source: .label),
            item("Emmental râpé", brand: "Entremont", category: .cheese, expiresIn: 6, isOpened: true),
            item("Œufs plein air", category: .eggs, expiresIn: 21, source: .label, quantity: 6),
            item("Riz basmati", category: .pantry, expiresIn: 400, quantity: 500, unit: .gram, storage: .pantry),
            item("Lait de coco", brand: "Suzi Wan", category: .pantry, expiresIn: 430,
                 quantity: 400, unit: .milliliter, storage: .pantry),
        ]
    }

    /// Historique du mois : de quoi remplir la carte « Ce mois-ci » du profil.
    static var history: [HistoryEvent] {
        let now = Date()
        var events: [HistoryEvent] = []
        let consumed: [(String, FoodCategory, Int, Double)] = [
            ("Yaourts nature", .dairy, 1, 2.4), ("Carottes", .vegetables, 2, 1.8),
            ("Pain de campagne", .bakery, 3, 2.2), ("Steak haché", .meat, 4, 6.5),
            ("Pommes", .fruits, 5, 3.1), ("Poireaux", .vegetables, 7, 2.4),
            ("Saumon frais", .fish, 8, 8.0), ("Fromage blanc", .dairy, 9, 2.0),
            ("Tomates cerises", .vegetables, 11, 2.6), ("Jambon blanc", .deli, 12, 3.5),
            ("Bananes", .fruits, 13, 1.9), ("Courgettes", .vegetables, 15, 2.2),
        ]
        for (name, category, daysAgo, value) in consumed {
            events.append(
                HistoryEvent(
                    itemID: UUID(), itemName: name, category: category, kind: .consumed,
                    date: calendar.adding(days: -daysAgo, to: now),
                    estimatedValueEUR: value, daysBeforeExpiry: 1
                )
            )
        }
        // Deux échecs assumés : un bilan qui n'affiche que des réussites n'est
        // pas crédible, et l'écran doit savoir les présenter sans culpabiliser.
        for (name, daysAgo, value) in [("Salade", 6, 1.5), ("Crème fraîche", 14, 2.0)] {
            events.append(
                HistoryEvent(
                    itemID: UUID(), itemName: name, category: .vegetables, kind: .discarded,
                    date: calendar.adding(days: -daysAgo, to: now),
                    estimatedValueEUR: value, daysBeforeExpiry: -2
                )
            )
        }
        return events
    }

    static var urgentItem: FoodItem {
        item("Courgettes", brand: "Bio Village", category: .vegetables, expiresIn: 3, quantity: 2)
    }

    static var recipeMatch: RecipeMatch? {
        RecipeMatcher().matches(recipes: RecipeCatalog.all, items: fridge, limit: 1).first
    }
}

@MainActor
extension AppEnvironment {
    /// Environnement complet, en mémoire, pré-rempli. À n'utiliser que dans les
    /// aperçus : la persistance est volatile et les réglages sont isolés.
    static func preview(
        items: [FoodItem] = SampleData.fridge,
        history: [HistoryEvent] = SampleData.history,
        onboarded: Bool = true
    ) -> AppEnvironment {
        let environment = AppEnvironment(inMemory: true)
        environment.preferences.hasCompletedOnboarding = onboarded
        environment.preferences.wasteBaselineEUR = 30
        environment.fridge.add(contentsOf: items)
        environment.fridge.seedHistory(history)
        return environment
    }

    /// Frigo vide, pour vérifier les états vides — ils comptent autant que les
    /// états remplis, et ce sont ceux qu'on oublie de regarder.
    static func previewEmpty() -> AppEnvironment {
        AppEnvironment.preview(items: [], history: [], onboarded: true)
    }
}
#endif
