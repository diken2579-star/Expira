import Foundation

/// Confronte un catalogue de recettes au contenu réel du frigo.
///
/// L'objectif n'est **pas** de proposer la meilleure recette de cuisine : c'est
/// de proposer celle qui sauve le plus d'aliments proches de leur date limite,
/// tout en restant réalisable ce soir.
public struct RecipeMatcher: Sendable {
    private let calendar: Calendar

    /// Pondérations du score. Voir `docs/BLUEPRINT.md` §6.4.
    private let urgencyWeight = 3.0
    private let coverageWeight = 2.0
    private let missingPenalty = 0.5
    private let timePenalty = 0.3

    public init(calendar: Calendar = .expira) {
        self.calendar = calendar
    }

    /// - Parameters:
    ///   - items: aliments actifs du stock.
    ///   - limit: nombre de recettes renvoyées (3 sur l'écran Recettes).
    ///   - requiresUrgentItem: si `true`, seules les recettes qui sauvent au moins
    ///     un aliment urgent sont renvoyées (comportement du plan de sauvetage).
    public func matches(
        recipes: [Recipe],
        items: [FoodItem],
        asOf date: Date = Date(),
        limit: Int = 3,
        requiresUrgentItem: Bool = false
    ) -> [RecipeMatch] {
        let activeItems = items.active
        guard !activeItems.isEmpty else { return [] }

        var results: [RecipeMatch] = []
        results.reserveCapacity(recipes.count)

        for recipe in recipes {
            guard let match = evaluate(recipe: recipe, against: activeItems, asOf: date) else { continue }
            if requiresUrgentItem {
                let savesUrgent = match.matchedItems.contains { $0.urgency(asOf: date, calendar: calendar) <= .thisWeek }
                guard savesUrgent else { continue }
            }
            results.append(match)
        }

        return results
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.savedItemCount != rhs.savedItemCount { return lhs.savedItemCount > rhs.savedItemCount }
                return lhs.recipe.minutes < rhs.recipe.minutes
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Évalue une recette. Renvoie `nil` si elle ne consomme aucun aliment du
    /// stock : on ne propose jamais une recette « à faire avec des courses ».
    public func evaluate(recipe: Recipe, against items: [FoodItem], asOf date: Date = Date()) -> RecipeMatch? {
        var available: [RecipeIngredient] = []
        var missing: [RecipeIngredient] = []
        var matchedItems: [FoodItem] = []
        var claimedItemIDs: Set<UUID> = []

        for ingredient in recipe.ingredients {
            if ingredient.isStaple {
                available.append(ingredient)
                continue
            }
            if let item = bestItem(for: ingredient, in: items, excluding: claimedItemIDs, asOf: date) {
                claimedItemIDs.insert(item.id)
                matchedItems.append(item)
                available.append(ingredient)
            } else {
                missing.append(ingredient)
            }
        }

        guard !matchedItems.isEmpty else { return nil }

        let urgencyScore = matchedItems.reduce(0.0) { partial, item in
            partial + item.urgency(asOf: date, calendar: calendar).weight
        }
        let essentials = max(1, recipe.essentialIngredients.count)
        let ownedEssentials = available.filter { !$0.isStaple && !$0.isOptional }.count
        let coverage = Double(ownedEssentials) / Double(essentials)
        let missingRequired = missing.filter { !$0.isOptional }.count

        let score = urgencyScore * urgencyWeight
            + coverage * coverageWeight
            - Double(missingRequired) * missingPenalty
            - (Double(recipe.minutes) / 60.0) * timePenalty

        return RecipeMatch(
            recipe: recipe,
            matchedItems: matchedItems,
            availableIngredients: available,
            missingIngredients: missing,
            score: score
        )
    }

    /// Parmi les aliments qui correspondent à un ingrédient, on retient le plus
    /// urgent : c'est celui qu'il faut sauver en premier.
    private func bestItem(
        for ingredient: RecipeIngredient,
        in items: [FoodItem],
        excluding claimed: Set<UUID>,
        asOf date: Date
    ) -> FoodItem? {
        items
            .filter { item in
                guard !claimed.contains(item.id) else { return false }
                return ingredient.keywords.contains { keyword in
                    TextNormalizer.matches(subject: item.name, keyword: keyword)
                }
            }
            .min { lhs, rhs in lhs.expiryDate < rhs.expiryDate }
    }
}
