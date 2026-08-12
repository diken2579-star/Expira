import SwiftUI
import UIKit
import Combine
import ExpiraCore
import ExpiraDesignSystem
import ExpiraScanning

/// Lecture de la date imprimée sur l'emballage (OCR, 100 % sur l'appareil).
///
/// Une date lue ici a priorité absolue sur toute estimation. Mais on ne
/// l'enregistre **jamais** en silence : la date détectée est affichée en grand,
/// et l'utilisateur confirme. Une date fausse validée sans qu'il la voie serait
/// pire que pas de date du tout.
///
/// Au bout de 8 secondes sans lecture, on n'insiste pas : on propose la saisie
/// manuelle. L'échec ne doit jamais coûter plus de quelques secondes.
@MainActor
struct DateScannerView: View {
    let onConfirm: (Date) -> Void

    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var permission: CameraAuthorization.Status = .notDetermined
    @State private var failure: ScanFailure?
    @State private var detected: DetectedExpiryDate?
    @State private var manualDate = Date()
    @State private var showManualPicker = false
    @State private var elapsedSeconds = 0

    private let giveUpAfterSeconds = 8
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permission == .authorized, failure == nil, !showManualPicker {
                DataScannerView(
                    mode: .text,
                    onText: handle(lines:),
                    onFailure: { failure = $0 }
                )
                .ignoresSafeArea()

                overlay
            } else if showManualPicker {
                manualEntry
            } else if let failure {
                ScanFallbackView(failure: failure) { showManualPicker = true }
            } else {
                ProgressView().tint(.white)
            }
        }
        .task { await requestPermission() }
        .onReceive(timer) { _ in
            guard detected == nil, !showManualPicker, failure == nil else { return }
            elapsedSeconds += 1
        }
    }

    // MARK: Overlay caméra

    private var overlay: some View {
        VStack {
            HStack {
                Button {
                    app.analytics.track(.dateOCR(result: "cancelled"))
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: Layout.minimumTapTarget, height: Layout.minimumTapTarget)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel("Fermer")
                Spacer()
            }
            .padding(Layout.screenPadding)

            Spacer()

            VStack(spacing: Spacing.m) {
                if let detected {
                    confirmationCard(for: detected)
                } else {
                    Text("Visez la date imprimée sur l'emballage")
                        .font(ExpiraFont.callout)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if elapsedSeconds >= giveUpAfterSeconds {
                        VStack(spacing: Spacing.s) {
                            Text("Date illisible ?")
                                .font(ExpiraFont.footnote)
                                .foregroundStyle(.white.opacity(0.8))
                            Button("Saisir la date à la main") {
                                app.analytics.track(.dateOCR(result: "manual_fallback"))
                                showManualPicker = true
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .transition(.opacity)
                    }
                }
            }
            .padding(Layout.screenPadding)
            .padding(.bottom, Spacing.l)
        }
        .animation(.easeOut(duration: 0.2), value: detected)
        .animation(.easeOut(duration: 0.2), value: elapsedSeconds >= giveUpAfterSeconds)
    }

    private func confirmationCard(for detected: DetectedExpiryDate) -> some View {
        VStack(spacing: Spacing.m) {
            Text("Date détectée")
                .font(ExpiraFont.caption)
                .foregroundStyle(ExpiraColor.textSecondary)
            Text(detected.date.expiraLongDateString())
                .font(ExpiraFont.title2)
                .foregroundStyle(ExpiraColor.textPrimary)

            if detected.confidence.requiresConfirmation {
                Text("Vérifiez qu'elle correspond bien à l'emballage.")
                    .font(ExpiraFont.footnote)
                    .foregroundStyle(ExpiraColor.tomorrow)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: Spacing.s) {
                Button("Ce n'est pas ça") {
                    self.detected = nil
                    elapsedSeconds = giveUpAfterSeconds
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Confirmer") {
                    app.analytics.track(.dateOCR(result: "confirmed"))
                    Haptics.success()
                    onConfirm(detected.date)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(isProminent: false))
            }
        }
        .padding(Spacing.l)
        .background(ExpiraColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Saisie manuelle

    private var manualEntry: some View {
        VStack(spacing: Spacing.l) {
            Text("Quelle est la date ?")
                .font(ExpiraFont.title3)
                .foregroundStyle(ExpiraColor.textPrimary)

            DatePicker("Date de péremption", selection: $manualDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button("Enregistrer cette date") {
                onConfirm(manualDate)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Annuler") { dismiss() }
                .buttonStyle(QuietButtonStyle())
        }
        .padding(Layout.screenPadding)
        .background(ExpiraColor.background)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .padding(Layout.screenPadding)
    }

    // MARK: Actions

    private func requestPermission() async {
        guard ScannerAvailability.isSupported else {
            failure = .unsupportedDevice
            return
        }
        let status = await CameraAuthorization.request()
        permission = status
        if status == .denied { failure = .cameraDenied }
    }

    private func handle(lines: [String]) {
        guard detected == nil else { return }
        guard let result = app.dateParser.parse(lines: lines) else { return }
        Haptics.impact(.medium)
        detected = result
    }
}
