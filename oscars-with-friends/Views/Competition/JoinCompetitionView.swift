import SwiftUI

struct JoinCompetitionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var joinedCompetitionName: String?

    var body: some View {
        NavigationStack {
            if let competitionName = joinedCompetitionName {
                successView(competitionName: competitionName)
            } else {
                formView
            }
        }
    }

    private var formView: some View {
        Form {
            Section {
                TextField("Invite Code", text: $code)
                    .textCase(.uppercase)
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .onChange(of: code) { _, newValue in
                        // Limit to 6 characters and uppercase
                        code = String(newValue.uppercased().prefix(6))
                    }
            } header: {
                Text("Enter the 6-character invite code")
            } footer: {
                Text("Ask your friend for the invite code to join their competition")
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Join Competition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Join") {
                    Task {
                        await joinCompetition()
                    }
                }
                .disabled(code.count != 6 || isLoading)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private func successView(competitionName: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.plus.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("You're In!")
                .font(.title)
                .fontWeight(.bold)

            Text("Successfully joined")
                .foregroundStyle(.secondary)

            Text(competitionName)
                .font(.title2)
                .fontWeight(.semibold)

            Button("Start Voting") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
        .navigationTitle("Success")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func joinCompetition() async {
        isLoading = true
        error = nil

        do {
            let response = try await CloudFunctionsService.shared.joinCompetition(code: code)
            joinedCompetitionName = response.competitionName
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    JoinCompetitionView()
}
