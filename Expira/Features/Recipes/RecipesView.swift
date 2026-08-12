import SwiftUI
import ExpiraCore
import ExpiraCatalog
import ExpiraDesignSystem

/// Recettes anti-gaspillage.
///
/// L'écran ne présente pas « des recettes » : il présente **des recettes qui
/// sauvent ce qui va périmer**. C'est pour cela que chaque carte affiche
/// « Sauve 3 aliments » avant d'afficher le temps de préparation.
@MainActor
struct RecipesView: View {
    @Environment(AppEnvironment.self) private var app
    @State private var selectedRecipe: RecipeMatch?

    private var matches: [RecipeMatch] {
        let limit = app.isPremium ? 12 : FreeTierLimits.weeklyRecipeViews
        return app.matcher.matches(
            recipes: RecipeCatalog.all,
            items: app.fridge.activeItems,
            limit: limit
        )
    }

    private var priorityItems: [FoodItem] {
        Array(
            app.fridge.activeItems
                .filter { $0.urgency() <= .thisWeek }
                .sortedByUrgency()
                .prefix(6)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if app.fridge.activeItems.isEmpty {
                    EmptyStateView(
                        emoji: "🍳",
                        title: "Ajoutez des aliments",
                        message: "Dès que votre frigo contient quelque chose, Expira vous propose des recettes pour l'utiliser avant qu'il ne périme."
                    )
                } else if matches.isEmpty {
                    EmptyStateView(
                        emoji: "🥄",
                        title: "Aucune recette pour l'instant",
                        message: "Nos recettes se basent sur les aliments de votre frigo. Ajoutez quelques produits frais et revenez."
                    )
                } else {
                    content
                }
            }
            .background(ExpiraColor.background)
            .navigationTitle("Recettes")
            .sheet(item: $selectedRecipe) { match in
                RecipeDetailView(match: match)
            }
            .onAppear { app.analytics.track(.recipeListViewed) }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if !priorityItems.isEmpty {
                    priorityStrip
                }

                SectionHeaderView(title: "Recettes suggérées")

                ForEach(matches) { match in
                    Button {
                        app.analytics.track(.recipeOpened(id: match.recipe.id))
                        selectedRecipe = match
                    } label: {
                        RecipeCard(match: match)
                    }
                    .buttonStyle(.plain)
                }

                if !app.isPremium {
                    Button {
                        app.presentPaywall(.recipes)
                    } label: {
                        InfoBanner(
                            message: "La version gratuite propose \(FreeTierLimits.weeklyRecipeViews) recettes. Premium les débloque toutes."
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Layout.screenPadding)
        }
    }

    private var priorityStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeaderView(title: "À utiliser en priorité", systemImage: "exclamationmark.triangle.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(priorityItems) { item in
                        HStack(spacing: Spacing.xs) {
                            Text(item.category.emoji)
                            Text(item.displayName)
                                .font(ExpiraFont.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
                        .background(ExpiraColor.urgencyBackground(item.urgency()), in: Capsule())
                        .foregroundStyle(ExpiraColor.urgencyColor(item.urgency()))
                        .accessibilityLabel("\(item.displayName), \(item.badgeLabel())")
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

// MARK: - Carte recette

@MainActor
struct RecipeCard: View {
    let match: RecipeMatch

    var body: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(spacing: Spacing.m) {
                    Text(match.recipe.emoji)
                        .font(.system(size: 34))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(match.recipe.title)
                            .font(ExpiraFont.headline)
                            .foregroundStyle(ExpiraColor.textPrimary)
                            .lineLimit(2)
                        Text("\(match.recipe.durationLabel) · \(match.recipe.difficulty.displayName)")
                            .font(ExpiraFont.caption)
                            .foregroundStyle(ExpiraColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                // L'argument principal, avant tout le reste.
                Label(match.savingsLabel, systemImage: "leaf.fill")
                    .font(ExpiraFont.captionEmphasized)
                    .foregroundStyle(ExpiraColor.brand)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xs)
                    .background(ExpiraColor.brandSoft, in: Capsule())

                HStack(spacing: Spacing.m) {
                    Label(match.coverageLabel, systemImage: "checkmark.circle")
                        .font(ExpiraFont.caption)
                        .foregroundStyle(ExpiraColor.textSecondary)

                    if !match.missingIngredients.filter({ !$0.isOptional }).isEmpty {
                        Label(
                            "\(match.missingIngredients.filter { !$0.isOptional }.count) manquant\(match.missingIngredients.filter { !$0.isOptional }.count > 1 ? "s" : "")",
                            systemImage: "cart"
                        )
                        .font(ExpiraFont.caption)
                        .foregroundStyle(ExpiraColor.textTertiary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
\n
#if DEBUG
#Preview("Recettes") {
    RecipesView()
        .environment(AppEnvironment.preview())
}

#Preview("Recettes — frigo vide") {
    RecipesView()
        .environment(AppEnvironment.previewEmpty())
}
#endif
