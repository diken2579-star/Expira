import SwiftUI
import UIKit
import VisionKit
import Vision

/// Ce que le scanner doit reconnaître.
public enum ScanMode: Equatable, Sendable {
    /// Codes-barres alimentaires (EAN-13 principalement, en France).
    case barcode
    /// Texte, pour lire une date imprimée sur l'emballage.
    case text
}

/// Enveloppe SwiftUI de `DataScannerViewController`.
///
/// Le contrôleur est sous-classé pour démarrer et arrêter le scan dans le cycle
/// de vie de la vue : c'est plus fiable que de le piloter depuis
/// `updateUIViewController`, appelé à des moments imprévisibles.
public struct DataScannerView: UIViewControllerRepresentable {
    private let mode: ScanMode
    private let onBarcode: (String) -> Void
    private let onText: ([String]) -> Void
    private let onFailure: (ScanFailure) -> Void

    public init(
        mode: ScanMode,
        onBarcode: @escaping (String) -> Void = { _ in },
        onText: @escaping ([String]) -> Void = { _ in },
        onFailure: @escaping (ScanFailure) -> Void = { _ in }
    ) {
        self.mode = mode
        self.onBarcode = onBarcode
        self.onText = onText
        self.onFailure = onFailure
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, onBarcode: onBarcode, onText: onText, onFailure: onFailure)
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        guard DataScannerViewController.isSupported else {
            onFailure(.unsupportedDevice)
            return UnsupportedPlaceholderViewController()
        }
        guard DataScannerViewController.isAvailable else {
            onFailure(.unavailable)
            return UnsupportedPlaceholderViewController()
        }

        let recognizedTypes: Set<DataScannerViewController.RecognizedDataType>
        switch mode {
        case .barcode:
            recognizedTypes = [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .code39])]
        case .text:
            recognizedTypes = [.text()]
        }

        let scanner = SelfStartingDataScannerViewController(
            recognizedDataTypes: recognizedTypes,
            qualityLevel: mode == .text ? .accurate : .balanced,
            recognizesMultipleItems: mode == .text,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        scanner.onStartFailure = { onFailure(.unavailable) }
        return scanner
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    // MARK: - Coordinator

    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let mode: ScanMode
        private let onBarcode: (String) -> Void
        private let onText: ([String]) -> Void
        private let onFailure: (ScanFailure) -> Void
        /// Un code-barres reste « vu » quelques secondes pour éviter de le
        /// remonter dix fois par seconde pendant que la caméra le suit.
        private var recentlySeen: [String: Date] = [:]
        private let debounceInterval: TimeInterval = 2.5

        init(
            mode: ScanMode,
            onBarcode: @escaping (String) -> Void,
            onText: @escaping ([String]) -> Void,
            onFailure: @escaping (ScanFailure) -> Void
        ) {
            self.mode = mode
            self.onBarcode = onBarcode
            self.onText = onText
            self.onFailure = onFailure
        }

        public func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            handle(addedItems, allItems: allItems)
        }

        public func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            // En mode texte, une date n'est souvent stable qu'après quelques
            // rafraîchissements : on écoute donc aussi les mises à jour.
            guard mode == .text else { return }
            handle(updatedItems, allItems: allItems)
        }

        public func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            onFailure(.unavailable)
        }

        private func handle(_ items: [RecognizedItem], allItems: [RecognizedItem]) {
            switch mode {
            case .barcode:
                for item in items {
                    guard case let .barcode(barcode) = item,
                          let payload = barcode.payloadStringValue,
                          !payload.isEmpty,
                          shouldEmit(payload)
                    else { continue }
                    onBarcode(payload)
                }
            case .text:
                let transcripts: [String] = allItems.compactMap { item in
                    guard case let .text(text) = item else { return nil }
                    return text.transcript
                }
                guard !transcripts.isEmpty else { return }
                onText(transcripts)
            }
        }

        private func shouldEmit(_ payload: String) -> Bool {
            let now = Date()
            if let last = recentlySeen[payload], now.timeIntervalSince(last) < debounceInterval {
                return false
            }
            recentlySeen[payload] = now
            // Purge pour ne pas laisser la table grandir sur une longue session.
            recentlySeen = recentlySeen.filter { now.timeIntervalSince($0.value) < 60 }
            return true
        }
    }
}

/// Démarre et arrête le scan au bon moment du cycle de vie.
private final class SelfStartingDataScannerViewController: DataScannerViewController {
    var onStartFailure: (() -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            try startScanning()
        } catch {
            onStartFailure?()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
}

/// Écran neutre affiché quand le scan est impossible : l'appelant a déjà reçu
/// l'échec et affiche son propre repli.
private final class UnsupportedPlaceholderViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
}
