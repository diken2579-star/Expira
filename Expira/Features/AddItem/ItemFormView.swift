import SwiftUI
import ExpiraCore
import ExpiraDesignSystem

/// Formulaire d'ajout et d'édition.
///
/// Il tient sur un écran, le champ « nom » prend le focus automatiquement, et le
/// bouton d'enregistrement est actif dès qu'un nom est saisi. Tout le reste est
/// pré-rempli.
@MainActor
struct ItemFormView: View {
    enum Mode {
        case create
        case edit

        var title: String {
            switch self {
            case .create: return "Nouvel aliment"
            case .edit: return "Modifier"
            }
        }

        var confirmTitle: String {
            switch self {
            case .create: return "Ajouter au frigo"
            case .edit: return "Enregistrer"
            }
        }
    }

    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var draft: FoodItemDraft
    @State private var showDateScanner = false
    @FocusState private var isNameFocused: Bool

    private let mode: Mode
    private let onSave: (FoodItem) -> Void

    init(draft: FoodItemDraft, mode: Mode, onSave: @escaping (FoodItem) -> Void) {
        _draft = State(initialValue: draft)
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    nameCard
                    categoryCard
                    expiryCard
                    detailsCard
                }
                .padding(Layout.screenPadding)
            }
            .background(ExpiraColor.background)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(mode.confirmTitle, action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!draft.isValid)
                    .opacity(draft.isValid ? 1 : 0.5)
                    .padding(Layout.screenPadding)
                    .background(.bar)
            }
            .sheet(isPresented: $showDateScanner) {
                DateScannerView { date in
                    draft.applyScannedDate(date)
                    showDateScanner = false
                }
            }
            .onAppear {
                if mode == .create, draft.name.isEmpty {
                    isNameFocused = true
                }
            }
        }
    }

    // MARK: - Sections

    private var nameCard: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Nom")
                    .font(ExpiraFont.captionEmphasized)
                    .foregroundStyle(ExpiraColor.textSecondary)
                TextField("Poulet, salade, yaourts…", text: $draft.name)
                    .font(ExpiraFont.title3)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.sentences)

                if let barcode = draft.barcode {
                    Text("Code-barres \(barcode)")
                        .font(ExpiraFont.caption)
                        .foregroundStyle(ExpiraColor.textTertiary)
                }
            }
        }
    }

    private var categoryCard: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Catégorie")
                    .font(ExpiraFont.captionEmphasized)
                    .foregroundStyle(ExpiraColor.textSecondary)

                // Grille d'emojis plutôt qu'un sélecteur : un tap au lieu de trois.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 64), spacing: Spacing.s)],
                    spacing: Spacing.s
                ) {
                    ForEach(FoodCategory.selectionOrder, id: \.self) { category in
                        CategoryChip(category: category, isSelected: draft.category == category) {
                            Haptics.selection()
                            draft.applyCategory(category, estimator: app.estimator)
                        }
                    }
                }

                Divider().overlay(ExpiraColor.separator)

                Picker("Conservation", selection: $draft.storage) {
                    ForEach(StorageLocation.allCases, id: \.self) { location in
                        Text(location.displayName).tag(location)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.storage) { _, _ in
                    draft.refreshEstimatedExpiry(using: app.estimator)
                }
            }
        }
    }

    private var expiryCard: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Text("Date de péremption")
                        .font(ExpiraFont.captionEmphasized)
                        .foregroundStyle(ExpiraColor.textSecondary)
                    Spacer()
                    Text(draft.expirySource.displayName)
                        .font(ExpiraFont.caption)
                        .foregroundStyle(
                            draft.expirySource.isEstimated ? ExpiraColor.tomorrow : ExpiraColor.brand
                        )
                }

                DatePicker(
                    "Date de péremption",
                    selection: Binding(
                        get: { draft.expiryDate },
                        set: { draft.applyUserDate($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()

                if draft.expirySource.isEstimated {
                    InfoBanner(
                        tone: .warning,
                        message: "Estimation basée sur la catégorie et le mode de conservation. Vérifiez l'emballage : une date imprimée est toujours plus fiable."
                    )
                }

                Button {
                    scanDate()
                } label: {
                    Label("Scanner la date sur l'emballage", systemImage: "text.viewfinder")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var detailsCard: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Toggle("Produit entamé", isOn: $draft.isOpened)
                    .font(ExpiraFont.body)
                    .onChange(of: draft.isOpened) { _, _ in
                        draft.refreshEstimatedExpiry(using: app.estimator)
                    }

                Divider().overlay(ExpiraColor.separator)

                HStack(spacing: Spacing.m) {
                    Text("Quantité")
                        .font(ExpiraFont.body)
                    Spacer()
                    Text(FoodItem.formatQuantity(draft.quantity, unit: draft.unit))
                        .font(ExpiraFont.bodyEmphasized)
                        .monospacedDigit()
                    Stepper("Quantité", value: $draft.quantity, in: 1...99, step: 1)
                        .labelsHidden()
                        .fixedSize()
                }

                Picker("Unité", selection: $draft.unit) {
                    ForEach(QuantityUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Actions

    /// Le paywall est présenté à la racine : ce formulaire reste ouvert derrière
    /// et l'utilisateur le retrouve intact après fermeture.
    private func scanDate() {
        guard app.requirePremium(for: .dateScanner) else { return }
        app.analytics.track(.scanStarted(type: "date"))
        showDateScanner = true
    }

    private func save() {
        guard draft.isValid else { return }
        let item = draft.build(estimator: app.estimator)
        onSave(item)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Pastille de catégorie

@MainActor
private struct CategoryChip: View {
    let category: FoodCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(category.emoji)
                    .font(.title3)
                Text(category.displayName)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? ExpiraColor.brand : ExpiraColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.s)
            .background(isSelected ? ExpiraColor.brandSoft : ExpiraColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .strokeBorder(isSelected ? ExpiraColor.brand : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
