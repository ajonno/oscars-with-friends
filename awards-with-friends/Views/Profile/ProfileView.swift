import SwiftUI
import FirebaseAuth
import Kingfisher

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @State private var showSignOutConfirmation = false

    private var user: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                List {
                    // User Info Section
                    Section {
                    HStack(spacing: 16) {
                        // Avatar
                        if let photoURL = user?.photoURL {
                            KFImage(photoURL)
                                .placeholder {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundStyle(.gray)
                                }
                                .fade(duration: 0.25)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundStyle(.gray)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user?.displayName ?? "User")
                                .font(.headline)

                            Text(user?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Account Section
                Section("Account") {
                    if let providerId = user?.providerData.first?.providerID {
                        HStack {
                            Text("Sign-in Method")
                            Spacer()
                            Text(providerDisplayName(providerId))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let creationDate = user?.metadata.creationDate {
                        HStack {
                            Text("Member Since")
                            Spacer()
                            Text(creationDate, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // App Info Section
                Section("App") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.buildNumber)
                            .foregroundStyle(.secondary)
                    }
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func providerDisplayName(_ providerId: String) -> String {
        switch providerId {
        case "apple.com":
            return "Apple"
        case "google.com":
            return "Google"
        case "password":
            return "Email"
        default:
            return providerId
        }
    }
}

extension Bundle {
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

#Preview {
    ProfileView()
        .environment(AuthService())
}
