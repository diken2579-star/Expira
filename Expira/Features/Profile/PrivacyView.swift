import SwiftUI
import ExpiraCore
import ExpiraDesignSystem

/// Confidentialité et données.
///
/// On y explique exactement ce qui sort de l'appareil (13 chiffres, quand
/// l'utilisateur scanne un code-barres) et ce qui n'en sort jamais. Le journal
/// analytique est consultable ligne par ligne : on ne demande pas de nous croire
/// sur parole, on montre.
@MainActor
struct PrivacyView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var showLog = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        @Bindable var preferences = app.preferences

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    ExpiraCard {
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            PrivacyPoint(
                                icon: "iphone",
                                title: "Vos aliments restent sur votre iPhone",
                                detail: "Aucun compte, aucun serveur. La liste de votre frigo n'est envoyée nulle part."
                            )
                            Divider().overlay(ExpiraColor.separator)
                            PrivacyPoint(
                                icon: "barcode.viewfinder",
                                title: "Une seule requête réseau",
                                detail: "Quand vous scannez un code-barres, ses 13 chiffres sont envoyés à Open Food Facts pour retrouver le produit. Rien d'autre — ni identifiant, ni historique."
                            )
                            Divider().overlay(ExpiraColor.separator)
                            PrivacyPoint(
                                icon: "camera.fill",
                                title: "Les photos ne sont jamais conservées",
                                detail: "La lecture des codes-barres et des dates se fait en mémoire, sur l'appareil. Aucune image n'est enregistrée ni transmise."
                            )
                            Divider().overlay(ExpiraColor.separator)
                            PrivacyPoint(
                                icon: "eurosign.circle",
                                title: "Nous ne vendons pas vos données",
                                detail: "Jamais. Expira est financée par ses abonnements, pas par la publicité."
                            )
                        }
                    }

                    ExpiraCard {
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            Toggle("Mesure d'audience anonyme", isOn: $preferences.analyticsEnabled)
                                .font(ExpiraFont.bodyEmphasized)
                            Text("Compte les étapes franchies dans l'app (onboarding terminé, premier scan…) pour savoir où les gens bloquent. Aucun nom d'aliment, aucun identifiant. Le journal est stocké localement.")
                                .font(ExpiraFont.footnote)
                                .foregroundStyle(ExpiraColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button("Voir le journal (\(app.analyticsLog().count) lignes)") {
                                showLog = true
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }

                    ExpiraCard {
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            Text("Supprimer mes données")
                                .font(ExpiraFont.headline)
                                .foregroundStyle(ExpiraColor.textPrimary)
                            Text("Efface définitivement vos aliments, votre historique et votre journal de cet appareil.")
                                .font(ExpiraFont.footnote)
                                .foregroundStyle(ExpiraColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Tout supprimer", role: .destructive) {
                                showDeleteConfirmation = true
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .foregroundStyle(ExpiraColor.expired)
                        }
                    }
                }
                .padding(Layout.screenPadding)
            }
            .background(ExpiraColor.background)
            .navigationTitle("Confidentialité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
            .sheet(isPresented: $showLog) {
                AnalyticsLogView(lines: app.analyticsLog())
            }
            .confirmationDialog(
                "Supprimer toutes vos données ?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Tout supprimer", role: .destructive) {
                    app.fridge.deleteAllData()
                    app.clearAnalyticsLog()
                    Task { await app.refreshNotifications() }
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cette action est irréversible.")
            }
        }
    }
}

@MainActor
private struct PrivacyPoint: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(ExpiraColor.brand)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ExpiraFont.bodyEmphasized)
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

@MainActor
private struct AnalyticsLogView: View {
    let lines: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if lines.isEmpty {
                    EmptyStateView(
                        emoji: "📭",
                        title: "Journal vide",
                        message: "Aucun événement n'a été enregistré sur cet appareil."
                    )
                } else {
                    List(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(ExpiraColor.textSecondary)
                    }
                    .listStyle(.plain)
                }
            }
            .background(ExpiraColor.background)
            .navigationTitle("Journal local")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
