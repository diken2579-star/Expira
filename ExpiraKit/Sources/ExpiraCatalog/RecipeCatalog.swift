import Foundation
import ExpiraCore

/// Catalogue de recettes anti-gaspillage embarqué dans l'app.
///
/// **Pourquoi pas une IA générative en V1 ?** Un catalogue local coûte 0 € par
/// requête, répond en 2 ms, fonctionne dans le métro, et ne peut pas inventer une
/// recette dangereuse. Le moteur de matching (`RecipeMatcher`) apporte 90 % de la
/// valeur d'un « chef IA » sans aucun de ses risques. L'IA générative viendra en
/// V2, une fois la boucle prouvée.
///
/// Les recettes sont choisies pour un seul critère : **absorber des restes**.
/// Ce sont des bases souples, pas de la haute gastronomie.
public enum RecipeCatalog {
    public static let all: [Recipe] = [
        omeletteAuxLegumes,
        rizSauteAuPoulet,
        soupeDeLegumes,
        gratinDeCourgettes,
        patesCremeJambon,
        pouletRotiLegumes,
        quicheAuxRestes,
        saladeComposee,
        ratatouille,
        curryDeLegumesCoco,
        croqueMonsieur,
        painPerdu,
        smoothieAuxFruits,
        compoteDeFruits,
        tarteAuxPommes,
        poeleePommesDeTerreLardons,
        risottoAuxChampignons,
        chiliSinCarne,
        poissonAuFour,
        velouteDeCourgettes,
        wrapsAuPoulet,
        saladeDeRiz,
        gratinDauphinois,
        frittataDePates,
    ]

    // MARK: - Ingrédients de fond de placard

    private static let sel = RecipeIngredient("Sel", isStaple: true)
    private static let poivre = RecipeIngredient("Poivre", isStaple: true)
    private static let huile = RecipeIngredient("Huile d'olive", keywords: ["huile"], isStaple: true)
    private static let beurre = RecipeIngredient("Beurre", category: .dairy, keywords: ["beurre"], isStaple: true)
    private static let farine = RecipeIngredient("Farine", category: .pantry, keywords: ["farine"], isStaple: true)
    private static let sucre = RecipeIngredient("Sucre", category: .pantry, keywords: ["sucre"], isStaple: true)
    private static let epices = RecipeIngredient("Épices", isStaple: true)

    // MARK: - Recettes

