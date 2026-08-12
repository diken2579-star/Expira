import Foundation
import Observation
import SwiftData
import ExpiraCore

/// Source de vérité du stock, côté application.
///
/// Les vues ne parlent jamais à SwiftData : elles lisent `items` / `events` et
/// appellent des méthodes explicites. Le volume manipulé est de l'ordre de la
/// centaine d'objets — on charge tout en mémoire et on filtre en Swift, ce qui
/// évite les prédicats SwiftData fragiles et garde l'écran instantané.
@MainActor
@Observable
public final class FridgeStore {
    public private(set) var items: [FoodItem] = []
    public private(set) var events: [HistoryEvent] = []
    /// Renseigné si la persistance a échoué : l'interface l'affiche discrètement.
    public private(set) var persistenceWarning: String?

    private let context: ModelContext
    private let calendar: Calendar
    /// Au-delà de ce délai, un aliment périmé sans action quitte la liste.
    /// Il n'est pas compté comme « jeté » : on ne sait pas ce qui s'est passé,
    /// et inventer un chiffre serait mentir à l'utilisateur.
    private let autoArchiveAfterDays = 7

    public init(context: ModelContext, calendar: Calendar = .expira) {
        self.context = context
        self.calendar = calendar
        reload()
    }

    // MARK: - Lecture

    public var activeItems: [FoodItem] {
        items.filter { $0.status == .active }
    }

    public func items(in level: UrgencyLevel, asOf date: Date = Date()) -> [FoodItem] {
        activeItems
            .filter { $0.urgency(asOf: date, calendar: calendar) == level }
            .sortedByUrgency(asOf: date, calendar: calendar)
    }

    /// Aliments à traiter en priorité : périmés, aujourd'hui et demain.
    public func urgentItems(asOf date: Date = Date()) -> [FoodItem] {
        activeItems
            .filter { $0.urgency(asOf: date, calendar: calendar).requiresAttention }
            .sortedByUrgency(asOf: date, calendar: calendar)
    }

    public func item(withID id: UUID) -> FoodItem? {
        items.first { $0.id == id }
    }

    public func reload() {
        do {
            let itemDescriptor = FetchDescriptor<StoredFoodItem>(
                sortBy: [SortDescriptor(\.expiryDate, order: .forward)]
            )
            items = try context.fetch(itemDescriptor).map(\.domain)

            let eventDescriptor = FetchDescriptor<StoredHistoryEvent>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            events = try context.fetch(eventDescriptor).map(\.domain)
            persistenceWarning = nil
        } catch {
            persistenceWarning = "Vos données n'ont pas pu être chargées complètement."
        }
    }

    // MARK: - Écriture

    @discardableResult
    public func add(_ item: FoodItem) -> Bool {
        context.insert(StoredFoodItem(item))
        return save()
    }

    @discardableResult
    public func add(contentsOf newItems: [FoodItem]) -> Bool {
        for item in newItems {
            context.insert(StoredFoodItem(item))
        }
        return save()
    }

    @discardableResult
    public func update(_ item: FoodItem) -> Bool {
        guard let stored = storedItem(id: item.id) else { return add(item) }
        stored.apply(item)
        return save()
    }

    /// Sort un aliment du stock et enregistre la trace correspondante.
    /// C'est le geste le plus important de l'app : il maintient le stock vrai.
    @discardableResult
    public func resolve(_ item: FoodItem, as kind: HistoryEvent.Kind, at date: Date = Date()) -> Bool {
        guard let stored = storedItem(id: item.id) else { return false }
        stored.statusRaw = (kind == .consumed ? ItemStatus.consumed : ItemStatus.discarded).rawValue
        stored.resolvedAt = date
        stored.updatedAt = date

        let event = HistoryEvent.from(item: item, kind: kind, at: date, calendar: calendar)
        context.insert(StoredHistoryEvent(event))
        return save()
    }

