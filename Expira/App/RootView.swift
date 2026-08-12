import SwiftUI
import ExpiraCore
import ExpiraDesignSystem

/// Aiguillage racine : onboarding, puis l'app. Le paywall est présenté ici pour
/// que n'importe quel écran puisse le déclencher sans le connaître.
@MainActor
struct RootView: View {
    @Environment(AppEnvironment.self) private var app

    var body: some View {
        @Bindable var app = app

        Group {
            if app.preferences.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.preferences.hasCompletedOnboarding)
        .background(ExpiraColor.background)
        .sheet(item: $app.paywallTrigger) { trigger in
            PaywallView(trigger: trigger)
        }
    }
}

extension PaywallTrigger: Identifiable {
    public var id: String { rawValue }
}

@MainActor
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var app
    @State private var selection: Tab = .fridge

    enum Tab: Hashable {
        case fridge
        case recipes
        case profile
    }

    var body: some View {
        TabView(selection: $selection) {
            FridgeView()
                .tabItem { Label("Frigo", systemImage: "refrigerator.fill") }
                .tag(Tab.fridge)

            RecipesView()
                .tabItem { Label("Recettes", systemImage: "fork.knife") }
                .tag(Tab.recipes)

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .onChange(of: app.pendingDeepLink) { _, link in
            guard let link else { return }
            switch link {
            case .fridge: selection = .fridge
            case .recipes: selection = .recipes
            }
            app.pendingDeepLink = nil
        }
    }
}
