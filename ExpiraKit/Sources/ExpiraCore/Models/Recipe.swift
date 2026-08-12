import Foundation

public enum RecipeDifficulty: String, Codable, CaseIterable, Sendable, Hashable, Comparable {
    case easy
    case medium
    case hard

    public var displayName: String {
        switch self {
        case .easy: return "Facile"
        case .medium: return "Moyen"
        case .hard: return "Difficile"
        }
    }

    public var rank: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        }
    }

    public static func < (lhs: RecipeDifficulty, rhs: RecipeDifficulty) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct RecipeIngredient: Equatable, Hashable, Sendable, Identifiable {
    public let name: String
    public let category: FoodCategory?
    /// Mots-clés servant à reconnaître l'ingrédient dans le nom d'un aliment du
    /// stock (« blanc de poulet fermier » → `poulet`).
    public let keywords: [String]
    public let isOptional: Bool
    /// Produit de fond de placard (sel, huile, farine…) : on considère qu'il est
    /// disponible et on ne le compte jamais comme « manquant ».
    public let isStaple: Bool

    public var id: String { name }

    public init(
        _ name: String,
        category: FoodCategory? = nil,
        keywords: [String] = [],
        isOptional: Bool = false,
        isStaple: Bool = false
    ) {
        self.name = name
        self.category = category
        self.keywords = keywords.isEmpty ? [name] : keywords
        self.isOptional = isOptional
        self.isStaple = isStaple
    }
}

public struct Recipe: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let emoji: String
    public let minutes: Int
    public let difficulty: RecipeDifficulty
    public let servings: Int
    public let ingredients: [RecipeIngredient]
    public let steps: [String]
    public let tags: [String]

    public init(
        id: String,
        title: String,
        emoji: String,
        minutes: Int,
        difficulty: RecipeDifficulty,
        servings: Int = 2,
        ingredients: [RecipeIngredient],
        steps: [String],
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.minutes = minutes
        self.difficulty = difficulty
        self.servings = servings
        self.ingredients = ingredients
        self.steps = steps
        self.tags = tags
    }

    /// Ingrédients qu'on peut réellement exiger de l'utilisateur (hors placard).
    public var essentialIngredients: [RecipeIngredient] {
        ingredients.filter { !$0.isStaple && !$0.isOptional }
    }

    public var durationLabel: String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) h" : "\(hours) h \(remainder)"
    }
}

/// Résultat du moteur de matching : une recette confrontée au stock réel.
public struct RecipeMatch: Identifiable, Equatable, Sendable {
    public let recipe: Recipe
    /// Aliments du stock que cette recette permet de consommer.
    public let matchedItems: [FoodItem]
    public let availableIngredients: [RecipeIngredient]
    public let missingIngredients: [RecipeIngredient]
    public let score: Double

    public var id: String { recipe.id }
    public var savedItemCount: Int { matchedItems.count }

    /// Part des ingrédients essentiels déjà présents dans le frigo (0…1).
    public var coverage: Double {
        let essentials = recipe.essentialIngredients.count
        guard essentials > 0 else { return 1 }
        let owned = availableIngredients.filter { !$0.isStaple && !$0.isOptional }.count
        return Double(owned) / Double(essentials)
    }

    public var coverageLabel: String {
        let essentials = recipe.essentialIngredients.count
        let owned = availableIngredients.filter { !$0.isStaple && !$0.isOptional }.count
        return "\(owned)/\(essentials) ingrédients"
    }

    /// L'argument qui compte réellement pour l'utilisateur.
    public var savingsLabel: String {
        switch savedItemCount {
        case 0: return "Aucun aliment urgent"
        case 1: return "Sauve 1 aliment"
        default: return "Sauve \(savedItemCount) aliments"
        }
    }

    public init(
        recipe: Recipe,
        matchedItems: [FoodItem],
        availableIngredients: [RecipeIngredient],
        missingIngredients: [RecipeIngredient],
        score: Double
    ) {
        self.recipe = recipe
        self.matchedItems = matchedItems
        self.availableIngredients = availableIngredients
        self.missingIngredients = missingIngredients
        self.score = score
    }
}
