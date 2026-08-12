import Foundation

/// Fiche produit résolue à partir d'un code-barres.
public struct ProductInfo: Equatable, Hashable, Sendable, Codable {
    public let barcode: String
    public let name: String
    public let brand: String?
    public let category: FoodCategory
    public let imageURLString: String?
    /// Contenance telle qu'imprimée (« 500 g », « 1 L »), à titre indicatif.
    public let quantityText: String?
    /// `true` lorsque la fiche vient du cache ou de la mémoire locale de l'appareil.
    public let isLocal: Bool

    public init(
        barcode: String,
        name: String,
        brand: String? = nil,
        category: FoodCategory = .other,
        imageURLString: String? = nil,
        quantityText: String? = nil,
        isLocal: Bool = false
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.category = category
        self.imageURLString = imageURLString
        self.quantityText = quantityText
        self.isLocal = isLocal
    }
}

/// Contrat de résolution d'un code-barres. L'implémentation réseau vit dans
/// `ExpiraCatalog` ; les tests et les aperçus utilisent des doublures.
public protocol ProductLookupService: Sendable {
    /// Renvoie `nil` si le produit est introuvable — ce n'est **pas** une erreur :
    /// l'app bascule alors sur l'écran « produit inconnu » pré-rempli.
    func lookup(barcode: String) async throws -> ProductInfo?
}

/// Erreurs de résolution. Aucune n'est bloquante côté interface : elles mènent
/// toutes à un repli manuel.
public enum ProductLookupError: Error, Equatable, Sendable {
    case offline
    case timedOut
    case invalidBarcode
    case serverUnavailable

    public var userMessage: String {
        switch self {
        case .offline:
            return "Vous êtes hors ligne. Vous pouvez quand même ajouter ce produit à la main."
        case .timedOut:
            return "La recherche a pris trop de temps. Ajoutons-le à la main, c'est plus rapide."
        case .invalidBarcode:
            return "Ce code-barres n'a pas pu être lu."
        case .serverUnavailable:
            return "La base produits est momentanément indisponible."
        }
    }
}