    @discardableResult
    public func resolve(_ itemsToResolve: [FoodItem], as kind: HistoryEvent.Kind, at date: Date = Date()) -> Bool {
        for item in itemsToResolve {
            guard let stored = storedItem(id: item.id) else { continue }
            stored.statusRaw = (kind == .consumed ? ItemStatus.consumed : ItemStatus.discarded).rawValue
            stored.resolvedAt = date
            stored.updatedAt = date
            context.insert(StoredHistoryEvent(HistoryEvent.from(item: item, kind: kind, at: date, calendar: calendar)))
        }
        return save()
    }

    /// Annule une sortie de stock — l'utilisateur se trompe de swipe, ça arrive.
    @discardableResult
    public func undoResolve(_ item: FoodItem) -> Bool {
        guard let stored = storedItem(id: item.id) else { return false }
        stored.statusRaw = ItemStatus.active.rawValue
        stored.resolvedAt = nil
        stored.updatedAt = Date()

        if let storedEvent = try? context.fetch(FetchDescriptor<StoredHistoryEvent>())
            .filter({ $0.itemID == item.id })
            .max(by: { $0.date < $1.date }) {
            context.delete(storedEvent)
        }
        return save()
    }

    @discardableResult
    public func delete(_ item: FoodItem) -> Bool {
        guard let stored = storedItem(id: item.id) else { return false }
        context.delete(stored)
        return save()
    }

    /// Supprime toutes les données locales — action proposée dans les réglages.
    @discardableResult
    public func deleteAllData() -> Bool {
        do {
            for stored in try context.fetch(FetchDescriptor<StoredFoodItem>()) {
                context.delete(stored)
            }
            for stored in try context.fetch(FetchDescriptor<StoredHistoryEvent>()) {
                context.delete(stored)
            }
        } catch {
            persistenceWarning = "La suppression n'a pas pu être effectuée entièrement."
            return false
        }
        return save()
    }

    // MARK: - Entretien du stock

    /// Retire de la liste les aliments périmés depuis longtemps et jamais traités.
    ///
    /// C'est la parade principale contre la dérive du stock : sans elle, l'écran
    /// Frigo se remplit de fantômes, l'utilisateur cesse de lui faire confiance,
    /// puis cesse d'ouvrir l'app.
    @discardableResult
    public func archiveStaleItems(asOf date: Date = Date()) -> Int {
        let stale = activeItems.filter { item in
            calendar.wholeDaysBetween(date, and: item.expiryDate) < -autoArchiveAfterDays
        }
        guard !stale.isEmpty else { return 0 }
        for item in stale {
            guard let stored = storedItem(id: item.id) else { continue }
            stored.statusRaw = ItemStatus.archived.rawValue
            stored.resolvedAt = date
            stored.updatedAt = date
        }
        _ = save()
        return stale.count
    }

    // MARK: - Limites de la version gratuite

    public func canAddItem(isPremium: Bool) -> Bool {
        isPremium || activeItems.count < FreeTierLimits.maxActiveItems
    }

    public func remainingFreeSlots() -> Int {
        max(0, FreeTierLimits.maxActiveItems - activeItems.count)
    }

    #if DEBUG
    /// Injecte un historique de démonstration. Réservé aux aperçus et aux tests :
    /// l'historique réel ne s'écrit qu'en sortant un aliment du stock.
    public func seedHistory(_ events: [HistoryEvent]) {
        for event in events {
            context.insert(StoredHistoryEvent(event))
        }
        _ = save()
    }
    #endif

    // MARK: - Interne

    private func storedItem(id: UUID) -> StoredFoodItem? {
        try? context.fetch(FetchDescriptor<StoredFoodItem>()).first { $0.id == id }
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try context.save()
            persistenceWarning = nil
            reload()
            return true
        } catch {
            context.rollback()
            reload()
            // Après `reload()` : celui-ci remet l'avertissement à zéro en cas de
            // lecture réussie, et c'est bien l'échec d'écriture qu'on veut afficher.
            persistenceWarning = "La modification n'a pas pu être enregistrée."
            return false
        }
    }
}
