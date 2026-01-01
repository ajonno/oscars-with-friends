import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        Group {
            if authService.isLoading {
                // Loading state while checking auth
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Loading...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if authService.user != nil {
                // Authenticated - show main app
                MainTabView()
            } else {
                // Not authenticated - show login
                LoginView()
            }
        }
        .animation(.easeInOut, value: authService.user != nil)
    }
}

enum AppTab: Int {
    case ceremonies
    case competitions
    case profile
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .ceremonies

    var body: some View {
        TabView(selection: $selectedTab) {
            CeremoniesListView()
                .tabItem {
                    Label("Ceremonies", systemImage: "trophy.fill")
                }
                .tag(AppTab.ceremonies)

            HomeView()
                .tabItem {
                    Label("Competitions", systemImage: "person.3.fill")
                }
                .tag(AppTab.competitions)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(AppTab.profile)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToCompetitionsTab)) { _ in
            selectedTab = .competitions
        }
    }
}

#Preview("Logged In") {
    ContentView()
        .environment(AuthService())
}

#Preview("Logged Out") {
    ContentView()
        .environment(AuthService())
}