    static let omeletteAuxLegumes = Recipe(
        id: "omelette-legumes",
        title: "Omelette aux légumes",
        emoji: "🍳",
        minutes: 15,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Œufs", category: .eggs, keywords: ["oeuf", "œuf", "oeufs"]),
            RecipeIngredient("Légumes au choix", category: .vegetables,
                             keywords: ["courgette", "poivron", "tomate", "oignon", "champignon", "epinard", "poireau"]),
            RecipeIngredient("Fromage râpé", category: .cheese, keywords: ["fromage", "emmental", "gruyere"], isOptional: true),
            huile, sel, poivre,
        ],
        steps: [
            "Coupez les légumes en petits dés et faites-les revenir 5 minutes à la poêle.",
            "Battez les œufs, salez, poivrez.",
            "Versez sur les légumes, baissez le feu et couvrez 4 minutes.",
            "Ajoutez le fromage, pliez l'omelette et servez.",
        ],
        tags: ["rapide", "restes", "végétarien"]
    )

    static let rizSauteAuPoulet = Recipe(
        id: "riz-saute-poulet",
        title: "Riz sauté au poulet",
        emoji: "🍚",
        minutes: 20,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Poulet", category: .poultry, keywords: ["poulet", "blanc de poulet", "escalope", "dinde"]),
            RecipeIngredient("Riz cuit", category: .pantry, keywords: ["riz"]),
            RecipeIngredient("Légumes", category: .vegetables,
                             keywords: ["carotte", "poivron", "petit pois", "oignon", "courgette", "brocoli"]),
            RecipeIngredient("Œuf", category: .eggs, keywords: ["oeuf", "œuf"], isOptional: true),
            RecipeIngredient("Sauce soja", category: .pantry, keywords: ["soja", "sauce soja"], isOptional: true),
            huile, sel, poivre,
        ],
        steps: [
            "Coupez le poulet en morceaux et saisissez-le à feu vif 5 minutes.",
            "Ajoutez les légumes coupés, faites sauter 5 minutes de plus.",
            "Incorporez le riz cuit, mélangez et faites revenir 5 minutes.",
            "Cassez l'œuf dans la poêle, mélangez, assaisonnez et servez.",
        ],
        tags: ["rapide", "restes", "complet"]
    )

    static let soupeDeLegumes = Recipe(
        id: "soupe-legumes",
        title: "Soupe de légumes du frigo",
        emoji: "🥣",
        minutes: 30,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Légumes variés", category: .vegetables,
                             keywords: ["carotte", "poireau", "pomme de terre", "courgette", "navet", "celeri", "potiron", "oignon"]),
            RecipeIngredient("Bouillon", category: .pantry, keywords: ["bouillon", "cube"], isOptional: true),
            RecipeIngredient("Crème fraîche", category: .dairy, keywords: ["creme", "creme fraiche"], isOptional: true),
            sel, poivre,
        ],
        steps: [
            "Épluchez et coupez tous les légumes en morceaux.",
            "Couvrez d'eau, ajoutez le bouillon et portez à ébullition.",
            "Laissez mijoter 25 minutes à couvert.",
            "Mixez, ajoutez la crème, rectifiez l'assaisonnement.",
        ],
        tags: ["anti-gaspi", "économique", "végétarien"]
    )

    static let gratinDeCourgettes = Recipe(
        id: "gratin-courgettes",
        title: "Gratin de courgettes",
        emoji: "🧀",
        minutes: 45,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Courgettes", category: .vegetables, keywords: ["courgette"]),
            RecipeIngredient("Crème fraîche", category: .dairy, keywords: ["creme", "creme fraiche"]),
            RecipeIngredient("Fromage râpé", category: .cheese, keywords: ["fromage", "emmental", "gruyere", "comte"]),
            RecipeIngredient("Œufs", category: .eggs, keywords: ["oeuf", "œuf"], isOptional: true),
            sel, poivre,
        ],
        steps: [
            "Préchauffez le four à 190 °C.",
            "Coupez les courgettes en rondelles et faites-les revenir 10 minutes.",
            "Mélangez avec la crème et les œufs battus, salez, poivrez.",
            "Versez dans un plat, couvrez de fromage et enfournez 25 minutes.",
        ],
        tags: ["gratin", "végétarien"]
    )

    static let patesCremeJambon = Recipe(
        id: "pates-creme-jambon",
        title: "Pâtes à la crème et au jambon",
        emoji: "🍝",
        minutes: 15,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Pâtes", category: .pantry, keywords: ["pates", "spaghetti", "penne", "tagliatelle", "fusilli"]),
            RecipeIngredient("Crème fraîche", category: .dairy, keywords: ["creme", "creme fraiche"]),
            RecipeIngredient("Jambon", category: .deli, keywords: ["jambon", "lardon", "bacon"]),
            RecipeIngredient("Fromage râpé", category: .cheese, keywords: ["fromage", "parmesan", "emmental"], isOptional: true),
            sel, poivre,
        ],
        steps: [
            "Faites cuire les pâtes dans l'eau bouillante salée.",
            "Faites revenir le jambon coupé en lanières 3 minutes.",
            "Ajoutez la crème, laissez épaissir 2 minutes.",
            "Mélangez avec les pâtes égouttées et parsemez de fromage.",
        ],
        tags: ["rapide", "familial"]
    )

    static let pouletRotiLegumes = Recipe(
        id: "poulet-roti-legumes",
        title: "Poulet rôti aux légumes",
        emoji: "🍗",
        minutes: 60,
        difficulty: .medium,
        servings: 4,
        ingredients: [
            RecipeIngredient("Poulet", category: .poultry, keywords: ["poulet", "cuisse", "escalope", "dinde"]),
            RecipeIngredient("Pommes de terre", category: .vegetables, keywords: ["pomme de terre", "patate"]),
            RecipeIngredient("Légumes racines", category: .vegetables,
                             keywords: ["carotte", "oignon", "panais", "navet"], isOptional: true),
            huile, sel, poivre, epices,
        ],
        steps: [
            "Préchauffez le four à 200 °C.",
            "Coupez les légumes en gros morceaux, disposez-les dans un plat.",
            "Posez le poulet dessus, huilez, salez, poivrez, ajoutez les épices.",
            "Enfournez 45 à 50 minutes en arrosant à mi-cuisson.",
        ],
        tags: ["dimanche", "familial"]
    )

    static let quicheAuxRestes = Recipe(
        id: "quiche-restes",
        title: "Quiche aux restes",
        emoji: "🥧",
        minutes: 45,
        difficulty: .easy,
        servings: 4,
        ingredients: [
            RecipeIngredient("Pâte brisée", category: .pantry, keywords: ["pate brisee", "pate feuilletee", "pate a tarte"]),
            RecipeIngredient("Œufs", category: .eggs, keywords: ["oeuf", "œuf"]),
            RecipeIngredient("Crème ou lait", category: .dairy, keywords: ["creme", "lait"]),
            RecipeIngredient("Garniture (légumes, jambon, fromage)", category: .vegetables,
                             keywords: ["courgette", "poireau", "epinard", "jambon", "lardon", "champignon", "tomate", "fromage"]),
            sel, poivre,
        ],
        steps: [
            "Préchauffez le four à 180 °C et étalez la pâte dans un moule.",
            "Répartissez la garniture sur le fond de tarte.",
            "Battez les œufs avec la crème, salez, poivrez, versez sur la garniture.",
            "Enfournez 35 minutes jusqu'à ce que le dessus soit doré.",
        ],
        tags: ["anti-gaspi", "familial"]
    )

    static let saladeComposee = Recipe(
        id: "salade-composee",
        title: "Salade composée du frigo",
        emoji: "🥗",
        minutes: 10,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Salade verte", category: .vegetables, keywords: ["salade", "laitue", "roquette", "mache"]),
            RecipeIngredient("Tomates", category: .vegetables, keywords: ["tomate"], isOptional: true),
            RecipeIngredient("Fromage", category: .cheese, keywords: ["fromage", "feta", "chevre", "mozzarella"], isOptional: true),
            RecipeIngredient("Protéine (œuf, jambon, thon)", category: .other,
                             keywords: ["oeuf", "œuf", "jambon", "thon", "poulet"], isOptional: true),
            huile, sel, poivre,
        ],
        steps: [
            "Lavez et essorez la salade.",
            "Coupez les tomates, le fromage et la protéine en morceaux.",
            "Préparez une vinaigrette : huile, vinaigre, sel, poivre.",
            "Mélangez au dernier moment pour garder le croquant.",
        ],
        tags: ["rapide", "sans cuisson"]
    )

    static let ratatouille = Recipe(
        id: "ratatouille",
        title: "Ratatouille",
        emoji: "🍆",
        minutes: 50,
        difficulty: .easy,
        servings: 4,
        ingredients: [
            RecipeIngredient("Courgettes", category: .vegetables, keywords: ["courgette"]),
            RecipeIngredient("Aubergine", category: .vegetables, keywords: ["aubergine"], isOptional: true),
            RecipeIngredient("Poivrons", category: .vegetables, keywords: ["poivron"]),
            RecipeIngredient("Tomates", category: .vegetables, keywords: ["tomate"]),
            RecipeIngredient("Oignon", category: .vegetables, keywords: ["oignon"]),
            huile, sel, poivre, epices,
        ],
        steps: [
            "Coupez tous les légumes en dés réguliers.",
            "Faites revenir l'oignon, puis ajoutez les légumes un par un.",
            "Ajoutez les tomates, salez, poivrez, ajoutez les herbes.",
            "Laissez mijoter 35 minutes à couvert, à feu doux.",
        ],
        tags: ["anti-gaspi", "végétarien", "batch cooking"]
    )

    static let curryDeLegumesCoco = Recipe(
        id: "curry-legumes-coco",
        title: "Curry de légumes au lait de coco",
        emoji: "🍛",
        minutes: 30,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Légumes variés", category: .vegetables,
                             keywords: ["carotte", "courgette", "patate douce", "chou-fleur", "pomme de terre", "poivron", "epinard"]),
            RecipeIngredient("Lait de coco", category: .pantry, keywords: ["lait de coco", "coco"]),
            RecipeIngredient("Oignon", category: .vegetables, keywords: ["oignon"], isOptional: true),
            RecipeIngredient("Riz", category: .pantry, keywords: ["riz"], isOptional: true),
            huile, sel, epices,
        ],
        steps: [
            "Faites revenir l'oignon avec les épices à curry 2 minutes.",
            "Ajoutez les légumes coupés, mélangez 5 minutes.",
            "Versez le lait de coco et laissez mijoter 20 minutes.",
            "Servez avec du riz.",
        ],
        tags: ["végétarien", "réconfortant"]
    )

    static let croqueMonsieur = Recipe(
        id: "croque-monsieur",
        title: "Croque-monsieur",
        emoji: "🥪",
        minutes: 15,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Pain de mie", category: .bakery, keywords: ["pain", "pain de mie", "baguette"]),
            RecipeIngredient("Jambon", category: .deli, keywords: ["jambon"]),
            RecipeIngredient("Fromage", category: .cheese, keywords: ["fromage", "emmental", "gruyere", "comte"]),
            beurre, poivre,
        ],
        steps: [
            "Beurrez les tranches de pain sur la face extérieure.",
            "Garnissez de jambon et de fromage.",
            "Faites dorer 4 minutes de chaque côté à la poêle, ou 8 minutes au four à 200 °C.",
        ],
        tags: ["rapide", "restes"]
    )

    static let painPerdu = Recipe(
        id: "pain-perdu",
        title: "Pain perdu",
        emoji: "🍞",
        minutes: 15,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Pain rassis", category: .bakery, keywords: ["pain", "brioche", "baguette"]),
            RecipeIngredient("Œufs", category: .eggs, keywords: ["oeuf", "œuf"]),
            RecipeIngredient("Lait", category: .dairy, keywords: ["lait"]),
            sucre, beurre,
        ],
        steps: [
            "Battez les œufs avec le lait et le sucre.",
            "Trempez les tranches de pain 30 secondes de chaque côté.",
            "Faites dorer au beurre à feu moyen, 3 minutes par face.",
        ],
        tags: ["anti-gaspi", "goûter", "pain rassis"]
    )

    static let smoothieAuxFruits = Recipe(
        id: "smoothie-fruits",
        title: "Smoothie aux fruits mûrs",
        emoji: "🥤",
        minutes: 5,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Fruits mûrs", category: .fruits,
                             keywords: ["banane", "fraise", "pomme", "poire", "mangue", "peche", "kiwi", "orange", "framboise", "myrtille"]),
            RecipeIngredient("Yaourt ou lait", category: .dairy, keywords: ["yaourt", "lait", "fromage blanc"]),
            RecipeIngredient("Miel", category: .pantry, keywords: ["miel"], isOptional: true),
        ],
        steps: [
            "Coupez les fruits en morceaux.",
            "Mixez avec le yaourt ou le lait jusqu'à obtenir une texture lisse.",
            "Sucrez au miel si nécessaire et servez frais.",
        ],
        tags: ["rapide", "sans cuisson", "fruits trop mûrs"]
    )

    static let compoteDeFruits = Recipe(
        id: "compote-fruits",
        title: "Compote express",
        emoji: "🍎",
        minutes: 20,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Pommes ou poires", category: .fruits, keywords: ["pomme", "poire", "peche", "abricot", "prune"]),
            sucre,
            RecipeIngredient("Cannelle", isOptional: true, isStaple: true),
        ],
        steps: [
            "Épluchez et coupez les fruits en morceaux.",
            "Mettez-les dans une casserole avec 3 cuillères d'eau.",
            "Couvrez et laissez compoter 15 minutes à feu doux.",
            "Écrasez à la fourchette et laissez refroidir.",
        ],
        tags: ["anti-gaspi", "fruits trop mûrs"]
    )

    static let tarteAuxPommes = Recipe(
        id: "tarte-pommes",
        title: "Tarte aux pommes",
        emoji: "🥧",
        minutes: 50,
        difficulty: .medium,
        servings: 6,
        ingredients: [
            RecipeIngredient("Pommes", category: .fruits, keywords: ["pomme"]),
            RecipeIngredient("Pâte à tarte", category: .pantry, keywords: ["pate", "pate brisee", "pate feuilletee"]),
            sucre, beurre,
        ],
        steps: [
            "Préchauffez le four à 180 °C.",
            "Étalez la pâte, piquez le fond à la fourchette.",
            "Disposez les pommes en lamelles, saupoudrez de sucre.",
            "Enfournez 35 minutes.",
        ],
        tags: ["dessert", "anti-gaspi"]
    )

    static let poeleePommesDeTerreLardons = Recipe(
        id: "poelee-pdt-lardons",
        title: "Poêlée de pommes de terre aux lardons",
        emoji: "🥔",
        minutes: 30,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Pommes de terre", category: .vegetables, keywords: ["pomme de terre", "patate"]),
            RecipeIngredient("Lardons", category: .deli, keywords: ["lardon", "bacon", "jambon"]),
            RecipeIngredient("Oignon", category: .vegetables, keywords: ["oignon"], isOptional: true),
            huile, sel, poivre,
        ],
        steps: [
            "Coupez les pommes de terre en cubes et faites-les cuire 15 minutes à la poêle.",
            "Ajoutez l'oignon émincé et les lardons.",
            "Poursuivez 10 minutes jusqu'à ce que tout soit doré.",
        ],
        tags: ["rapide", "réconfortant"]
    )

    static let risottoAuxChampignons = Recipe(
        id: "risotto-champignons",
        title: "Risotto aux champignons",
        emoji: "🍄",
        minutes: 35,
        difficulty: .medium,
        ingredients: [
            RecipeIngredient("Riz", category: .pantry, keywords: ["riz", "riz arborio"]),
            RecipeIngredient("Champignons", category: .vegetables, keywords: ["champignon"]),
            RecipeIngredient("Bouillon", category: .pantry, keywords: ["bouillon", "cube"]),
            RecipeIngredient("Parmesan", category: .cheese, keywords: ["parmesan", "fromage"], isOptional: true),
            RecipeIngredient("Oignon", category: .vegetables, keywords: ["oignon"], isOptional: true),
            beurre, sel, poivre,
        ],
        steps: [
            "Faites revenir l'oignon et les champignons 5 minutes.",
            "Ajoutez le riz, nacrez 2 minutes.",
            "Versez le bouillon louche par louche en remuant, 18 minutes.",
            "Hors du feu, incorporez le beurre et le parmesan.",
        ],
        tags: ["végétarien", "réconfortant"]
    )

    static let chiliSinCarne = Recipe(
        id: "chili-sin-carne",
        title: "Chili sin carne",
        emoji: "🌶️",
        minutes: 35,
        difficulty: .easy,
        servings: 4,
        ingredients: [
            RecipeIngredient("Haricots rouges", category: .pantry, keywords: ["haricot", "haricots rouges"]),
            RecipeIngredient("Tomates", category: .vegetables, keywords: ["tomate", "coulis", "tomates concassees"]),
            RecipeIngredient("Poivrons", category: .vegetables, keywords: ["poivron"]),
            RecipeIngredient("Oignon", category: .vegetables, keywords: ["oignon"]),
            RecipeIngredient("Maïs", category: .pantry, keywords: ["mais"], isOptional: true),
            huile, sel, epices,
        ],
        steps: [
            "Faites revenir l'oignon et les poivrons 5 minutes.",
            "Ajoutez les tomates et les épices, mélangez.",
            "Incorporez les haricots égouttés et le maïs.",
            "Laissez mijoter 20 minutes à feu doux.",
        ],
        tags: ["végétarien", "batch cooking", "économique"]
    )

    static let poissonAuFour = Recipe(
        id: "poisson-four",
        title: "Poisson au four et légumes",
        emoji: "🐟",
        minutes: 30,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Poisson", category: .fish, keywords: ["poisson", "cabillaud", "saumon", "colin", "lieu", "dorade"]),
            RecipeIngredient("Légumes", category: .vegetables, keywords: ["courgette", "tomate", "poivron", "fenouil", "carotte"]),
            RecipeIngredient("Citron", category: .fruits, keywords: ["citron"], isOptional: true),
            huile, sel, poivre, epices,
        ],
        steps: [
            "Préchauffez le four à 200 °C.",
            "Disposez les légumes émincés dans un plat, huilez, salez.",
            "Posez le poisson dessus avec des rondelles de citron.",
            "Enfournez 20 minutes.",
        ],
        tags: ["léger", "rapide"]
    )

    static let velouteDeCourgettes = Recipe(
        id: "veloute-courgettes",
        title: "Velouté de courgettes",
        emoji: "🥒",
        minutes: 25,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Courgettes", category: .vegetables, keywords: ["courgette"]),
            RecipeIngredient("Fromage frais ou crème", category: .dairy, keywords: ["creme", "fromage frais", "vache qui rit"]),
            RecipeIngredient("Bouillon", category: .pantry, keywords: ["bouillon", "cube"], isOptional: true),
            RecipeIngredient("Oignon", category: .vegetables, keywords: ["oignon"], isOptional: true),
            sel, poivre,
        ],
        steps: [
            "Coupez les courgettes en rondelles sans les éplucher.",
            "Faites-les cuire 15 minutes dans le bouillon.",
            "Mixez avec le fromage frais jusqu'à obtenir un velouté lisse.",
        ],
        tags: ["végétarien", "léger"]
    )

    static let wrapsAuPoulet = Recipe(
        id: "wraps-poulet",
        title: "Wraps au poulet",
        emoji: "🌯",
        minutes: 15,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Poulet", category: .poultry, keywords: ["poulet", "escalope", "dinde"]),
            RecipeIngredient("Tortillas", category: .bakery, keywords: ["tortilla", "wrap", "galette"]),
            RecipeIngredient("Crudités", category: .vegetables, keywords: ["salade", "tomate", "carotte", "concombre", "poivron"]),
            RecipeIngredient("Sauce (yaourt, moutarde)", category: .dairy, keywords: ["yaourt", "moutarde", "sauce"], isOptional: true),
            sel, poivre,
        ],
        steps: [
            "Faites cuire le poulet coupé en lanières 8 minutes.",
            "Réchauffez les tortillas 20 secondes à la poêle.",
            "Garnissez de poulet, crudités et sauce, puis roulez serré.",
        ],
        tags: ["rapide", "à emporter"]
    )

    static let saladeDeRiz = Recipe(
        id: "salade-riz",
        title: "Salade de riz complète",
        emoji: "🍙",
        minutes: 15,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Riz cuit", category: .pantry, keywords: ["riz"]),
            RecipeIngredient("Tomates", category: .vegetables, keywords: ["tomate"], isOptional: true),
            RecipeIngredient("Thon ou œufs", category: .other, keywords: ["thon", "oeuf", "œuf", "poulet"]),
            RecipeIngredient("Maïs", category: .pantry, keywords: ["mais"], isOptional: true),
            huile, sel, poivre,
        ],
        steps: [
            "Laissez refroidir le riz cuit.",
            "Coupez les tomates, émiettez le thon ou coupez les œufs durs.",
            "Mélangez le tout avec une vinaigrette légère.",
        ],
        tags: ["rapide", "sans cuisson", "restes"]
    )

    static let gratinDauphinois = Recipe(
        id: "gratin-dauphinois",
        title: "Gratin dauphinois",
        emoji: "🥔",
        minutes: 70,
        difficulty: .medium,
        servings: 4,
        ingredients: [
            RecipeIngredient("Pommes de terre", category: .vegetables, keywords: ["pomme de terre", "patate"]),
            RecipeIngredient("Crème fraîche", category: .dairy, keywords: ["creme", "creme fraiche"]),
            RecipeIngredient("Lait", category: .dairy, keywords: ["lait"]),
            RecipeIngredient("Fromage râpé", category: .cheese, keywords: ["fromage", "gruyere", "emmental"], isOptional: true),
            beurre, sel, poivre,
        ],
        steps: [
            "Préchauffez le four à 170 °C.",
            "Coupez les pommes de terre en fines rondelles.",
            "Disposez-les en couches dans un plat beurré, salez, poivrez.",
            "Versez le mélange lait-crème et enfournez 55 minutes.",
        ],
        tags: ["familial", "réconfortant"]
    )

    static let frittataDePates = Recipe(
        id: "frittata-pates",
        title: "Frittata de pâtes (restes)",
        emoji: "🍲",
        minutes: 20,
        difficulty: .easy,
        ingredients: [
            RecipeIngredient("Pâtes cuites", category: .leftovers, keywords: ["pates", "spaghetti", "penne", "restes"]),
            RecipeIngredient("Œufs", category: .eggs, keywords: ["oeuf", "œuf"]),
            RecipeIngredient("Fromage râpé", category: .cheese, keywords: ["fromage", "parmesan", "emmental"]),
            RecipeIngredient("Légumes ou jambon", category: .vegetables,
                             keywords: ["courgette", "tomate", "jambon", "poivron", "epinard"], isOptional: true),
            huile, sel, poivre,
        ],
        steps: [
            "Battez les œufs avec le fromage, salez, poivrez.",
            "Mélangez avec les pâtes cuites et la garniture.",
            "Versez dans une poêle huilée, couvrez et cuisez 8 minutes à feu doux.",
            "Retournez et poursuivez 4 minutes.",
        ],
        tags: ["anti-gaspi", "restes", "rapide"]
    )
}
