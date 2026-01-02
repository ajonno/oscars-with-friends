import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var showSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo/Header
                    VStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.yellow.gradient)

                        Text("Oscars With Friends")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Compete with friends to predict Oscar winners")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Sign in options
                    VStack(spacing: 16) {
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            authService.handleSignInWithAppleRequest(request)
                        } onCompletion: { result in
                            Task {
                                await authService.handleSignInWithAppleCompletion(result)
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(10)

                        // Sign in with Google
                        Button {
                            Task {
                                await authService.signInWithGoogle()
                            }
                        } label: {
                            HStack {
                                Text("G")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.red, .yellow, .green, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Sign in with Google")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.white)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }

                        // Email/Password
                        VStack(spacing: 12) {
                            TextField("Email", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)

                            SecureField("Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)

                            Button {
                                isLoading = true
                                Task {
                                    await authService.signIn(email: email, password: password)
                                    isLoading = false
                                }
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .disabled(email.isEmpty || password.isEmpty || isLoading)
                            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                        }
                    }
                    .padding(.horizontal)

                    // Sign up link
                    Button {
                        showSignUp = true
                    } label: {
                        Text("Don't have an account? ")
                            .foregroundStyle(.secondary)
                        + Text("Sign Up")
                            .foregroundStyle(.blue)
                            .fontWeight(.medium)
                    }

                    // Error message
                    if let error = authService.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthService())
}
