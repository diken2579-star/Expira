import Foundation

/// Une journée du plan de sauvetage.
public struct RescuePlanDay: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let dayOffset: Int
    public let date: Date
    /// `nil` = aucune recette pertinente : on suggère de consommer tel quel.
    public let recipe: Recipe?
    public let items: [FoodItem]

    public var savedItemCount: Int { items.count }

    public var title: String {
        switch dayOffset {
        case 0: return "Ce soir"
        case 1: return "Demain"
        case 2: return "Après-demain"
        default: return date.expiraShortDateString().capitalized
        }
    }

    public var suggestion: String {
        if let recipe { return "\(recipe.emoji) \(recipe.title)" }
        let names = items.prefix(3).map(\.displayName)
        return "À consommer tel quel : \(names.joined(separator: ", "))"
    }

    public init(id: UUID = UUID(), dayOffset: Int, date: Date, recipe: Recipe?, items: [FoodItem]) {
        self.id = id
        self.dayOffset = dayOffset
        self.date = date
        self.recipe = recipe
        self.items = items
    }
}

public struct RescuePlan: Equatable, Sendable {
    public let days: [RescuePlanDay]
    public let itemsAtRisk: [FoodItem]
    public let generatedAt: Date

    public var totalItemsSaved: Int { days.reduce(0) { $0 + $1.savedItemCount } }

    public var estimatedSavingsEUR: Double {
        let total = days.flatMap(\.items).reduce(0.0) { $0 + $1.estimatedValueEUR }
        return (total * 100).rounded() / 100
    }

    public var isEmpty: Bool { days.isEmpty }

    public init(days: [RescuePlanDay], itemsAtRisk: [FoodItem], generatedAt: Date = Date()) {
        self.days = days
        self.itemsAtRisk = itemsAtRisk
        self.generatedAt = generatedAt
    }
}

/// Construit le plan « Sauver mes aliments ».
///
/// Algorithme : glouton par couverture d'ensemble. On choisit la recette qui
/// sauve le plus d'aliments urgents, on retire ces aliments du réservoir, puis on
/// recommence pour le jour suivant. Simple, déterministe, instantané — et
/// suffisant : l'utilisateur veut un plan crédible, pas un optimum théorique.
public struct RescuePlanner: Sendable {
    private let calendar: Calendar
    private let matcher: RecipeMatcher

    public init(calendar: Calendar = .expira) {
        self.calendar = calendar
        self.matcher = RecipeMatcher(calendar: calendar)
    }

    public func makePlan(
        items: [FoodItem],
        recipes: [Recipe],
        asOf date: Date = Date(),
        dayCount: Int = 3,
        excludedRecipeIDs: Set<String> = []
    ) -> RescuePlan {
        let atRisk = items.active
            .filter { $0.urgency(asOf: date, calendar: calendar) <= .thisWeek }
            .sortedByUrgency(asOf: date, calendar: calendar)

        guard !atRisk.isEmpty else {
            return RescuePlan(days: [], itemsAtRisk: [], generatedAt: date)
        }

        var pool = atRisk
        var usedRecipeIDs = excludedRecipeIDs
        var days: [RescuePlanDay] = []

        for offset in 0..<dayCount {
            guard !pool.isEmpty else { break }
            let dayDate = calendar.startOfDay(for: calendar.adding(days: offset, to: date))

            let candidates = matcher
                .matches(recipes: recipes, items: pool, asOf: date, limit: 5, requiresUrgentItem: true)
                .filter { !usedRecipeIDs.contains($0.recipe.id) }

            if let best = candidates.first {
                usedRecipeIDs.insert(best.recipe.id)
                let saved = best.matchedItems
                pool.removeAll { item in saved.contains(where: { $0.id == item.id }) }
                days.append(
                    RescuePlanDay(dayOffset: offset, date: dayDate, recipe: best.recipe, items: saved)
                )
            } else {
                // Aucune recette : on suggère quand même une action concrète
                // pour les aliments les plus pressants, plutôt qu'un trou dans le plan.
                let direct = Array(pool.prefix(2))
                guard !direct.isEmpty else { break }
                pool.removeFirst(direct.count)
                days.append(
                    RescuePlanDay(dayOffset: offset, date: dayDate, recipe: nil, items: direct)
                )
            }
        }

        return RescuePlan(days: days, itemsAtRisk: atRisk, generatedAt: date)
    }
}
