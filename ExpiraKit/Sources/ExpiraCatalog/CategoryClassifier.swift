import Foundation
import ExpiraCore

/// Devine la catégorie d'un produit à partir de son nom et des étiquettes
/// Open Food Facts.
///
/// Objectif : que l'utilisateur n'ait **rien** à choisir dans la majorité des cas.
/// En cas de doute, on renvoie `.other` plutôt qu'une catégorie fausse — une
/// mauvaise catégorie produit une mauvaise date estimée.
public enum CategoryClassifier {
    /// Ordre important : les règles les plus spécifiques d'abord.
    /// (« lait de coco » est de l'épicerie, pas un produit laitier.)
    private static let rules: [(category: FoodCategory, keywords: [String])] = [
        (.pantry, ["lait de coco", "creme de coco", "conserve", "bocal", "farine", "sucre", "riz",
                   "pates", "pate a", "huile", "vinaigre", "sauce", "epice", "cafe", "the",
                   "cereale", "biscuit", "chocolat", "confiture", "miel", "haricot", "lentille",
                   "pois chiche", "semoule", "quinoa", "boulgour", "mais", "olive", "moutarde",
                   "ketchup", "mayonnaise", "bouillon"]),
        (.frozen, ["surgele", "congele", "glace", "sorbet", "creme glacee"]),
        (.poultry, ["poulet", "dinde", "volaille", "canard", "pintade", "escalope de dinde"]),
        (.fish, ["poisson", "saumon", "cabillaud", "thon", "colin", "lieu", "dorade", "truite",
                 "sardine", "maquereau", "crevette", "moule", "crabe", "surimi"]),
        (.meat, ["boeuf", "veau", "porc", "agneau", "steak", "viande", "hache", "cote",
                 "roti", "saucisse", "merguez"]),
        (.deli, ["jambon", "lardon", "bacon", "charcuterie", "saucisson", "pate", "rillette",
                 "chorizo", "salami", "terrine"]),
        (.cheese, ["fromage", "camembert", "emmental", "gruyere", "comte", "mozzarella", "feta",
                   "chevre", "roquefort", "brie", "parmesan", "raclette", "cheddar", "reblochon"]),
        (.dairy, ["lait", "yaourt", "yogourt", "creme", "beurre", "fromage blanc", "skyr",
                  "petit suisse", "dessert lacte"]),
        (.eggs, ["oeuf", "œuf", "oeufs"]),
        (.bakery, ["pain", "baguette", "brioche", "croissant", "viennoiserie", "tortilla",
                   "wrap", "galette", "biscotte", "pain de mie"]),
        (.fruits, ["pomme", "banane", "orange", "fraise", "raisin", "poire", "peche", "abricot",
                   "kiwi", "mangue", "ananas", "citron", "cerise", "melon", "pasteque", "prune",
                   "framboise", "myrtille", "clementine", "avocat", "fruit"]),
        (.vegetables, ["tomate", "carotte", "courgette", "salade", "laitue", "poivron", "oignon",
                       "pomme de terre", "patate", "brocoli", "chou", "epinard", "concombre",
                       "aubergine", "champignon", "poireau", "haricot vert", "petit pois",
                       "radis", "betterave", "navet", "celeri", "ail", "echalote", "legume"]),
        (.beverages, ["jus", "soda", "eau", "biere", "vin", "boisson", "limonade", "sirop",
                      "smoothie", "cola"]),
        (.prepared, ["plat", "pizza", "lasagne", "quiche", "sandwich", "salade composee",
                     "soupe", "potage", "gratin", "couscous", "paella"]),
    ]

    /// Correspondance directe avec les tags Open Food Facts (`categories_tags`),
    /// plus fiable que le nom quand elle est disponible.
    private static let offTagRules: [(category: FoodCategory, tags: [String])] = [
        (.dairy, ["dairies", "milks", "yogurts", "creams", "produits-laitiers", "laits", "yaourts"]),
        (.cheese, ["cheeses", "fromages"]),
        (.eggs, ["eggs", "oeufs"]),
        (.poultry, ["poultry", "chickens", "volailles", "poulets"]),
        (.meat, ["meats", "beef", "pork", "viandes"]),
        (.fish, ["fishes", "seafood", "poissons", "produits-de-la-mer"]),
        (.deli, ["charcuteries", "hams", "delicatessen", "jambons"]),
        (.fruits, ["fruits", "fresh-fruits"]),
        (.vegetables, ["vegetables", "fresh-vegetables", "legumes"]),
        (.bakery, ["breads", "bakery", "pains", "viennoiseries"]),
        (.frozen, ["frozen-foods", "surgeles"]),
        (.beverages, ["beverages", "boissons", "waters", "juices"]),
        (.prepared, ["meals", "prepared-meals", "plats-prepares", "pizzas", "soups"]),
        (.pantry, ["groceries", "canned-foods", "epicerie", "conserves", "pastas", "rices",
                   "cereals", "condiments", "sauces", "snacks", "chocolates", "biscuits"]),
    ]

    public static func classify(name: String, offTags: [String] = []) -> FoodCategory {
        // 1. Les tags Open Food Facts d'abord : ils sont structurés.
        let normalizedTags = offTags.map { tag -> String in
            // « en:dairies » → « dairies »
            guard let colon = tag.firstIndex(of: ":") else { return TextNormalizer.normalize(tag) }
            return TextNormalizer.normalize(String(tag[tag.index(after: colon)...]))
        }
        for rule in offTagRules {
            for tag in rule.tags where normalizedTags.contains(TextNormalizer.normalize(tag)) {
                return rule.category
            }
        }

        // 2. Repli sur le nom du produit.
        let normalizedName = TextNormalizer.normalize(name)
        guard !normalizedName.isEmpty else { return .other }
        for rule in rules {
            for keyword in rule.keywords where TextNormalizer.matches(subject: normalizedName, keyword: keyword) {
                return rule.category
            }
        }
        return .other
    }
}
