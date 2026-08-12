import SwiftUI
import UIKit
import ExpiraCore

// MARK: - Carte

/// Grande carte, coin arrondi généreux, ombre quasi invisible.
/// C'est le conteneur de base de toute l'interface.
public struct ExpiraCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = Spacing.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ExpiraColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(ExpiraColor.separator, lineWidth: 0.5)
            )
    }
}

// MARK: - Boutons

public struct PrimaryButtonStyle: ButtonStyle {
    private let isProminent: Bool

    public init(isProminent: Bool = true) {
        self.isProminent = isProminent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ExpiraFont.headline)
            .foregroundStyle(ExpiraColor.onBrand)
            .frame(maxWidth: .infinity)
            .frame(minHeight: isProminent ? 54 : Layout.minimumTapTarget)
            .background(ExpiraColor.brand)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ExpiraFont.headline)
            .foregroundStyle(ExpiraColor.brand)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Layout.minimumTapTarget)
            .background(ExpiraColor.brandSoft)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

public struct QuietButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ExpiraFont.callout)
            .foregroundStyle(ExpiraColor.textSecondary)
            .frame(minHeight: Layout.minimumTapTarget)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Badge d'urgence

/// Le badge porte l'urgence sur **trois canaux** : icône, texte et couleur.
/// Retirer la couleur ne doit rien enlever à la compréhension — c'est la règle
/// d'accessibilité fondamentale de l'écran Frigo.
public struct UrgencyBadge: View {
    private let level: UrgencyLevel
    private let label: String
    private let isEstimated: Bool

    public init(level: UrgencyLevel, label: String, isEstimated: Bool) {
        self.level = level
        self.label = label
        self.isEstimated = isEstimated
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: level.systemImageName)
                .font(.caption2)
            Text(label)
                .font(ExpiraFont.captionEmphasized)
            if isEstimated {
                Text("· estimée")
                    .font(ExpiraFont.caption)
                    .opacity(0.75)
            }
        }
        .foregroundStyle(ExpiraColor.urgencyColor(level))
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(ExpiraColor.urgencyBackground(level))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isEstimated ? "\(label), date estimée" : label)
    }
}

// MARK: - En-tête de section

public struct SectionHeaderView: View {
    private let title: String
    private let count: Int?
    private let systemImage: String?

    public init(title: String, count: Int? = nil, systemImage: String? = nil) {
        self.title = title
        self.count = count
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: Spacing.s) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote)
                    .foregroundStyle(ExpiraColor.textSecondary)
            }
            Text(title.uppercased())
                .font(ExpiraFont.captionEmphasized)
                .kerning(0.6)
                .foregroundStyle(ExpiraColor.textSecondary)
            if let count {
                Text("\(count)")
                    .font(ExpiraFont.caption)
                    .foregroundStyle(ExpiraColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - État vide

public struct EmptyStateView: View {
    private let emoji: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        emoji: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.emoji = emoji
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.m) {
            Text(emoji)
                .font(.system(size: 52))
                .accessibilityHidden(true)
            Text(title)
                .font(ExpiraFont.title3)
                .foregroundStyle(ExpiraColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(ExpiraFont.callout)
                .foregroundStyle(ExpiraColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, Spacing.s)
                    .frame(maxWidth: 280)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tuile de statistique

public struct StatTile: View {
    private let emoji: String
    private let value: String
    private let label: String
    /// Affiché quand le chiffre est une estimation — jamais de faux précis.
    private let isEstimate: Bool

    public init(emoji: String, value: String, label: String, isEstimate: Bool = false) {
        self.emoji = emoji
        self.value = value
        self.label = label
        self.isEstimate = isEstimate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(emoji)
                .font(.title3)
                .accessibilityHidden(true)
            Text(value)
                .font(ExpiraFont.numberLarge)
                .foregroundStyle(ExpiraColor.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(isEstimate ? "\(label) (estimé)" : label)
                .font(ExpiraFont.caption)
                .foregroundStyle(ExpiraColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(ExpiraColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chargement

/// Squelette de chargement, préféré à un spinner : il montre la forme du contenu
/// à venir et rend l'attente moins longue.
public struct SkeletonBlock: View {
    private let height: CGFloat
    private let cornerRadius: CGFloat
    @State private var isAnimating = false

    public init(height: CGFloat = 16, cornerRadius: CGFloat = Radius.small) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ExpiraColor.separator)
            .frame(height: height)
            .opacity(isAnimating ? 0.45 : 0.9)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
            .accessibilityHidden(true)
    }
}

// MARK: - Bandeau d'information

public struct InfoBanner: View {
    public enum Tone {
        case info
        case warning

        var color: Color {
            switch self {
            case .info: return ExpiraColor.brand
            case .warning: return ExpiraColor.tomorrow
            }
        }

        var systemImage: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    private let tone: Tone
    private let message: String

    public init(tone: Tone = .info, message: String) {
        self.tone = tone
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: tone.systemImage)
                .font(.footnote)
                .foregroundStyle(tone.color)
            Text(message)
                .font(ExpiraFont.footnote)
                .foregroundStyle(ExpiraColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .background(tone.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }
}

// MARK: - Haptics

/// Retour haptique **uniquement** quand il apporte une information :
/// un scan reconnu, un aliment sauvé, une erreur. Jamais de vibration décorative.
public enum Haptics {
    @MainActor
    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor
    public static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    @MainActor
    public static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    @MainActor
    public static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @MainActor
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
