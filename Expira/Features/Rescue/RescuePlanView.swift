import SwiftUI
import ExpiraCore
import ExpiraCatalog
import ExpiraDesignSystem

/// « Sauver mes aliments » — la fonctionnalité qui donne une raison de revenir.
///
/// L'utilisateur appuie sur un bouton et obtient un plan concret sur trois jours.
/// Aucune saisie, aucun choix à faire : c'est l'app qui décide, il n'a qu'à
/// cuisiner. C'est exactement l'inverse d'une liste de recettes à parcourir.
@MainActor
struct RescuePlanView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var plan: RescuePlan?
    @State private var excludedRecipeIDs: Set<String> = []
    @State private var selectedMatch: RecipeMatch?
    @State private var isGenerating = true

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    generatingState
                } else if let plan, !plan.isEmpty {
                    content(for: plan)
                } else {
                    EmptyStateView(
                        emoji: "🎉",
                        title: "Rien à sauver",
                        message: "Aucun aliment n'arrive à expiration dans les 7 prochains jours. Revenez après vos prochaines courses."
                    )
                }
            }
            .background(ExpiraColor.background)
            .navigationTitle("Sauver mes aliments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $selectedMatch) { match in
                RecipeDetailView(match: match)
            }
            .task { await generate() }
        }
    }

    // MARK: - États

    private var generatingState: some View {
        VStack(spacing: Spacing.l) {
            ForEach(0..<3, id: \.self) { _ in
                ExpiraCard {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        SkeletonBlock(height: 12)
                            .frame(width: 90)
                        SkeletonBlock(height: 20)
                        SkeletonBlock(height: 12)
                            .frame(width: 140)
                    }
                }
            }
            Spacer()
        }
        .padding(Layout.screenPadding)
        .accessibilityLabel("Analyse de votre frigo en cours")
    }

    private func content(for plan: RescuePlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Voici ce que vous devriez utiliser en premier.")
                        .font(ExpiraFont.title3)
                        .foregroundStyle(ExpiraColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(plan.itemsAtRisk.count) aliment\(plan.itemsAtRisk.count > 1 ? "s" : "") arrive\(plan.itemsAtRisk.count > 1 ? "nt" : "") à expiration cette semaine.")
                        .font(ExpiraFont.callout)
                        .foregroundStyle(ExpiraColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(plan.days) { day in
                    PlanDayCard(day: day, onOpenRecipe: open(recipe:))
                }

                summaryCard(for: plan)

                Button {
                    regenerate()
                } label: {
                    Label("Proposer un autre plan", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Layout.screenPadding)
        }
    }

    private func summaryCard(for plan: RescuePlan) -> some View {
        ExpiraCard {
            HStack(spacing: Spacing.l) {
                StatTile(
                    emoji: "🥦",
                    value: "\(plan.totalItemsSaved)",
                    label: plan.totalItemsSaved > 1 ? "aliments sauvés" : "aliment sauvé"
                )
                StatTile(
                    emoji: "💰",
                    value: plan.estimatedSavingsEUR.expiraEuroString,
                    label: "économisés",
                    isEstimate: true
                )
            }
        }
    }

    // MARK: - Actions

    private func generate() {
        isGenerating = true
        let newPlan = app.rescuePlanner.makePlan(
            items: app.fridge.activeItems,
            recipes: RecipeCatalog.all,
            dayCount: 3,
            excludedRecipeIDs: excludedRecipeIDs
        )
        plan = newPlan
        isGenerating = false

        if !newPlan.isEmpty {
            app.preferences.rescuePlansUsed += 1
            app.analytics.track(
                .rescuePlanGenerated(itemsAtRisk: newPlan.itemsAtRisk.count, daysPlanned: newPlan.days.count)
            )
        }
    }

    private func regenerate() {
        // On écarte les recettes déjà proposées : « un autre plan » doit
        // réellement proposer autre chose.
        excludedRecipeIDs.formUnion(plan?.days.compactMap { $0.recipe?.id } ?? [])
        Haptics.impact(.light)
        generate()
        if plan?.isEmpty == true, !excludedRecipeIDs.isEmpty {
            // Plus rien d'inédit : on repart du catalogue complet.
            excludedRecipeIDs.removeAll()
            generate()
        }
    }

    private func open(recipe: Recipe) {
        guard let match = app.matcher.evaluate(recipe: recipe, against: app.fridge.activeItems) else { return }
        app.analytics.track(.recipeOpened(id: recipe.id))
        selectedMatch = match
    }
}

// MARK: - Carte d'une journée

@MainActor
private struct PlanDayCard: View {
    let day: RescuePlanDay
    let onOpenRecipe: (Recipe) -> Void

    var body: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(day.title.uppercased())
                    .font(ExpiraFont.captionEmphasized)
                    .kerning(0.6)
                    .foregroundStyle(ExpiraColor.textSecondary)

                if let recipe = day.recipe {
                    Button {
                        onOpenRecipe(recipe)
                    } label: {
                        HStack(spacing: Spacing.m) {
                            Text(recipe.emoji)
                                .font(.system(size: 32))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipe.title)
                                    .font(ExpiraFont.headline)
                                    .foregroundStyle(ExpiraColor.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text("\(recipe.durationLabel) · \(recipe.difficulty.displayName)")
                                    .font(ExpiraFont.caption)
                                    .foregroundStyle(ExpiraColor.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(ExpiraColor.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(day.suggestion)
                        .font(ExpiraFont.body)
                        .foregroundStyle(ExpiraColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().overlay(ExpiraColor.separator)

                HStack(spacing: Spacing.s) {
                    ForEach(day.items) { item in
                        Text("\(item.category.emoji) \(item.displayName)")
                            .font(ExpiraFont.caption)
                            .lineLimit(1)
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, Spacing.xs)
                            .background(ExpiraColor.brandSoft, in: Capsule())
                            .foregroundStyle(ExpiraColor.brand)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(day.title) : \(day.suggestion)")
    }
}
#if DEBUG
#Preview("Plan de sauvetage") {
    RescuePlanView()
        .environment(AppEnvironment.preview())
}

#Preview("Rien à sauver") {
    RescuePlanView()
        .environment(AppEnvironment.previewEmpty())
}
#endif
