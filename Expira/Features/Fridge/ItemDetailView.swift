import SwiftUI
import ExpiraCore
import ExpiraDesignSystem

/// Détail d'un aliment : voir, corriger, sortir du stock.
///
/// Le bloc de date est le cœur de l'écran. Quand la date est estimée, on le dit,
/// on explique d'où vient l'estimation, et on propose immédiatement de scanner la
/// vraie date. EXPIRA ne prétend jamais savoir ce qu'elle ne sait pas.
@MainActor
struct ItemDetailView: View {
    let item: FoodItem

    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var showDateScanner = false
    @State private var showDeleteConfirmation = false

    private var current: FoodItem { app.fridge.item(withID: item.id) ?? item }
    private var urgency: UrgencyLevel { current.urgency() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    header
                    expiryCard
                    detailsCard
                    actions
                }
                .padding(Layout.screenPadding)
            }
            .background(ExpiraColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditor = true
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Supprimer sans compter", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                ItemFormView(draft: .from(item: current), mode: .edit) { updated in
                    app.fridge.update(updated)
                    Task { await app.refreshNotifications() }
                }
            }
            .sheet(isPresented: $showDateScanner) {
                DateScannerView { date in
                    var updated = current
                    updated.expiryDate = date
                    updated.expirySource = .label
                    app.fridge.update(updated)
                    Task { await app.refreshNotifications() }
                }
            }
            .confirmationDialog(
                "Supprimer cet aliment ?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    app.fridge.delete(current)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Il ne sera compté ni comme consommé, ni comme jeté.")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .fill(ExpiraColor.urgencyBackground(urgency))
                    .frame(width: 88, height: 88)
                Text(current.category.emoji)
                    .font(.system(size: 40))
            }
            .accessibilityHidden(true)

            Text(current.displayName)
                .font(ExpiraFont.title2)
                .foregroundStyle(ExpiraColor.textPrimary)
                .multilineTextAlignment(.center)

            if let brand = current.brand, !brand.isEmpty {
                Text(brand)
                    .font(ExpiraFont.callout)
                    .foregroundStyle(ExpiraColor.textSecondary)
            }

            UrgencyBadge(
                level: urgency,
                label: current.badgeLabel(),
                isEstimated: current.isEstimated
            )
        }
    }

    private var expiryCard: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Text(current.expirySource.displayName.uppercased())
                        .font(ExpiraFont.captionEmphasized)
                        .kerning(0.6)
                        .foregroundStyle(ExpiraColor.textSecondary)
                    Spacer()
                    Image(systemName: current.isEstimated ? "questionmark.circle" : "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(current.isEstimated ? ExpiraColor.tomorrow : ExpiraColor.brand)
                }

                Text(current.expiryDate.expiraLongDateString())
                    .font(ExpiraFont.title3)
                    .foregroundStyle(ExpiraColor.textPrimary)

                if current.isEstimated {
                    InfoBanner(
                        tone: .warning,
                        message: "Estimation basée sur la catégorie « \(current.category.displayName) » et une conservation « \(current.storage.displayName) ». Ce n'est pas une garantie sanitaire : fiez-vous à l'emballage et à vos sens."
                    )

                    Button {
                        scanDate()
                    } label: {
                        Label("Scanner la vraie date", systemImage: "text.viewfinder")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private var detailsCard: some View {
        ExpiraCard {
            VStack(spacing: Spacing.m) {
                DetailRow(label: "Catégorie", value: current.category.displayName)
                Divider().overlay(ExpiraColor.separator)
                DetailRow(label: "Conservation", value: current.storage.displayName)
                Divider().overlay(ExpiraColor.separator)
                DetailRow(
                    label: "Quantité",
                    value: FoodItem.formatQuantity(current.quantity, unit: current.unit)
                )
                Divider().overlay(ExpiraColor.separator)
                DetailRow(label: "Acheté le", value: current.purchaseDate.expiraShortDateString().capitalized)
                if current.isOpened {
                    Divider().overlay(ExpiraColor.separator)
                    DetailRow(label: "État", value: "Entamé")
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.s) {
            Button {
                resolve(.consumed)
            } label: {
                Label("Je l'ai consommé", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                resolve(.discarded)
            } label: {
                Label("Je l'ai jeté", systemImage: "trash")
            }
            .buttonStyle(SecondaryButtonStyle())

            Text("Marquer un aliment garde votre frigo à jour — c'est ce qui rend les alertes fiables.")
                .font(ExpiraFont.caption)
                .foregroundStyle(ExpiraColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.xs)
        }
    }

    // MARK: - Actions

    private func scanDate() {
        guard app.requirePremium(for: .dateScanner) else { return }
        showDateScanner = true
    }

    private func resolve(_ kind: HistoryEvent.Kind) {
        app.fridge.resolve(current, as: kind)
        app.analytics.track(.itemResolved(kind: kind, daysBeforeExpiry: current.daysRemaining()))
        if kind == .consumed { Haptics.success() } else { Haptics.impact(.light) }
        Task { await app.refreshNotifications() }
        dismiss()
    }
}

@MainActor
private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(ExpiraFont.callout)
                .foregroundStyle(ExpiraColor.textSecondary)
            Spacer()
            Text(value)
                .font(ExpiraFont.bodyEmphasized)
                .foregroundStyle(ExpiraColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}
#if DEBUG
#Preview("Détail — date estimée") {
    ItemDetailView(item: SampleData.urgentItem)
        .environment(AppEnvironment.preview())
}

#Preview("Détail — date lue sur l'emballage") {
    ItemDetailView(
        item: SampleData.item("Blanc de poulet", brand: "Le Gaulois", category: .poultry,
                              expiresIn: 0, source: .label, quantity: 400, unit: .gram)
    )
    .environment(AppEnvironment.preview())
}
#endif
