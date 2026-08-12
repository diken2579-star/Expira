import Foundation
import ExpiraCore

/// Stockage local des fiches produit déjà vues.
///
/// Sert deux buts : éviter un appel réseau pour un produit racheté chaque semaine,
/// et **apprendre** les produits absents d'Open Food Facts. Quand l'utilisateur
/// nomme lui-même un produit inconnu, le code-barres est mémorisé : le prochain
/// scan sera instantané et hors-ligne.
public protocol ProductCacheStore: Sendable {
    func product(for barcode: String) -> ProductInfo?
    func store(_ product: ProductInfo)
}

public final class UserDefaultsProductCache: ProductCacheStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "expira.product.cache.v1"
    private let maxEntries = 400
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func product(for barcode: String) -> ProductInfo? {
        lock.lock()
        defer { lock.unlock() }
        return load()[barcode]
    }

    public func store(_ product: ProductInfo) {
        lock.lock()
        defer { lock.unlock() }
        var entries = load()
        entries[product.barcode] = product
        // Purge grossière mais suffisante : le cache est un confort, pas une base.
        if entries.count > maxEntries {
            entries = Dictionary(uniqueKeysWithValues: Array(entries).suffix(maxEntries / 2))
        }
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
        }
    }

    private func load() -> [String: ProductInfo] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: ProductInfo].self, from: data)
        else { return [:] }
        return decoded
    }
}

/// Résolution de code-barres avec cache et repli hors-ligne.
///
/// Séquence : cache local → réseau → cache local en secours.
/// Aucune de ces étapes ne peut bloquer l'utilisateur : en dernier recours, il
/// arrive sur l'écran « produit inconnu » avec le code-barres déjà rempli.
public struct CachedProductLookupService: ProductLookupService {
    private let remote: ProductLookupService
    private let cache: ProductCacheStore

    public init(remote: ProductLookupService, cache: ProductCacheStore) {
        self.remote = remote
        self.cache = cache
    }

    public init() {
        self.init(remote: OpenFoodFactsClient(), cache: UserDefaultsProductCache())
    }

    public func lookup(barcode: String) async throws -> ProductInfo? {
        if let cached = cache.product(for: barcode) {
            return cached
        }
        do {
            guard let fetched = try await remote.lookup(barcode: barcode) else { return nil }
            cache.store(fetched)
            return fetched
        } catch {
            // Hors ligne ou service indisponible : on ne relance pas d'erreur si
            // on a déjà vu ce produit, l'utilisateur ne doit rien remarquer.
            if let fallback = cache.product(for: barcode) { return fallback }
            throw error
        }
    }

    /// Mémorise un produit nommé à la main par l'utilisateur.
    public func remember(_ product: ProductInfo) {
        let local = ProductInfo(
            barcode: product.barcode,
            name: product.name,
            brand: product.brand,
            category: product.category,
            imageURLString: product.imageURLString,
            quantityText: product.quantityText,
            isLocal: true
        )
        cache.store(local)
    }
}
