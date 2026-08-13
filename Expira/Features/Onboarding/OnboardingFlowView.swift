import SwiftUI
import ExpiraCore
import ExpiraDesignSystem

/// Onboarding en 4 écrans, puis l'ajout des premiers aliments.
///
/// Objectif chiffré : **moins de 30 secondes** entre l'installation et le premier
/// aliment dans le frigo. Chaque écran doit donc tenir en un seul tap. On ne
/// demande ni compte, ni e-mail, ni la caméra — seulement les notifications, et
/// après avoir expliqué pourquoi.
@MainActor
struct OnboardingFlowView: View {
    @Environment(AppEnvironment.self) private var app
    @State private var step = 0
    @State private var isRequestingNotifications = false

    private let lastStep = 3

    var body: some View {
        ZStack {
            ExpiraColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressDots(count: lastStep + 2, current: step)
                    .padding(.top, Spacing.l)

                TabView(selection: $step) {
                    WelcomeStep().tag(0)
                    WasteEstimateStep().tag(1)
                    PromiseStep().tag(2)
                    PermissionsStep(isRequesting: $isRequestingNotifications, onFinish: completeOnboarding)
                        .tag(3)
                    FirstItemsStep().tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
        .onAppear { app.analytics.track(.onboardingStarted) }
        .environment(\.onboardingAdvance, OnboardingAdvance { advance() })
    }

    private func advance() {
        app.analytics.track(.onboardingStepCompleted(step))
        withAnimation { step = min(step + 1, 4) }
    }

    private func completeOnboarding() {
        app.analytics.track(.onboardingCompleted)
        withAnimation { step = 4 }
    }
}

// MARK: - Passage à l'étape suivante

/// Petite injection pour que chaque étape reste une vue autonome et testable en
/// aperçu, sans connaître le conteneur qui l'affiche.
struct OnboardingAdvance {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    func callAsFunction() { action() }
}

private struct OnboardingAdvanceKey: EnvironmentKey {
    static let defaultValue = OnboardingAdvance {}
}

extension EnvironmentValues {
    var onboardingAdvance: OnboardingAdvance {
        get { self[OnboardingAdvanceKey.self] }
        set { self[OnboardingAdvanceKey.self] = newValue }
    }
}

// MARK: - Écran 1 — Bienvenue

@MainActor
private struct WelcomeStep: View {
    @Environment(\.onboardingAdvance) private var advance

    var body: some View {
        OnboardingScaffold(
            primaryTitle: "Commencer",
            primaryAction: { advance() }
        ) {
            VStack(spacing: Spacing.l) {
                Spacer()
                Text("🥬")
                    .font(.system(size: 84))
                    .accessibilityHidden(true)
                Text("EXPIRA")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .kerning(2)
                    .foregroundStyle(ExpiraColor.brand)
                Text("Ne laissez plus votre nourriture expirer.")
                    .font(ExpiraFont.title3)
                    .foregroundStyle(ExpiraColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }
}

// MARK: - Écran 2 — Estimation du gaspillage

@MainActor
private struct WasteEstimateStep: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.onboardingAdvance) private var advance
    @State private var selected: Option?

    private enum Option: String, CaseIterable, Identifiable {
        case low, medium, high, unknown

        var id: String { rawValue }

        var label: String {
            switch self {
            case .low: return "Presque rien"
            case .medium: return "Quelques produits"
            case .high: return "Beaucoup trop"
            case .unknown: return "Je ne sais pas"
            }
        }

        var detail: String {
            switch self {
            case .low: return "environ 10 € par mois"
            case .medium: return "environ 30 € par mois"
            case .high: return "environ 60 € par mois"
            case .unknown: return "on l'estimera ensemble"
            }
        }

        var euros: Double? {
            switch self {
            case .low: return 10
            case .medium: return 30
            case .high: return 60
            case .unknown: return nil
            }
        }
    }

    var body: some View {
        OnboardingScaffold(
            primaryTitle: "Continuer",
            primaryAction: submit,
            isPrimaryDisabled: selected == nil
        ) {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Spacer(minLength: Spacing.xl)
                Text("Combien jetez-vous chaque mois ?")
                    .font(ExpiraFont.title)
                    .foregroundStyle(ExpiraColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Une estimation suffit. Elle nous sert à mesurer ce que vous économisez.")
                    .font(ExpiraFont.callout)
                    .foregroundStyle(ExpiraColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: Spacing.s) {
                    ForEach(Option.allCases) { option in
                        Button {
                            Haptics.selection()
                            selected = option
                        } label: {
                            HStack(spacing: Spacing.m) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .font(ExpiraFont.bodyEmphasized)
                                        .foregroundStyle(ExpiraColor.textPrimary)
                                    Text(option.detail)
                                        .font(ExpiraFont.footnote)
                                        .foregroundStyle(ExpiraColor.textSecondary)
                                }
                                Spacer()
                                Image(systemName: selected == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected == option ? ExpiraColor.brand : ExpiraColor.textTertiary)
                            }
                            .padding(Spacing.l)
                            .background(selected == option ? ExpiraColor.brandSoft : ExpiraColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                                    .strokeBorder(
                                        selected == option ? ExpiraColor.brand : ExpiraColor.separator,
                                        lineWidth: selected == option ? 1.5 : 0.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == option ? [.isSelected] : [])
                    }
                }
                Spacer()
            }
        }
    }

    private func submit() {
        guard let selected else { return }
        app.preferences.wasteBaselineEUR = selected.euros
        app.analytics.track(.wasteBaselineSelected(selected.rawValue))
        advance()
    }
}

// MARK: - Écran 3 — Promesse produit

@MainActor
private struct PromiseStep: View {
    @Environment(\.onboardingAdvance) private var advance

    var body: some View {
        OnboardingScaffold(primaryTitle: "J'ai compris", primaryAction: { advance() }) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Spacer(minLength: Spacing.xl)
                Text("Expira transforme votre frigo en liste intelligente.")
                    .font(ExpiraFont.title)
                    .foregroundStyle(ExpiraColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Spacing.l) {
                    PromiseRow(
                        emoji: "📷",
                        title: "Scannez en 3 secondes",
                        detail: "Un code-barres, et le produit est ajouté avec sa date."
                    )
                    PromiseRow(
                        emoji: "🔔",
                        title: "On vous prévient au bon moment",
                        detail: "Une notification par jour maximum. Jamais plus."
                    )
                    PromiseRow(
                        emoji: "🍳",
                        title: "On vous dit quoi cuisiner",
                        detail: "Des recettes choisies pour sauver ce qui expire en premier."
                    )
                }
                Spacer()
            }
        }
    }
}

@MainActor
private struct PromiseRow: View {
    let emoji: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Text(emoji)
                .font(.title2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ExpiraFont.headline)
                    .foregroundStyle(ExpiraColor.textPrimary)
                Text(detail)
                    .font(ExpiraFont.footnote)
                    .foregroundStyle(ExpiraColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Écran 4 — Permissions

@MainActor
private struct PermissionsStep: View {
    @Environment(AppEnvironment.self) private var app
    @Binding var isRequesting: Bool
    let onFinish: () -> Void

    var body: some View {
        OnboardingScaffold(
            primaryTitle: isRequesting ? "..." : "Activer les notifications",
            primaryAction: requestNotifications,
            isPrimaryDisabled: isRequesting,
            secondaryTitle: "Plus tard",
            secondaryAction: skip
        ) {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Spacer(minLength: Spacing.xl)
                Text("🔔")
                    .font(.system(size: 56))
                    .accessibilityHidden(true)
                Text("Sans notification, Expira ne peut pas vous prévenir à temps.")
                    .font(ExpiraFont.title2)
                    .foregroundStyle(ExpiraColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                InfoBanner(
                    message: "Une notification par jour maximum, à l'heure que vous choisissez. Vous pouvez tout couper à tout moment dans les réglages."
                )

                Text("L'accès à la caméra vous sera demandé plus tard, uniquement au moment de votre premier scan.")
                    .font(ExpiraFont.footnote)
                    .foregroundStyle(ExpiraColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }

    private func requestNotifications() {
        isRequesting = true
        Task {
            let granted = await app.notifications.requestAuthorization()
            app.analytics.track(.notificationPermission(granted: granted))
            app.preferences.notificationsEnabled = granted
            isRequesting = false
            onFinish()
        }
    }

    private func skip() {
        app.analytics.track(.notificationPermission(granted: false))
        app.preferences.notificationsEnabled = false
        onFinish()
    }
}

// MARK: - Écran 5 — Premiers aliments

@MainActor
private struct FirstItemsStep: View {
    @Environment(AppEnvironment.self) private var app
    @State private var route: AddItemRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Spacer(minLength: Spacing.xxl)
            Text("Ajoutez vos premiers aliments")
                .font(ExpiraFont.title)
                .foregroundStyle(ExpiraColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Commencez par deux ou trois produits. Vous compléterez plus tard.")
                .font(ExpiraFont.callout)
                .foregroundStyle(ExpiraColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Spacing.m) {
                AddMethodCard(
                    emoji: "📷",
                    title: "Scanner un produit",
                    subtitle: "Le plus rapide — 3 secondes par produit",
                    isPrimary: true
                ) { route = .barcode }

                AddMethodCard(
                    emoji: "✍️",
                    title: "Ajouter manuellement",
                    subtitle: "Un nom suffit, on estime le reste"
                ) { route = .manual }

                AddMethodCard(
                    emoji: "🧾",
                    title: "Scanner mon ticket",
                    subtitle: "Bientôt disponible",
                    isDisabled: true
                ) {}
            }

            Spacer()

            Button("Je le ferai plus tard") { finish() }
                .buttonStyle(QuietButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Layout.screenPadding)
        .padding(.bottom, Spacing.xl)
        .sheet(item: $route) { route in
            AddItemFlowView(route: route) { added in
                if added { finish() }
            }
        }
    }

    private func finish() {
        app.preferences.hasCompletedOnboarding = true
        Task { await app.refreshNotifications() }
    }
}

@MainActor
private struct AddMethodCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    var isPrimary: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Text(emoji)
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ExpiraFont.headline)
                        .foregroundStyle(isPrimary ? ExpiraColor.onBrand : ExpiraColor.textPrimary)
                    Text(subtitle)
                        .font(ExpiraFont.footnote)
                        .foregroundStyle(isPrimary ? ExpiraColor.onBrand.opacity(0.85) : ExpiraColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(isPrimary ? ExpiraColor.onBrand.opacity(0.7) : ExpiraColor.textTertiary)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isPrimary ? ExpiraColor.brand : ExpiraColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(ExpiraColor.separator, lineWidth: isPrimary ? 0 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Habillage commun

@MainActor
private struct OnboardingScaffold<Content: View>: View {
    let primaryTitle: String
    let primaryAction: () -> Void
    var isPrimaryDisabled: Bool = false
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: Spacing.l) {
            content
            VStack(spacing: Spacing.s) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isPrimaryDisabled)
                    .opacity(isPrimaryDisabled ? 0.5 : 1)
                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(QuietButtonStyle())
                }
            }
        }
        .padding(.horizontal, Layout.screenPadding)
        .padding(.bottom, Spacing.xl)
    }
}

@MainActor
private struct ProgressDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? ExpiraColor.brand : ExpiraColor.separator)
                    .frame(width: index == current ? 22 : 6, height: 6)
                    .animation(.spring(duration: 0.3), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Étape \(current + 1) sur \(count)")
    }
}
#if DEBUG
#Preview("Onboarding") {
    OnboardingFlowView()
        .environment(AppEnvironment.preview(items: [], history: [], onboarded: false))
}
#endif
