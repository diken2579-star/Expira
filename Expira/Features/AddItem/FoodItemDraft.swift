import Foundation
import ExpiraCore

/// Brouillon d'aliment en cours de saisie.
///
/// Principe directeur : **un seul champ est réellement obligatoire, le nom.**
/// Tout le reste a un défaut intelligent. Changer la catégorie ou le lieu de
/// stockage recalcule la date estimée — mais **jamais** une date lue sur
/// l'emballage ou saisie par l'utilisateur : on n'écrase pas une information
/// plus fiable par une estimation.
struct FoodItemDraft {
    var id = UUID()
    var name = ""
    var brand: String?
    var barcode: String?
    var category: FoodCategory = .other
    var storage: StorageLocation = .fridge
    var quantity: Double = 1
    var unit: QuantityUnit = .piece
    var purchaseDate = Date()
    var expiryDate = Date()
    var expirySource: ExpiryDateSource = .estimated
    var isOpened = false
    var imageURLString: String?
    var notes: String?
    var createdAt = Date()

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Construction

    static func new(estimator: ExpiryEstimator, category: FoodCategory = .other) -> FoodItemDraft {
        var draft = FoodItemDraft()
        draft.category = category
        draft.storage = estimator.defaultStorage(for: category)
        draft.expiryDate = estimator.estimatedExpiry(category: category, storage: draft.storage)
        draft.expirySource = .estimated
        return draft
    }

    static func from(product: ProductInfo, estimator: ExpiryEstimator) -> FoodItemDraft {
        var draft = FoodItemDraft()
        draft.name = product.name
        draft.brand = product.brand
        draft.barcode = product.barcode
        draft.category = product.category
        draft.storage = estimator.defaultStorage(for: product.category)
        draft.expiryDate = estimator.estimatedExpiry(category: product.category, storage: draft.storage)
        draft.expirySource = .estimated
        draft.imageURLString = product.imageURLString
        return draft
    }

    static func from(item: FoodItem) -> FoodItemDraft {
        var draft = FoodItemDraft()
        draft.id = item.id
        draft.name = item.name
        draft.brand = item.brand
        draft.barcode = item.barcode
        draft.category = item.category
        draft.storage = item.storage
        draft.quantity = item.quantity
        draft.unit = item.unit
        draft.purchaseDate = item.purchaseDate
        draft.expiryDate = item.expiryDate
        draft.expirySource = item.expirySource
        draft.isOpened = item.isOpened
        draft.imageURLString = item.imageURLString
        draft.notes = item.notes
        draft.createdAt = item.createdAt
        return draft
    }

    // MARK: - Mise à jour

    /// Recalcule la date estimée après un changement de catégorie, de stockage
    /// ou d'état « entamé ». Sans effet si la date vient de l'emballage ou de
    /// l'utilisateur.
    mutating func refreshEstimatedExpiry(using estimator: ExpiryEstimator) {
        guard expirySource == .estimated else { return }
        expiryDate = estimator.estimatedExpiry(
            category: category,
            storage: storage,
            isOpened: isOpened,
            from: purchaseDate
        )
    }

    mutating func applyCategory(_ newCategory: FoodCategory, estimator: ExpiryEstimator) {
        category = newCategory
        storage = estimator.defaultStorage(for: newCategory)
        refreshEstimatedExpiry(using: estimator)
    }

    /// Applique une date lue sur l'emballage : elle prend le pas sur toute estimation.
    mutating func applyScannedDate(_ date: Date) {
        expiryDate = date
        expirySource = .label
    }

    mutating func applyUserDate(_ date: Date) {
        // Une date identique à l'estimation ne « devient » pas une saisie
        // utilisateur : le badge « estimée » doit rester honnête tant que
        // personne n'a rien corrigé.
        guard date != expiryDate else { return }
        expiryDate = date
        expirySource = .user
    }

    func build(estimator: ExpiryEstimator) -> FoodItem {
        FoodItem(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            barcode: barcode,
            category: category,
            storage: storage,
            quantity: quantity,
            unit: unit,
            purchaseDate: purchaseDate,
            expiryDate: expiryDate,
            expirySource: expirySource,
            isOpened: isOpened,
            imageURLString: imageURLString,
            notes: notes?.nilIfEmpty,
            estimatedValueEUR: estimator.estimatedValueEUR(for: category, quantity: quantity, unit: unit),
            status: .active,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }

    /// Fiche produit à mémoriser localement quand l'utilisateur a nommé
    /// lui-même un code-barres inconnu.
    var productInfoForMemory: ProductInfo? {
        guard let barcode, isValid else { return nil }
        return ProductInfo(
            barcode: barcode,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand,
            category: category,
            imageURLString: imageURLString,
            isLocal: true
        )
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
