import SwiftUI
import ExpiraCore
import ExpiraDesignSystem

/// Une ligne de la liste du frigo.
///
/// Accessibilité : l'urgence est lisible sans couleur (icône + texte du badge),
/// et la ligne entière expose un seul élément VoiceOver, lu comme une phrase.
@MainActor
struct FoodItemRow: View {
    let item: FoodItem
    let asOf: Date

    private var urgency: UrgencyLevel { item.urgency(asOf: asOf) }

    var body: some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(ExpiraColor.urgencyBackground(urgency))
                    .frame(width: 48, height: 48)
                Text(item.category.emoji)
                    .font(.title3)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.displayName)
                    .font(ExpiraFont.bodyEmphasized)
                    .foregroundStyle(ExpiraColor.textPrimary)
                    .lineLimit(1)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(ExpiraFont.caption)
                        .foregroundStyle(ExpiraColor.textTertiary)
                        .lineLimit(1)
                }

                UrgencyBadge(
                    level: urgency,
                    label: item.badgeLabel(asOf: asOf),
                    isEstimated: item.isEstimated
                )
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(ExpiraColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(Spacing.m)
        .background(ExpiraColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(ExpiraColor.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Toucher pour voir le détail. Balayer pour marquer consommé ou jeté.")
    }

    private var accessibilityDescription: String {
        var parts: [String] = [item.displayName]
        if let brand = item.brand, !brand.isEmpty { parts.append(brand) }
        parts.append(item.category.displayName)
        parts.append(item.badgeLabel(asOf: asOf))
        if item.isEstimated { parts.append("date estimée") }
        return parts.joined(separator: ", ")
    }
}
