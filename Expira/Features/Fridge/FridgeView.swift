import SwiftUI
import ExpiraCore
import ExpiraDesignSystem

/// Écran principal : le stock, trié par urgence.
///
/// Trois choses doivent être visibles sans scroller : ce qui expire aujourd'hui,
/// le bouton « Sauver mes aliments », et le moyen d'ajouter un produit. Tout le
/// reste est secondaire.
@MainActor
struct FridgeView: View {
    @Environment(AppEnvironment.self) private var app

    @State private var addRoute: AddItemRoute?
    @State private var showAddOptions = false
    @State private var showRescuePlan = false
    @State private var selectedItem: FoodItem?
    @State private var lastResolved: (item: FoodItem, kind: HistoryEvent.Kind)?

    private var now: Date { Date() }

    private var sections: [(level: UrgencyLevel, items: [FoodItem])] {
        UrgencyLevel.allCases.compactMap { level in
            let items = app.fridge.items(in: level, asOf: now)
            return items.isEmpty ? nil : (level, items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if app.fridge.activeItems.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(ExpiraColor.background)
            .navigationTitle("Mon frigo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        requestAdd()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .accessibilityLabel("Ajouter un aliment")
                }
            }
            .confirmationDialog("Ajouter un aliment", isPresented: $showAddOptions, titleVisibility: .visible) {
                Button("Scanner un produit") { addRoute = .barcode }
                Button("Ajouter manuellement") { addRoute = .manual }
                Button("Annuler", role: .cancel) {}
            }
            .fullScreenCover(item: $addRoute) { route in
                AddItemFlowView(route: route) { _ in addRoute = nil }
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
            .sheet(isPresented: $showRescuePlan) {
                RescuePlanView()
            }
        }
    }

    // MARK: - Contenu

    private var content: some View {
        List {
            Section {
                headerCard
                rescueButton
                if let warning = app.fridge.persistenceWarning {
                    InfoBanner(tone: .warning, message: warning)
                }
                if app.isUsingTemporaryStorage {
                    InfoBanner(
                        tone: .warning,
                        message: "Stockage temporaire : vos aliments ne seront pas conservés à la fermeture de l'app. Redémarrez votre iPhone pour rétablir la sauvegarde."
                    )
                }
                freeTierNotice
            }
            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Layout.screenPadding, bottom: Spacing.xs, trailing: Layout.screenPadding))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(sections, id: \.level) { section in
                Section {
                    ForEach(section.items) { item in
                        FoodItemRow(item: item, asOf: now)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedItem = item }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    resolve(item, as: .consumed)
                                } label: {
                                    Label("Consommé", systemImage: "checkmark")
                                }
                                .tint(ExpiraColor.brand)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    resolve(item, as: .discarded)
                                } label: {
                                    Label("Jeté", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    SectionHeaderView(
                        title: section.level.sectionTitle,
                        count: section.items.count,
                        systemImage: section.level.systemImageName
                    )
                    .textCase(nil)
                }
                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Layout.screenPadding, bottom: Spacing.xs, trailing: Layout.screenPadding))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Color.clear
                .frame(height: Spacing.xxl)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { app.fridge.reload() }
        .overlay(alignment: .bottom) { undoBanner }
    }

    private var headerCard: some View {
        HStack(spacing: Spacing.m) {
            let streak = app.insights.wasteFreeStreak(
                events: app.fridge.events,
                firstUseDate: app.preferences.firstUseDate
            )
            let urgent = app.fridge.urgentItems(asOf: now).count

            if streak > 0 {
                Label("\(streak) j sans gaspillage", systemImage: "flame.fill")
                    .font(ExpiraFont.captionEmphasized)
                    .foregroundStyle(ExpiraColor.brand)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(ExpiraColor.brandSoft, in: Capsule())
            }

            if urgent > 0 {
                Label(
                    urgent == 1 ? "1 aliment urgent" : "\(urgent) aliments urgents",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(ExpiraFont.captionEmphasized)
                .foregroundStyle(ExpiraColor.today)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .background(ExpiraColor.urgencyBackground(.today), in: Capsule())
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, Spacing.xs)
    }

    private var rescueButton: some View {
        Button {
            openRescuePlan()
        } label: {
            HStack(spacing: Spacing.m) {
                Text("✨")
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sauver mes aliments")
                        .font(ExpiraFont.headline)
                        .foregroundStyle(ExpiraColor.onBrand)
                    Text("Un plan sur 3 jours à partir de votre frigo")
                        .font(ExpiraFont.caption)
                        .foregroundStyle(ExpiraColor.onBrand.opacity(0.85))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(ExpiraColor.onBrand.opacity(0.7))
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ExpiraColor.brand)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.bottom, Spacing.s)
    }

    @ViewBuilder
    private var freeTierNotice: some View {
        let remaining = app.fridge.remainingFreeSlots()
        if !app.isPremium, remaining <= 3 {
            Button {
                app.presentPaywall(.itemLimit)
            } label: {
                InfoBanner(
                    message: remaining == 0
                        ? "Vous suivez \(FreeTierLimits.maxActiveItems) aliments, la limite de la version gratuite. Passez à Premium pour un frigo illimité."
                        : "Encore \(remaining) aliment\(remaining > 1 ? "s" : "") avant la limite de la version gratuite."
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            emoji: "🧊",
            title: "Votre frigo est vide",
            message: "Scannez un produit ou ajoutez-le à la main. Expira estime la date de péremption pour vous.",
            actionTitle: "Ajouter un aliment"
        ) {
            requestAdd()
        }
    }

    /// Bandeau d'annulation : un swipe se trompe vite, et une action irréversible
    /// dans une liste est une source d'anxiété. On laisse toujours une porte de sortie.
    @ViewBuilder
    private var undoBanner: some View {
        if let lastResolved {
            HStack(spacing: Spacing.m) {
                Text("\(lastResolved.item.displayName) · \(lastResolved.kind.displayName)")
                    .font(ExpiraFont.footnote)
                    .foregroundStyle(ExpiraColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button("Annuler") {
                    app.fridge.undoResolve(lastResolved.item)
                    self.lastResolved = nil
                    Task { await app.refreshNotifications() }
                }
                .font(ExpiraFont.captionEmphasized)
                .foregroundStyle(ExpiraColor.brand)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .background(ExpiraColor.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(ExpiraColor.separator, lineWidth: 0.5))
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, Spacing.s)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func requestAdd() {
        guard app.canAddItem() else {
            app.presentPaywall(.itemLimit)
            return
        }
        showAddOptions = true
    }

    private func openRescuePlan() {
        guard app.preferences.canGenerateRescuePlan(isPremium: app.isPremium) else {
            app.presentPaywall(.rescuePlanner)
            return
        }
        showRescuePlan = true
    }

    private func resolve(_ item: FoodItem, as kind: HistoryEvent.Kind) {
        app.fridge.resolve(item, as: kind)
        app.analytics.track(
            .itemResolved(kind: kind, daysBeforeExpiry: item.daysRemaining(asOf: now))
        )
        if kind == .consumed {
            Haptics.success()
        } else {
            Haptics.impact(.light)
        }

        withAnimation { lastResolved = (item, kind) }
        Task {
            await app.refreshNotifications()
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                if lastResolved?.item.id == item.id {
                    withAnimation { lastResolved = nil }
                }
            }
        }
    }
}
\n
#if DEBUG
#Preview("Frigo rempli") {
    FridgeView()
        .environment(AppEnvironment.preview())
}

// Les états vides comptent autant que les états remplis — ce sont ceux
// qu'on oublie de regarder.
#Preview("Frigo vide") {
    FridgeView()
        .environment(AppEnvironment.previewEmpty())
}
#endif
