import Foundation

/// Fonctionnalités réservées à EXPIRA Premium.
///
/// Décision produit : **le scan de code-barres reste gratuit**. C'est le moment
/// « aha » du produit ; le verrouiller détruirait l'activation, donc la base
/// d'utilisateurs à convertir. On monétise l'usage intensif, pas la découverte.
public enum PremiumFeature: String, CaseIterable, Sendable, Hashable {
    case unlimitedItems
    case dateScanner
    case receiptScanner
    case rescuePlanner
    case unlimitedRecipes
    case fullHistory
    case familySharing

    public var displayName: String {
        switch self {
        case .unlimitedItems: return "Aliments illimités"
        case .dateScanner: return "Scan de la date de péremption"
        case .receiptScanner: return "Scan de ticket de caisse"
        case .rescuePlanner: return "Plan « Sauver mes aliments »"
        case .unlimitedRecipes: return "Recettes illimitées"
        case .fullHistory: return "Historique et bilan complets"
        case .familySharing: return "Frigo partagé"
        }
    }

    public var explanation: String {
        switch self {
        case .unlimitedItems: return "Suivez tout votre frigo, sans limite de \(FreeTierLimits.maxActiveItems) aliments."
        case .dateScanner: return "Photographiez la date sur l'emballage : elle remplace l'estimation."
        case .receiptScanner: return "Photographiez votre ticket et ajoutez vos courses d'un coup."
        case .rescuePlanner: return "Un plan sur 3 jours pour ne rien laisser périmer."
        case .unlimitedRecipes: return "Toutes les recettes anti-gaspi, à volonté."
        case .fullHistory: return "Vos économies et votre historique mois par mois."
        case .familySharing: return "Un frigo commun avec votre famille ou vos colocataires."
        }
    }

    public var systemImageName: String {
        switch self {
        case .unlimitedItems: return "infinity"
        case .dateScanner: return "text.viewfinder"
        case .receiptScanner: return "doc.text.viewfinder"
        case .rescuePlanner: return "sparkles"
        case .unlimitedRecipes: return "fork.knife"
        case .fullHistory: return "chart.line.uptrend.xyaxis"
        case .familySharing: return "person.2.fill"
        }
    }

    /// Fonctionnalités déjà livrées en V1 (les autres sont annoncées comme à venir).
    public var isAvailableInV1: Bool {
        switch self {
        case .receiptScanner, .familySharing: return false
        default: return true
        }
    }
}

/// Limites de la version gratuite. Généreuses par choix : une app gratuite
/// inutilisable ne convertit personne, elle se fait désinstaller.
public enum FreeTierLimits {
    public static let maxActiveItems = 15
    public static let weeklyRecipeViews = 3
    public static let historyDays = 7
    /// Un essai offert du plan de sauvetage : on montre la valeur avant de la vendre.
    public static let freeRescuePlans = 1
}

/// Origine de l'ouverture du paywall. Sert à mesurer quel déclencheur convertit —
/// et donc où placer la valeur.
public enum PaywallTrigger: String, Sendable, Hashable, CaseIterable {
    case itemLimit
    case dateScanner
    case receiptScanner
    case rescuePlanner
    case statistics
    case settings
    case recipes

    public var headline: String {
        switch self {
        case .itemLimit: return "Votre frigo est plus grand que ça"
        case .dateScanner: return "Lisez la date, ne la devinez plus"
        case .receiptScanner: return "Vos courses ajoutées en une photo"
        case .rescuePlanner: return "Un plan pour ne rien jeter"
        case .statistics: return "Voyez ce que vous économisez"
        case .settings: return "Passez à Expira Premium"
        case .recipes: return "Toutes les recettes anti-gaspi"
        }
    }

    public var subheadline: String {
        switch self {
        case .itemLimit:
            return "La version gratuite suit \(FreeTierLimits.maxActiveItems) aliments. Premium les suit tous."
        case .dateScanner:
            return "Photographiez la date imprimée sur l'emballage : plus fiable qu'une estimation."
        case .receiptScanner:
            return "Une photo de ticket, et tous vos produits sont ajoutés."
        case .rescuePlanner:
            return "Expira analyse votre frigo et vous dit quoi cuisiner, jour par jour."
        case .statistics:
            return "Aliments sauvés, argent économisé, évolution mois par mois."
        case .settings:
            return "Tout Expira, sans limite."
        case .recipes:
            return "Des recettes choisies pour sauver ce qui expire en premier."
        }
    }

    public var highlightedFeature: PremiumFeature? {
        switch self {
        case .itemLimit: return .unlimitedItems
        case .dateScanner: return .dateScanner
        case .receiptScanner: return .receiptScanner
        case .rescuePlanner: return .rescuePlanner
        case .statistics: return .fullHistory
        case .recipes: return .unlimitedRecipes
        case .settings: return nil
        }
    }
}
