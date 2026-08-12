import SwiftUI
import ExpiraCore
import ExpiraDesignSystem

/// Détail d'une recette.
///
/// Le vrai bouton de cet écran n'est pas « lire la recette », c'est
/// **« J'ai cuisiné ça »** : il sort trois à cinq aliments du stock d'un seul
/// geste. C'est le mécanisme qui empêche les données de dériver.
@MainActor
struct RecipeDetailView: View {
    let match: RecipeMatch

    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showCookedSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header
                    ingredientsCard
                    stepsCard
                }
                .padding(Layout.screenPadding)
            }
            .background(ExpiraColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    showCookedSheet = true
                } label: {
                    Label("J'ai cuisiné ça", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(Layout.screenPadding)
                .background(.bar)
            }
            .sheet(isPresented: $showCookedSheet) {
                CookedConfirmationView(match: match) { dismiss() }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(match.recipe.emoji)
                .font(.system(size: 56))
                .accessibilityHidden(true)
            Text(match.recipe.title)
                .font(ExpiraFont.title)
                .foregroundStyle(ExpiraColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.m) {
                MetaChip(systemImage: "clock", text: match.recipe.durationLabel)
                MetaChip(systemImage: "chart.bar", text: match.recipe.difficulty.displayName)
                MetaChip(systemImage: "person.2", text: "\(match.recipe.servings) pers.")
            }

            Label(match.savingsLabel, systemImage: "leaf.fill")
                .font(ExpiraFont.captionEmphasized)
                .foregroundStyle(ExpiraColor.brand)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .background(ExpiraColor.brandSoft, in: Capsule())
        }
    }

    private var ingredientsCard: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                let owned = match.availableIngredients
                let missing = match.missingIngredients.filter { !$0.isOptional }
                let optional = match.missingIngredients.filter { $0.isOptional }

                if !owned.isEmpty {
                    SectionHeaderView(title: "Vous avez", count: owned.count, systemImage: "checkmark.circle.fill")
                    ForEach(owned) { ingredient in
                        IngredientRow(name: ingredient.name, isAvailable: true)
                    }
                }

                if !missing.isEmpty {
                    SectionHeaderView(title: "Il vous manque", count: missing.count, systemImage: "cart")
                        .padding(.top, Spacing.s)
                    ForEach(missing) { ingredient in
                        IngredientRow(name: ingredient.name, isAvailable: false)
                    }
                }

                if !optional.isEmpty {
                    Text("Facultatif : \(optional.map(\.name).joined(separator: ", "))")
                        .font(ExpiraFont.caption)
                        .foregroundStyle(ExpiraColor.textTertiary)
                        .padding(.top, Spacing.xs)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var stepsCard: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeaderView(title: "Préparation")
                ForEach(Array(match.recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Spacing.m) {
                        Text("\(index + 1)")
                            .font(ExpiraFont.captionEmphasized)
                            .foregroundStyle(ExpiraColor.onBrand)
                            .frame(width: 24, height: 24)
                            .background(ExpiraColor.brand, in: Circle())
                        Text(step)
                            .font(ExpiraFont.body)
                            .foregroundStyle(ExpiraColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Confirmation « J'ai cuisiné ça »

/// Sortie de stock groupée, avec cases décochables.
///
/// On ne retire jamais un aliment sans montrer lequel : l'utilisateur peut avoir
/// utilisé la moitié du poulet. Le stock doit rester **son** stock.
@MainActor
private struct CookedConfirmationView: View {
    let match: RecipeMatch
    let onDone: () -> Void

    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID>

    init(match: RecipeMatch, onDone: @escaping () -> Void) {
        self.match = match
        self.onDone = onDone
        _selectedIDs = State(initialValue: Set(match.matchedItems.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Text("Quels aliments avez-vous utilisés ?")
                        .font(ExpiraFont.title3)
                        .foregroundStyle(ExpiraColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Ils seront marqués comme consommés et sortiront de votre frigo.")
                        .font(ExpiraFont.callout)
                        .foregroundStyle(ExpiraColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ExpiraCard {
                        VStack(spacing: Spacing.s) {
                            ForEach(match.matchedItems) { item in
                                Button {
                                    Haptics.selection()
                                    if selectedIDs.contains(item.id) {
                                        selectedIDs.remove(item.id)
                                    } else {
                                        selectedIDs.insert(item.id)
                                    }
                                } label: {
                                    HStack(spacing: Spacing.m) {
                                        Image(systemName: selectedIDs.contains(item.id)
                                            ? "checkmark.square.fill"
                                            : "square")
                                            .foregroundStyle(selectedIDs.contains(item.id)
                                                ? ExpiraColor.brand
                                                : ExpiraColor.textTertiary)
                                        Text("\(item.category.emoji) \(item.displayName)")
                                            .font(ExpiraFont.body)
                                            .foregroundStyle(ExpiraColor.textPrimary)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: Layout.minimumTapTarget)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedIDs.contains(item.id) ? [.isSelected] : [])
                            }
                        }
                    }
                }
                .padding(Layout.screenPadding)
            }
            .background(ExpiraColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(confirmTitle, action: confirm)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedIDs.isEmpty)
                    .opacity(selectedIDs.isEmpty ? 0.5 : 1)
                    .padding(Layout.screenPadding)
                    .background(.bar)
            }
        }
    }

    private var confirmTitle: String {
        switch selectedIDs.count {
        case 0: return "Sélectionnez un aliment"
        case 1: return "Marquer 1 aliment consommé"
        default: return "Marquer \(selectedIDs.count) aliments consommés"
        }
    }

    private func confirm() {
        let items = match.matchedItems.filter { selectedIDs.contains($0.id) }
        guard !items.isEmpty else { return }
        app.fridge.resolve(items, as: .consumed)
        app.analytics.track(.recipeCooked(id: match.recipe.id, itemsSaved: items.count))
        for item in items {
            app.analytics.track(.itemResolved(kind: .consumed, daysBeforeExpiry: item.daysRemaining()))
        }
        Haptics.success()
        Task { await app.refreshNotifications() }
        dismiss()
        onDone()
    }
}

@MainActor
private struct MetaChip: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(ExpiraFont.caption)
            .foregroundStyle(ExpiraColor.textSecondary)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(ExpiraColor.surfaceElevated, in: Capsule())
    }
}

@MainActor
private struct IngredientRow: View {
    let name: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "circle.dashed")
                .font(.footnote)
                .foregroundStyle(isAvailable ? ExpiraColor.brand : ExpiraColor.textTertiary)
            Text(name)
                .font(ExpiraFont.callout)
                .foregroundStyle(isAvailable ? ExpiraColor.textPrimary : ExpiraColor.textSecondary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isAvailable ? "\(name), disponible" : "\(name), manquant")
    }
}
\n
#if DEBUG
#Preview("Détail recette") {
    let environment = AppEnvironment.preview()
    if let match = SampleData.recipeMatch {
        RecipeDetailView(match: match)
            .environment(environment)
    } else {
        Text("Aucune recette ne correspond au jeu de démonstration.")
    }
}
#endif
