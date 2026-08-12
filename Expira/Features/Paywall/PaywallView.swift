import SwiftUI
import StoreKit
import ExpiraCore
import ExpiraCommerce
import ExpiraDesignSystem

/// Paywall EXPIRA.
///
/// **Règles non négociables, appliquées ici et vérifiables à la lecture :**
/// - une croix de fermeture visible immédiatement, en haut à gauche, ≥ 44 pt ;
/// - le prix, la durée de l'essai et le prix après essai écrits sur le bouton ;
/// - aucun compte à rebours, aucune fausse rareté, aucune formulation culpabilisante ;
/// - « Restaurer mes achats » toujours visible ;
/// - la résiliation expliquée en une phrase.
///
/// Un paywall honnête convertit moins bien à l'instant T. Il convertit mieux sur
/// la durée, se fait moins désinstaller et ne se fait pas refuser par l'App Store.
@MainActor
struct PaywallView: View {
    let trigger: PaywallTrigger

    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedProductID = ExpiraProduct.annual
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var appearedAt = Date()

    private var service: SubscriptionService { app.subscriptions }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    headline
                    featureList
                    offers
                    legalFooter
                }
                .padding(Layout.screenPadding)
            }
            .background(ExpiraColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Croix en haut à GAUCHE, taille de cible pleine, sans délai.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(ExpiraColor.textSecondary)
                            .frame(width: Layout.minimumTapTarget, height: Layout.minimumTapTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Fermer")
                }
            }
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .task { await prepare() }
            .alert(
                "Achat impossible",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("D'accord", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private func prepare() async {
        appearedAt = Date()
        if service.products.isEmpty {
            await service.loadProducts()
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("EXPIRA PREMIUM")
                .font(ExpiraFont.captionEmphasized)
                .kerning(1.2)
                .foregroundStyle(ExpiraColor.brand)
            Text(trigger.headline)
                .font(ExpiraFont.title)
                .foregroundStyle(ExpiraColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(trigger.subheadline)
                .font(ExpiraFont.callout)
                .foregroundStyle(ExpiraColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(PremiumFeature.allCases, id: \.self) { feature in
                HStack(alignment: .top, spacing: Spacing.m) {
                    Image(systemName: feature.systemImageName)
                        .font(.footnote)
                        .foregroundStyle(ExpiraColor.brand)
                        .frame(width: 22, alignment: .center)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: Spacing.xs) {
                            Text(feature.displayName)
                                .font(ExpiraFont.bodyEmphasized)
                                .foregroundStyle(ExpiraColor.textPrimary)
                            if !feature.isAvailableInV1 {
                                Text("bientôt")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(ExpiraColor.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ExpiraColor.surfaceElevated, in: Capsule())
                            }
                        }
                        Text(feature.explanation)
                            .font(ExpiraFont.footnote)
                            .foregroundStyle(ExpiraColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private var offers: some View {
        if service.isLoadingProducts {
            VStack(spacing: Spacing.m) {
                SkeletonBlock(height: 78, cornerRadius: Radius.medium)
                SkeletonBlock(height: 78, cornerRadius: Radius.medium)
            }
        } else if service.products.isEmpty {
            InfoBanner(
                tone: .warning,
                message: service.loadError ?? "Les offres ne sont pas disponibles pour le moment. Réessayez plus tard."
            )
        } else {
            VStack(spacing: Spacing.m) {
                ForEach(service.products, id: \.id) { product in
                    OfferCard(
                        product: product,
                        isSelected: selectedProductID == product.id,
                        isBestValue: product.id == ExpiraProduct.annual,
                        savingsPercent: product.id == ExpiraProduct.annual ? service.annualSavingsPercent : nil,
                        monthlyEquivalent: service.monthlyEquivalent(for: product),
                        trialDescription: service.introductoryOfferDescription(for: product)
                    ) {
                        Haptics.selection()
                        selectedProductID = product.id
                    }
                }
            }
        }
    }

    private var purchaseBar: some View {
        VStack(spacing: Spacing.s) {
            Button(action: purchase) {
                if isPurchasing {
                    ProgressView().tint(ExpiraColor.onBrand)
                } else {
                    Text(purchaseButtonTitle)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isPurchasing || service.products.isEmpty)
            .opacity(service.products.isEmpty ? 0.5 : 1)

            // Prix et conditions écrits noir sur blanc, sous le bouton.
            Text(commitmentDescription)
                .font(ExpiraFont.caption)
                .foregroundStyle(ExpiraColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Restaurer mes achats") {
                Task {
                    isPurchasing = true
                    let restored = await service.restorePurchases()
                    isPurchasing = false
                    if restored { dismiss() } else { errorMessage = "Aucun abonnement actif n'a été trouvé sur ce compte." }
                }
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(Layout.screenPadding)
        .background(.bar)
    }

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Résiliation en un tap depuis Réglages › votre nom › Abonnements. Aucune question posée.")
                .font(ExpiraFont.caption)
                .foregroundStyle(ExpiraColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.l) {
                if let terms = LegalLinks.terms {
                    Button("Conditions d'utilisation") { openURL(terms) }
                }
                if let privacy = LegalLinks.privacy {
                    Button("Confidentialité") { openURL(privacy) }
                }
            }
            .font(ExpiraFont.caption)
            .foregroundStyle(ExpiraColor.textSecondary)
        }
    }

    // MARK: - Textes

    private var selectedProduct: Product? {
        service.products.first { $0.id == selectedProductID }
    }

    private var purchaseButtonTitle: String {
        guard let product = selectedProduct else { return "Continuer" }
        if let trial = service.introductoryOfferDescription(for: product) {
            return "Essayer — \(trial)"
        }
        return "S'abonner — \(product.displayPrice)"
    }

    private var commitmentDescription: String {
        guard let product = selectedProduct else {
            return "Abonnement renouvelable, résiliable à tout moment."
        }
        let period = product.id == ExpiraProduct.annual ? "an" : "mois"
        if service.introductoryOfferDescription(for: product) != nil {
            return "Gratuit pendant l'essai, puis \(product.displayPrice) par \(period). Résiliable à tout moment avant la fin de l'essai, sans frais."
        }
        return "\(product.displayPrice) par \(period), renouvelé automatiquement. Résiliable à tout moment."
    }

    // MARK: - Actions

    private func purchase() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        Task {
            let outcome = await service.purchase(product)
            isPurchasing = false
            switch outcome {
            case .purchased:
                Haptics.success()
                dismiss()
            case .cancelled:
                break
            case .pending:
                errorMessage = "Votre achat est en attente de validation. Nous activerons Premium dès qu'il sera confirmé."
            case let .failed(message):
                Haptics.error()
                errorMessage = message
            }
        }
    }

    private func close() {
        let seconds = Int(Date().timeIntervalSince(appearedAt))
        app.analytics.track(.paywallDismissed(trigger: trigger, seconds: seconds))
        dismiss()
    }
}

// MARK: - Carte d'offre

@MainActor
private struct OfferCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let savingsPercent: Int?
    let monthlyEquivalent: String?
    let trialDescription: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? ExpiraColor.brand : ExpiraColor.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.s) {
                        Text(title)
                            .font(ExpiraFont.headline)
                            .foregroundStyle(ExpiraColor.textPrimary)
                        if let savingsPercent {
                            Text("−\(savingsPercent) %")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(ExpiraColor.onBrand)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ExpiraColor.brand, in: Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(ExpiraFont.footnote)
                        .foregroundStyle(ExpiraColor.textSecondary)
                    if let trialDescription {
                        Text(trialDescription)
                            .font(ExpiraFont.caption)
                            .foregroundStyle(ExpiraColor.brand)
                    }
                }

                Spacer(minLength: 0)

                Text(product.displayPrice)
                    .font(ExpiraFont.headline)
                    .foregroundStyle(ExpiraColor.textPrimary)
            }
            .padding(Spacing.l)
            .background(isSelected ? ExpiraColor.brandSoft : ExpiraColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(
                        isSelected ? ExpiraColor.brand : ExpiraColor.separator,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel("\(title), \(product.displayPrice). \(subtitle)")
    }

    private var title: String {
        isBestValue ? "Annuel" : "Mensuel"
    }

    private var subtitle: String {
        if let monthlyEquivalent {
            return "soit \(monthlyEquivalent) par mois"
        }
        return isBestValue ? "Facturé une fois par an" : "Facturé chaque mois"
    }
}
\n
#if DEBUG
// Les prix restent vides en aperçu : StoreKit n'y répond pas. C'est justement
// l'occasion de vérifier que l'écran reste présentable sans catalogue.
#Preview("Paywall — limite d'aliments") {
    PaywallView(trigger: .itemLimit)
        .environment(AppEnvironment.preview())
}

#Preview("Paywall — scan de date") {
    PaywallView(trigger: .dateScanner)
        .environment(AppEnvironment.preview())
}
#endif
