import Foundation
import SwiftData
import ExpiraCore

/// Représentation persistée d'un aliment.
///
/// Les énumérations sont stockées en `String` brute plutôt qu'en type Swift :
/// une valeur inconnue lue après une mise à jour ne fait pas échouer le décodage,
/// elle retombe sur un défaut. Une app de frigo ne doit jamais refuser de
/// s'ouvrir à cause d'un champ.
@Model
public final class StoredFoodItem {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var brand: String?
    public var barcode: String?
    public var categoryRaw: String
    public var storageRaw: String
    public var quantity: Double
    public var unitRaw: String
    public var purchaseDate: Date
    public var expiryDate: Date
    public var expirySourceRaw: String
    public var isOpened: Bool
    public var imageURLString: String?
    public var notes: String?
    public var estimatedValueEUR: Double
    public var statusRaw: String
    public var resolvedAt: Date?
    public var householdID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        brand: String?,
        barcode: String?,
        categoryRaw: String,
        storageRaw: String,
        quantity: Double,
        unitRaw: String,
        purchaseDate: Date,
        expiryDate: Date,
        expirySourceRaw: String,
        isOpened: Bool,
        imageURLString: String?,
        notes: String?,
        estimatedValueEUR: Double,
        statusRaw: String,
        resolvedAt: Date?,
        householdID: UUID?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.categoryRaw = categoryRaw
        self.storageRaw = storageRaw
        self.quantity = quantity
        self.unitRaw = unitRaw
        self.purchaseDate = purchaseDate
        self.expiryDate = expiryDate
        self.expirySourceRaw = expirySourceRaw
        self.isOpened = isOpened
        self.imageURLString = imageURLString
        self.notes = notes
        self.estimatedValueEUR = estimatedValueEUR
        self.statusRaw = statusRaw
        self.resolvedAt = resolvedAt
        self.householdID = householdID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public convenience init(_ item: FoodItem) {
        self.init(
            id: item.id,
            name: item.name,
            brand: item.brand,
            barcode: item.barcode,
            categoryRaw: item.category.rawValue,
            storageRaw: item.storage.rawValue,
            quantity: item.quantity,
            unitRaw: item.unit.rawValue,
            purchaseDate: item.purchaseDate,
            expiryDate: item.expiryDate,
            expirySourceRaw: item.expirySource.rawValue,
            isOpened: item.isOpened,
            imageURLString: item.imageURLString,
            notes: item.notes,
            estimatedValueEUR: item.estimatedValueEUR,
            statusRaw: item.status.rawValue,
            resolvedAt: item.resolvedAt,
            householdID: item.householdID,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
    }

    public func apply(_ item: FoodItem) {
        name = item.name
        brand = item.brand
        barcode = item.barcode
        categoryRaw = item.category.rawValue
        storageRaw = item.storage.rawValue
        quantity = item.quantity
        unitRaw = item.unit.rawValue
        purchaseDate = item.purchaseDate
        expiryDate = item.expiryDate
        expirySourceRaw = item.expirySource.rawValue
        isOpened = item.isOpened
        imageURLString = item.imageURLString
        notes = item.notes
        estimatedValueEUR = item.estimatedValueEUR
        statusRaw = item.status.rawValue
        resolvedAt = item.resolvedAt
        householdID = item.householdID
        updatedAt = Date()
    }

    public var domain: FoodItem {
        FoodItem(
            id: id,
            name: name,
            brand: brand,
            barcode: barcode,
            category: FoodCategory(rawValue: categoryRaw) ?? .other,
            storage: StorageLocation(rawValue: storageRaw) ?? .fridge,
            quantity: quantity,
            unit: QuantityUnit(rawValue: unitRaw) ?? .piece,
            purchaseDate: purchaseDate,
            expiryDate: expiryDate,
            expirySource: ExpiryDateSource(rawValue: expirySourceRaw) ?? .estimated,
            isOpened: isOpened,
            imageURLString: imageURLString,
            notes: notes,
            estimatedValueEUR: estimatedValueEUR,
            status: ItemStatus(rawValue: statusRaw) ?? .active,
            resolvedAt: resolvedAt,
            householdID: householdID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

/// Trace immuable d'une sortie de stock. Jamais modifiée après création.
@Model
public final class StoredHistoryEvent {
    @Attribute(.unique) public var id: UUID
    public var itemID: UUID
    public var itemName: String
    public var categoryRaw: String
    public var kindRaw: String
    public var date: Date
    public var estimatedValueEUR: Double
    public var daysBeforeExpiry: Int

    public init(
        id: UUID,
        itemID: UUID,
        itemName: String,
        categoryRaw: String,
        kindRaw: String,
        date: Date,
        estimatedValueEUR: Double,
        daysBeforeExpiry: Int
    ) {
        self.id = id
        self.itemID = itemID
        self.itemName = itemName
        self.categoryRaw = categoryRaw
        self.kindRaw = kindRaw
        self.date = date
        self.estimatedValueEUR = estimatedValueEUR
        self.daysBeforeExpiry = daysBeforeExpiry
    }

    public convenience init(_ event: HistoryEvent) {
        self.init(
            id: event.id,
            itemID: event.itemID,
            itemName: event.itemName,
            categoryRaw: event.category.rawValue,
            kindRaw: event.kind.rawValue,
            date: event.date,
            estimatedValueEUR: event.estimatedValueEUR,
            daysBeforeExpiry: event.daysBeforeExpiry
        )
    }

    public var domain: HistoryEvent {
        HistoryEvent(
            id: id,
            itemID: itemID,
            itemName: itemName,
            category: FoodCategory(rawValue: categoryRaw) ?? .other,
            kind: HistoryEvent.Kind(rawValue: kindRaw) ?? .consumed,
            date: date,
            estimatedValueEUR: estimatedValueEUR,
            daysBeforeExpiry: daysBeforeExpiry
        )
    }
}
