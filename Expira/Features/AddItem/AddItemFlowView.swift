import SwiftUI
import UIKit
import ExpiraCore
import ExpiraDesignSystem
import ExpiraScanning

enum AddItemRoute: String, Identifiable, Hashable {
    case barcode
    case manual

    var id: String { rawValue }
}

/// Point d'entrée unique de l'ajout d'aliments.
@MainActor
struct AddItemFlowView: View {
    let route: AddItemRoute
    /// `true` si au moins un aliment a été ajouté.
    let onComplete: (Bool) -> Void

    @Environment(AppEnvironment.self) private var app

    var body: some View {
        switch route {
        case .manual:
            ItemFormView(draft: .new(estimator: app.estimator), mode: .create) { item in
                save(item, method: "manual")
                onComplete(true)
            }
        case .barcode:
            BarcodeScanScreen(onComplete: onComplete)
        }
    }

    private func save(_ item: FoodItem, method: String) {
        guard app.canAddItem() else {
            app.presentPaywall(.itemLimit)
            return
        }
        app.fridge.add(item)
        app.analytics.track(.itemAdded(method: method, expirySource: item.expirySource))
        app.analytics.track(.firstItemAdded(method: method))
        Task { await app.refreshNotifications() }
    }
}

// MARK: - Scan de code-barres

/// Scanner en **mode rafale** : on revient des courses avec huit produits, on les
/// passe l'un après l'autre sans jamais quitter l'écran. C'est ce qui fait la
/// différence entre une app qu'on utilise et une app qu'on abandonne.
@MainActor
struct BarcodeScanScreen: View {
    let onComplete: (Bool) -> Void

    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var permission: CameraAuthorization.Status = .notDetermined
    @State private var failure: ScanFailure?
    @State private var pendingDraft: FoodItemDraft?
    @State private var isLookingUp = false
    @State private var addedCount = 0
    @State private var lastAddedName: String?
    @State private var scanStartedAt = Date()
    @State private var lookupTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permission == .authorized, failure == nil {
                DataScannerView(
                    mode: .barcode,
                    onBarcode: handle(barcode:),
                    onFailure: { failure = $0 }
                )
                .ignoresSafeArea()

                scannerOverlay
            } else if let failure {
                ScanFallbackView(failure: failure) {
                    pendingDraft = .new(estimator: app.estimator)
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task { await requestPermission() }
        .onDisappear { lookupTask?.cancel() }
        .sheet(item: Binding(
            get: { pendingDraft.map(IdentifiedDraft.init) },
            set: { pendingDraft = $0?.draft }
        )) { identified in
            ItemFormView(draft: identified.draft, mode: .create) { item in
                add(item)
            }
        }
    }

    // MARK: Overlay

    private var scannerOverlay: some View {
        VStack {
            HStack {
                Button {
                    finish()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: Layout.minimumTapTarget, height: Layout.minimumTapTarget)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel("Fermer le scanner")

                Spacer()

                if isLookingUp {
                    HStack(spacing: Spacing.s) {
                        ProgressView().tint(.white)
                        Text("Recherche…")
                            .font(ExpiraFont.footnote)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(.black.opacity(0.45), in: Capsule())
                }
            }
            .padding(Layout.screenPadding)

            Spacer()

            VStack(spacing: Spacing.m) {
                if let lastAddedName {
                    Label("\(lastAddedName) ajouté", systemImage: "checkmark.circle.fill")
                        .font(ExpiraFont.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
                        .background(ExpiraColor.brand.opacity(0.9), in: Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Text("Visez le code-barres du produit")
                    .font(ExpiraFont.footnote)
                    .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: Spacing.m) {
                    Button("Saisir à la main") {
                        pendingDraft = .new(estimator: app.estimator)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .foregroundStyle(.white)

                    Button(addedCount > 0 ? "Terminer (\(addedCount))" : "Terminer") {
                        finish()
                    }
                    .buttonStyle(PrimaryButtonStyle(isProminent: false))
                    .frame(maxWidth: 180)
                }
            }
            .padding(Layout.screenPadding)
            .padding(.bottom, Spacing.l)
        }
        .animation(.easeOut(duration: 0.2), value: lastAddedName)
        .animation(.easeOut(duration: 0.2), value: isLookingUp)
    }

    // MARK: Actions

    private func requestPermission() async {
        guard ScannerAvailability.isSupported else {
            failure = .unsupportedDevice
            return
        }
        app.analytics.track(.scanStarted(type: "barcode"))
        scanStartedAt = Date()
        let status = await CameraAuthorization.request()
        permission = status
        app.analytics.track(.cameraPermission(granted: status == .authorized))
        if status == .denied {
            failure = .cameraDenied
        }
    }

    private func handle(barcode: String) {
        guard pendingDraft == nil, !isLookingUp else { return }
        Haptics.impact(.medium)
        isLookingUp = true

        lookupTask?.cancel()
        lookupTask = Task {
            var draft: FoodItemDraft
            var found = false
            do {
                if let product = try await app.productLookup.lookup(barcode: barcode) {
                    draft = .from(product: product, estimator: app.estimator)
                    found = true
                    app.analytics.track(.productLookup(found: true, cached: product.isLocal))
                } else {
                    // Produit inconnu : ce n'est pas une erreur. On pré-remplit ce
                    // qu'on sait (le code-barres) et l'utilisateur nomme le produit.
                    draft = .new(estimator: app.estimator)
                    draft.barcode = barcode
                    app.analytics.track(.productLookup(found: false, cached: false))
                }
            } catch {
                draft = .new(estimator: app.estimator)
                draft.barcode = barcode
                app.analytics.track(.scanFailed(type: "barcode", reason: "lookup_error"))
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                isLookingUp = false
                if found {
                    let elapsed = Int(Date().timeIntervalSince(scanStartedAt) * 1000)
                    app.analytics.track(.scanSucceeded(type: "barcode", durationMS: elapsed))
                }
                pendingDraft = draft
            }
        }
    }

    private func add(_ item: FoodItem) {
        guard app.canAddItem() else {
            app.presentPaywall(.itemLimit)
            return
        }
        app.fridge.add(item)
        app.analytics.track(.itemAdded(method: "barcode", expirySource: item.expirySource))
        app.analytics.track(.firstItemAdded(method: "barcode"))

        // Le produit nommé à la main est mémorisé : le prochain scan du même
        // code-barres sera instantané, même hors ligne.
        if let info = FoodItemDraft.from(item: item).productInfoForMemory {
            app.productLookup.remember(info)
        }

        addedCount += 1
        lastAddedName = item.displayName
        Haptics.success()
        Task { await app.refreshNotifications() }
    }

    private func finish() {
        lookupTask?.cancel()
        onComplete(addedCount > 0)
        dismiss()
    }
}

/// `FoodItemDraft` est une structure de saisie, pas une entité : on lui donne une
/// identité seulement pour la présentation en feuille.
private struct IdentifiedDraft: Identifiable {
    let draft: FoodItemDraft
    var id: UUID { draft.id }
}

// MARK: - Repli quand le scan est impossible

@MainActor
struct ScanFallbackView: View {
    let failure: ScanFailure
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.7))
            Text(failure.title)
                .font(ExpiraFont.title3)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(failure.message)
                .font(ExpiraFont.callout)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Spacing.s) {
                Button("Ajouter à la main", action: onManualEntry)
                    .buttonStyle(PrimaryButtonStyle())

                if failure.offersSettingsShortcut {
                    Button("Ouvrir les Réglages") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .foregroundStyle(.white)
                }
            }
            .padding(.top, Spacing.m)
        }
        .padding(Layout.screenPadding)
    }
}
