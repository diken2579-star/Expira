import Foundation

/// Liens légaux, requis par l'App Store pour tout abonnement.
/// À remplacer par les URL réelles avant la soumission.
enum LegalLinks {
    static let terms = URL(string: "https://expira.app/cgu")
    static let privacy = URL(string: "https://expira.app/confidentialite")
    static let support = URL(string: "https://expira.app/aide")
    /// Raccourci système vers la gestion des abonnements.
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")
}
