import Foundation

/// Normalisation de texte partagée par le moteur de recettes et le classement
/// de catégories. Sans accents, sans casse, sans ponctuation.
public enum TextNormalizer {
    private static let frenchLocale = Locale(identifier: "fr_FR")

    public static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: frenchLocale)
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func tokens(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init)
    }

    /// Le mot-clé `keyword` désigne-t-il l'aliment `subject` ?
    ///
    /// Règle volontairement conservatrice : on préfère rater un rapprochement
    /// plutôt que proposer une recette absurde. Un faux positif détruit la
    /// confiance dans la fonctionnalité recette bien plus vite qu'un oubli.
    public static func matches(subject: String, keyword: String) -> Bool {
        let normalizedKeyword = normalize(keyword)
        guard !normalizedKeyword.isEmpty else { return false }
        let normalizedSubject = normalize(subject)
        guard !normalizedSubject.isEmpty else { return false }

        // Mot-clé composé (« creme fraiche ») : recherche de sous-chaîne.
        if normalizedKeyword.contains(" ") {
            return normalizedSubject.contains(normalizedKeyword)
        }

        for token in normalizedSubject.split(separator: " ").map(String.init) {
            if token == normalizedKeyword { return true }
            // Pluriels et dérivés : « tomates » ↔ « tomate », « poulets ».
            if normalizedKeyword.count >= 4, token.hasPrefix(normalizedKeyword) { return true }
            if token.count >= 4, normalizedKeyword.hasPrefix(token) { return true }
        }
        return false
    }
}
