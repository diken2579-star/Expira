import SwiftUI
import UIKit
import ExpiraCore
import ExpiraDesignSystem

/// Profil : le bilan, la série, et les réglages.
///
/// Le bilan est la preuve que l'app sert à quelque chose. Chaque chiffre incertain
/// porte la mention « estimé » — un faux précis détruit la confiance beaucoup plus
/// vite qu'un chiffre honnêtement approximatif.
@MainActor
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var app
    @State private var showNotificationSettings = false
    @State private var showPrivacy = false

    private var summary: PeriodSummary {
        app.insights.currentMonthSummary(events: app.fridge.events)
    }

    private var streak: Int {
        app.insights.wasteFreeStreak(
            events: app.fridge.events,
            firstUseDate: app.preferences.firstUseDate
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    monthCard
                    goalCard
                    premiumCard
                    settingsCard
                    aboutCard
                }
                .padding(Layout.screenPadding)
            }
            .background(ExpiraColor.background)
            .navigationTitle("Profil")
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyView()
            }
        }
    }

    // MARK: - Sections

    private var monthCard: some View {
        ExpiraCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeaderView(title: "Ce mois-ci")

                if summary.isEmpty {
                    Text("Marquez vos aliments comme consommés ou jetés : votre bilan apparaîtra ici.")
                        .font(ExpiraFont.callout)
                        .foregroundStyle(ExpiraColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: Spacing.s) {
                        StatTile(emoji: "🥦", value: "\(summary.savedCount)", label: "aliments sauvés")
                        StatTile(
                            emoji: "💰",
                            value: summary.savedValueEUR.expiraEuroString,
                            label: "économisés",
                            isEstimate: true
                        )
                        StatTile(emoji: "🗑️", value: "\(summary.discardedCount)", label: "aliments jetés")
                    }

                    if let rate = summary.saveRate {
                        Text("Vous consommez \(Int(rate * 100)) % de ce que vous suivez.")
                            .font(ExpiraFont.footnote)
                            .foregroundStyle(ExpiraColor.textSecondary)
                    }

                    if !app.isPremium {
                        Button {
                            app.presentPaywall(.statistics)
                        } label: {
                            Text("Voir l'historique complet")
                                .font(ExpiraFont.footnote)
                                .foregroundStyle(ExpiraColor.brand)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var goalCard: some View {
        ExpiraCard {
            HStack(spacing: Spacing.l) {
                Text(streak > 0 ? "🔥" : "🌱")
                    .font(.system(size: 40))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(streak > 0 ? "\(streak) jours sans gaspillage" : "Nouvelle série démarrée")
                        .font(ExpiraFont.headline)
                        .foregroundStyle(ExpiraColor.textPrimary)
                    Text(
                        streak > 0
                            ? "Objectif de la semaine : 0 aliment gaspillé."
                            : "Chaque journée sans rien jeter fait grandir votre série."
                    )
                    .font(ExpiraFont.footnote)
                    .foregroundStyle(ExpiraColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var premiumCard: some View {
        if app.isPremium {
            ExpiraCard {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(ExpiraColor.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expira Premium actif")
                            .font(ExpiraFont.headline)
                            .foregroundStyle(ExpiraColor.textPrimary)
                        Text("Merci — c'est vous qui financez le développement.")
                            .font(ExpiraFont.footnote)
                            .foregroundStyle(ExpiraColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        } else {
            Button {
                app.presentPaywall(.settings)
            } label: {
                ExpiraCard {
                    HStack(spacing: Spacing.m) {
                        Text("✨").font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Passer à Expira Premium")
                                .font(ExpiraFont.headline)
                                .foregroundStyle(ExpiraColor.textPrimary)
                            Text("Aliments illimités, scan de date, plan de sauvetage.")
                                .font(ExpiraFont.footnote)
                                .foregroundStyle(ExpiraColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(ExpiraColor.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsCard: some View {
        ExpiraCard(padding: Spacing.s) {
            VStack(spacing: 0) {
                SettingsRow(icon: "bell.fill", title: "Notifications") {
                    showNotificationSettings = true
                }
                Divider().overlay(ExpiraColor.separator).padding(.leading, 48)
                SettingsRow(icon: "hand.raised.fill", title: "Confidentialité et données") {
                    showPrivacy = true
                }
                Divider().overlay(ExpiraColor.separator).padding(.leading, 48)
                SettingsRow(icon: "creditcard.fill", title: "Gérer mon abonnement") {
                    guard let url = LegalLinks.manageSubscriptions else { return }
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var aboutCard: some View {
        VStack(spacing: Spacing.s) {
            Text("Expira \(Bundle.main.appVersionString)")
                .font(ExpiraFont.caption)
                .foregroundStyle(ExpiraColor.textTertiary)
            Text("Vos données restent sur votre iPhone. Nous ne les vendons pas — jamais.")
                .font(ExpiraFont.caption)
                .foregroundStyle(ExpiraColor.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.l)
    }
}

// MARK: - Ligne de réglage

@MainActor
struct SettingsRow: View {
    let icon: String
    let title: String
    var detail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(systemName: icon)
                    .font(.footnote)
                    .foregroundStyle(ExpiraColor.brand)
                    .frame(width: 28, height: 28)
                    .background(ExpiraColor.brandSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(title)
                    .font(ExpiraFont.body)
                    .foregroundStyle(ExpiraColor.textPrimary)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(ExpiraFont.footnote)
                        .foregroundStyle(ExpiraColor.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ExpiraColor.textTertiary)
            }
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: Layout.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
