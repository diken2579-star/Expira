import SwiftUI
import UIKit
import UserNotifications
import ExpiraCore
import ExpiraDesignSystem
import ExpiraNotifications

@main
@MainActor
struct ExpiraApp: App {
    @State private var appEnvironment = AppEnvironment()
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .tint(ExpiraColor.brand)
                .onAppear {
                    notificationDelegate.environment = appEnvironment
                    appEnvironment.onLaunch()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        appEnvironment.onEnterForeground()
                    }
                }
        }
    }
}

/// Réception des notifications et de leurs actions rapides.
///
/// Les actions (« C'est consommé », « Voir une recette ») sont ce qui rend une
/// notification réellement utile : l'utilisateur peut maintenir son stock à jour
/// sans même ouvrir l'app.
final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor var environment: AppEnvironment?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Une notification reçue alors que l'app est ouverte n'a aucun intérêt :
    /// l'information est déjà à l'écran. On ne l'affiche pas.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // On extrait des valeurs simples avant de repasser sur le fil principal :
        // `UNNotificationResponse` et son `userInfo` ne traversent pas les
        // frontières de concurrence.
        let userInfo = response.notification.request.content.userInfo
        let kind = userInfo["kind"] as? String ?? "unknown"
        let itemIDs = (userInfo["itemIDs"] as? [String] ?? []).compactMap(UUID.init(uuidString:))
        let actionIdentifier = response.actionIdentifier

        await MainActor.run {
            guard let environment else { return }
            environment.analytics.track(.notificationOpened(type: kind))

            switch actionIdentifier {
            case NotificationService.actionMarkConsumed:
                let items = itemIDs.compactMap { environment.fridge.item(withID: $0) }
                    .filter { $0.status == .active }
                guard !items.isEmpty else { return }
                environment.fridge.resolve(items, as: .consumed)
                Task { await environment.refreshNotifications() }

            case NotificationService.actionShowRecipes:
                environment.pendingDeepLink = .recipes

            default:
                environment.pendingDeepLink = .fridge
            }
        }
    }
}
