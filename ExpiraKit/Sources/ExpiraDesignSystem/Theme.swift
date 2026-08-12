import SwiftUI
import UIKit
import ExpiraCore

// MARK: - Couleurs

public extension Color {
    /// Couleur adaptative clair/sombre, définie une seule fois.
    /// Le dark mode n'est pas une option ajoutée après coup : chaque couleur du
    /// produit est déclarée dans les deux modes dès sa création.
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

/// Palette EXPIRA — chaleureuse et sobre.
///
/// Un vert profond comme couleur de marque (fraîcheur, aliment sain), des fonds
/// crème plutôt que blancs purs (moins clinique, plus « cuisine »), et des
/// couleurs d'alerte lisibles sans être criardes.
public enum ExpiraColor {
    // Marque
    public static let brand = Color(
        light: UIColor(red: 0.05, green: 0.45, blue: 0.33, alpha: 1),
        dark: UIColor(red: 0.29, green: 0.83, blue: 0.62, alpha: 1)
    )
    public static let brandSoft = Color(
        light: UIColor(red: 0.90, green: 0.96, blue: 0.93, alpha: 1),
        dark: UIColor(red: 0.09, green: 0.20, blue: 0.16, alpha: 1)
    )
    public static let onBrand = Color(
        light: UIColor.white,
        dark: UIColor(red: 0.03, green: 0.10, blue: 0.08, alpha: 1)
    )

    // Fonds
    public static let background = Color(
        light: UIColor(red: 0.98, green: 0.97, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.05, green: 0.06, blue: 0.07, alpha: 1)
    )
    public static let surface = Color(
        light: UIColor.white,
        dark: UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1)
    )
    public static let surfaceElevated = Color(
        light: UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.14, green: 0.15, blue: 0.16, alpha: 1)
    )
    public static let separator = Color(
        light: UIColor(white: 0.0, alpha: 0.08),
        dark: UIColor(white: 1.0, alpha: 0.10)
    )

    // Texte
    public static let textPrimary = Color(
        light: UIColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.96, blue: 0.95, alpha: 1)
    )
    public static let textSecondary = Color(
        light: UIColor(red: 0.36, green: 0.38, blue: 0.40, alpha: 1),
        dark: UIColor(red: 0.68, green: 0.70, blue: 0.71, alpha: 1)
    )
    public static let textTertiary = Color(
        light: UIColor(red: 0.55, green: 0.57, blue: 0.59, alpha: 1),
        dark: UIColor(red: 0.50, green: 0.52, blue: 0.54, alpha: 1)
    )

    // Urgence — toujours accompagnées d'un texte et d'une icône.
    public static let expired = Color(
        light: UIColor(red: 0.72, green: 0.16, blue: 0.13, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.45, blue: 0.40, alpha: 1)
    )
    public static let today = Color(
        light: UIColor(red: 0.82, green: 0.34, blue: 0.05, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.62, blue: 0.35, alpha: 1)
    )
    public static let tomorrow = Color(
        light: UIColor(red: 0.66, green: 0.46, blue: 0.03, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.80, blue: 0.35, alpha: 1)
    )
    public static let success = brand
    public static let neutral = textTertiary

    public static func urgencyColor(_ level: UrgencyLevel) -> Color {
        switch level {
        case .expired: return expired
        case .today: return today
        case .tomorrow: return tomorrow
        case .thisWeek: return brand
        case .later: return neutral
        }
    }

    /// Fond du badge : la même teinte, très désaturée, pour rester lisible en
    /// Dynamic Type XXL comme en dark mode.
    public static func urgencyBackground(_ level: UrgencyLevel) -> Color {
        urgencyColor(level).opacity(0.12)
    }
}

// MARK: - Typographie

/// Toutes les tailles passent par les styles système : Dynamic Type fonctionne
/// automatiquement, y compris aux tailles d'accessibilité.
public enum ExpiraFont {
    public static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    public static let title = Font.system(.title, design: .rounded, weight: .bold)
    public static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
    public static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)
    public static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    public static let body = Font.system(.body)
    public static let bodyEmphasized = Font.system(.body, weight: .medium)
    public static let callout = Font.system(.callout)
    public static let subheadline = Font.system(.subheadline)
    public static let footnote = Font.system(.footnote)
    public static let caption = Font.system(.caption)
    public static let captionEmphasized = Font.system(.caption, weight: .semibold)
    public static let numberLarge = Font.system(.title, design: .rounded, weight: .bold).monospacedDigit()
}

// MARK: - Métriques

public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
}

public enum Radius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 14
    public static let large: CGFloat = 20
    public static let pill: CGFloat = 999
}

public enum Layout {
    /// Taille de cible minimale recommandée par Apple. Utilisée notamment pour
    /// la croix de fermeture du paywall.
    public static let minimumTapTarget: CGFloat = 44
    public static let screenPadding: CGFloat = 20
}
