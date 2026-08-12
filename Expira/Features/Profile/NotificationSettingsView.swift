import SwiftUI
import UIKit
import ExpiraCore
import ExpiraDesignSystem
import ExpiraNotifications

/// Réglages de notifications.
///
/// Le plafond « une notification par jour » est écrit noir sur blanc en haut de
/// l'écran. C'est une promesse produit, pas un détail technique : c'est ce qui
/// évite que l'utilisateur coupe tout au bout de trois jours.
@MainActor
struct NotificationSettingsView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var systemStatus: NotificationService.Authorization = .notDetermined

    var body: some View {
        @Bindable var preferences = app.preferences

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    if systemStatus == .denied {
                        deniedBanner
                    } else {
                        InfoBanner(
                            message: "Une notification par jour maximum. Vous choisissez l'heure, et vous pouvez tout couper d'un tap."
                        )
                    }

                    ExpiraCard {
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            Toggle("Recevoir des rappels", isOn: $preferences.notificationsEnabled)
                                .font(ExpiraFont.bodyEmphasized)
                                .disabled(systemStatus == .denied)

                            if preferences.notificationsEnabled, systemStatus != .denied {
                                Divider().overlay(ExpiraColor.separator)

                                HStack {
                                    Text("Heure du rappel")
                                        .font(ExpiraFont.body)
                                    Spacer()
                                    Picker("Heure du rappel", selection: $preferences.digestHour) {
                                        ForEach(6...22, id: \.self) { hour in
                                            Text(String(format: "%02d:00", hour)).tag(hour)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                }

                                Divider().overlay(ExpiraColor.separator)

                                VStack(alignment: .leading, spacing: Spacing.s) {
                                    Text("Me prévenir quand un aliment expire dans…")
                                        .font(ExpiraFont.footnote)
                                        .foregroundStyle(ExpiraColor.textSecondary)
                                    Picker("Seuil d'alerte", selection: $preferences.alertThresholdDays) {
                                        Text("Le jour même").tag(0)
                                        Text("1 jour").tag(1)
                                        Text("2 jours").tag(2)
                                        Text("3 jours").tag(3)
                                    }
                                    .pickerStyle(.segmented)
                                }

                                Divider().overlay(ExpiraColor.separator)

                                Toggle("Résumé du dimanche soir", isOn: $preferences.weeklySummaryEnabled)
                                    .font(ExpiraFont.body)
                            }
                        }
                    }

                    Text("Expira n'envoie jamais de notification quand il n'y a rien à signaler. Aucune donnée ne part de votre iPhone : les rappels sont calculés et programmés localement.")
                        .font(ExpiraFont.caption)
                        .foregroundStyle(ExpiraColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Layout.screenPadding)
            }
            .background(ExpiraColor.background)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
            .task { await loadAuthorizationStatus() }
            .onDisappear {
                Task { await app.refreshNotifications() }
            }
        }
    }

    private func loadAuthorizationStatus() async {
        systemStatus = await app.notifications.authorizationStatus()
    }

    private var deniedBanner: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            InfoBanner(
                tone: .warning,
                message: "Les notifications sont désactivées dans les réglages d'iOS. Expira ne peut donc pas vous prévenir avant qu'un aliment expire."
            )
            Button("Ouvrir les Réglages") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}
