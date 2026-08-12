import Foundation
import AVFoundation
import VisionKit

/// Disponibilité du scanner sur l'appareil.
///
/// `DataScannerViewController` exige une puce A12 ou plus récente. Sur un
/// appareil plus ancien, on ne montre jamais un bouton qui ne marche pas :
/// l'app bascule silencieusement sur la saisie manuelle.
public enum ScannerAvailability {
    @MainActor
    public static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    @MainActor
    public static var isAvailable: Bool {
        DataScannerViewController.isAvailable
    }

    @MainActor
    public static var canScan: Bool {
        isSupported && isAvailable
    }
}

/// Gestion de l'autorisation caméra.
///
/// Elle est demandée **au moment du premier scan**, jamais à l'onboarding :
/// l'intention de l'utilisateur est alors maximale, et le taux d'acceptation
/// bien supérieur.
public enum CameraAuthorization {
    public enum Status: Equatable, Sendable {
        case authorized
        case denied
        case notDetermined
    }

    public static var current: Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    public static func request() async -> Status {
        switch current {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        }
    }
}

/// Toutes les façons dont un scan peut échouer — chacune mène à un repli manuel,
/// jamais à une impasse.
public enum ScanFailure: Equatable, Sendable {
    case unsupportedDevice
    case cameraDenied
    case unavailable
    case nothingDetected

    public var title: String {
        switch self {
        case .unsupportedDevice: return "Scan indisponible sur cet appareil"
        case .cameraDenied: return "Accès à la caméra refusé"
        case .unavailable: return "La caméra n'est pas disponible"
        case .nothingDetected: return "Rien n'a été reconnu"
        }
    }

    public var message: String {
        switch self {
        case .unsupportedDevice:
            return "Votre iPhone ne prend pas en charge le scan. Vous pouvez ajouter vos aliments à la main, c'est tout aussi rapide."
        case .cameraDenied:
            return "Expira a besoin de la caméra pour lire les codes-barres et les dates. Vous pouvez l'autoriser dans les Réglages."
        case .unavailable:
            return "La caméra est utilisée par une autre application, ou momentanément indisponible."
        case .nothingDetected:
            return "Essayez de vous rapprocher, ou saisissez l'information à la main."
        }
    }

    public var offersSettingsShortcut: Bool {
        self == .cameraDenied
    }
}
