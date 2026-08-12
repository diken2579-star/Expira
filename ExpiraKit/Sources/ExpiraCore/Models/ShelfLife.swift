import Foundation

/// Durée de conservation d'une catégorie dans un lieu de stockage donné.
public struct ShelfLifeRule: Equatable, Sendable, Hashable {
    public let category: FoodCategory
    public let storage: StorageLocation
    /// Durée en jours, produit fermé.
    public let days: Int
    /// Durée en jours une fois le produit entamé (toujours ≤ `days`).
    public let daysWhenOpened: Int

    public init(category: FoodCategory, storage: StorageLocation, days: Int, daysWhenOpened: Int) {
        self.category = category
        self.storage = storage
        self.days = days
        self.daysWhenOpened = min(daysWhenOpened, days)
    }

    public func days(isOpened: Bool) -> Int {
        isOpened ? daysWhenOpened : days
    }
}

/// Source des règles de conservation. Implémentée par `ExpiraCatalog`, mockée
/// dans les tests. `ExpiraCore` ne connaît que ce contrat.
public protocol ShelfLifeProviding: Sendable {
    func rule(for category: FoodCategory, storage: StorageLocation) -> ShelfLifeRule
    /// Lieu de stockage proposé par défaut pour une catégorie (le champ est
    /// pré-rempli, l'utilisateur n'a rien à choisir dans 90 % des cas).
    func defaultStorage(for category: FoodCategory) -> StorageLocation
    /// Prix moyen indicatif en euros, pour l'estimation d'économies.
    func averagePriceEUR(for category: FoodCategory) -> Double
}

/// Calcule une date de péremption **estimée**.
///
/// Le résultat est toujours accompagné de `ExpiryDateSource.estimated` par les
/// appelants : EXPIRA ne présente jamais une estimation comme une certitude.
public struct ExpiryEstimator: Sendable {
    private let provider: ShelfLifeProviding
    private let calendar: Calendar

    public init(provider: ShelfLifeProviding, calendar: Calendar = .expira) {
        self.provider = provider
        self.calendar = calendar
    }

    public func estimatedExpiry(
        category: FoodCategory,
        storage: StorageLocation,
        isOpened: Bool = false,
        from referenceDate: Date = Date()
    ) -> Date {
        let rule = provider.rule(for: category, storage: storage)
        let days = rule.days(isOpened: isOpened)
        let target = calendar.adding(days: days, to: referenceDate)
        return calendar.startOfDay(for: target)
    }

    public func defaultStorage(for category: FoodCategory) -> StorageLocation {
        provider.defaultStorage(for: category)
    }

    public func estimatedValueEUR(for category: FoodCategory, quantity: Double, unit: QuantityUnit) -> Double {
        let base = provider.averagePriceEUR(for: category)
        let multiplier: Double
        switch unit {
        case .piece, .pack:
            multiplier = max(1, quantity)
        case .gram:
            multiplier = max(0.2, quantity / 400)
        case .kilogram:
            multiplier = max(0.2, quantity * 2.5)
        case .milliliter:
            multiplier = max(0.2, quantity / 500)
        case .liter:
            multiplier = max(0.2, quantity * 2)
        }
        return ((base * multiplier) * 100).rounded() / 100
    }
}
