import Foundation

/// L'entité centrale d'EXPIRA, sous forme de valeur immuable.
///
/// La couche de persistance (`ExpiraData`) fait la conversion avec son propre
/// modèle SwiftData. Les moteurs métier ne connaissent que ce type-ci : ils
/// restent donc testables sans base de données.
public struct FoodItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var brand: String?
    public var barcode: String?
    public var category: FoodCategory
    public var storage: StorageLocation
    public var quantity: Double
    public var unit: QuantityUnit
    public var purchaseDate: Date
    public var expiryDate: Date
    public var expirySource: ExpiryDateSource
    public var isOpened: Bool
    public var imageURLString: String?
    public var notes: String?
    /// Valeur estimée, utilisée uniquement pour le bilan « argent économisé ».
    /// Toujours présentée comme une estimation dans l'interface.
    public var estimatedValueEUR: Double
    public var status: ItemStatus
    public var resolvedAt: Date?
    /// Présent dès la V1 pour que l'arrivée du frigo partagé (V1.2) ne demande
    /// aucune migration douloureuse.
    public var householdID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        category: FoodCategory = .other,
        storage: StorageLocation = .fridge,
        quantity: Double = 1,
        unit: QuantityUnit = .piece,
        purchaseDate: Date = Date(),
        expiryDate: Date,
        expirySource: ExpiryDateSource = .estimated,
        isOpened: Bool = false,
        imageURLString: String? = nil,
        notes: String? = nil,
        estimatedValueEUR: Double = 0,
        status: ItemStatus = .active,
        resolvedAt: Date? = nil,
        householdID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.category = category
        self.storage = storage
        self.quantity = quantity
        self.unit = unit
        self.purchaseDate = purchaseDate
        self.expiryDate = expiryDate
        self.expirySource = expirySource
        self.isOpened = isOpened
        self.imageURLString = imageURLString
        self.notes = notes
        self.estimatedValueEUR = estimatedValueEUR
        self.status = status
        self.resolvedAt = resolvedAt
        self.householdID = householdID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Valeurs dérivées (jamais stockées : impossible d'être incohérent)

    public var isEstimated: Bool { expirySource.isEstimated }

    public var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? category.displayName
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sous-titre de ligne : marque et/ou quantité, sans jamais afficher « 1 u ».
    public var subtitle: String? {
        var parts: [String] = []
        if let brand, !brand.isEmpty { parts.append(brand) }
        if !(quantity == 1 && unit == .piece) {
            parts.append(Self.formatQuantity(quantity, unit: unit))
        }
        if isOpened { parts.append("entamé") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public func daysRemaining(asOf date: Date = Date(), calendar: Calendar = .expira) -> Int {
        calendar.wholeDaysBetween(date, and: expiryDate)
    }

    public func urgency(asOf date: Date = Date(), calendar: Calendar = .expira) -> UrgencyLevel {
        .from(daysRemaining: daysRemaining(asOf: date, calendar: calendar))
    }

    public func badgeLabel(asOf date: Date = Date(), calendar: Calendar = .expira) -> String {
        UrgencyLevel.badgeLabel(daysRemaining: daysRemaining(asOf: date, calendar: calendar))
    }

    public static func formatQuantity(_ quantity: Double, unit: QuantityUnit) -> String {
        let rounded = (quantity * 100).rounded() / 100
        let value = rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.2f", rounded)
        return "\(value) \(unit.shortName)"
    }
}

// MARK: - Tri

public extension Array where Element == FoodItem {
    /// Tri canonique de l'écran Frigo : le plus urgent en premier, puis par nom
    /// pour que l'ordre soit stable d'un lancement à l'autre.
    func sortedByUrgency(asOf date: Date = Date(), calendar: Calendar = .expira) -> [FoodItem] {
        sorted { lhs, rhs in
            let l = lhs.expiryDate
            let r = rhs.expiryDate
            if calendar.startOfDay(for: l) != calendar.startOfDay(for: r) {
                return l < r
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var active: [FoodItem] { filter { $0.status == .active } }
}
