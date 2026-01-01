import SwiftUI

struct CreateCompetitionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var createdInviteCode: String?

    private let ceremonyYear = "2026" // Current ceremony year

    var body: some View {
        NavigationStack {
            if let inviteCode = createdInviteCode {
                successView(inviteCode: inviteCode)
            } else {
                formView
            }
        }
    }

    private var formView: some View {
        Form {
            Section {
                TextField("Competition Name", text: $name)
                    .textContentType(.name)
            } header: {
                Text("Name your competition")
            } footer: {
                Text("Give your competition a fun name like \"Family Oscar Pool\" or \"Work Predictions\"")
            }

            Section {
                HStack {
                    Text("Ceremony")
                    Spacer()
                    Text("\(ceremonyYear) Academy Awards")
                        .foregroundStyle(.secondary)
                }
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Create Competition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        await createCompetition()
                    }
                }
                .disabled(name.isEmpty || isLoading)
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

    private func successView(inviteCode: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Competition Created!")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                Text("Share this code with friends")
                    .foregroundStyle(.secondary)

                Text(inviteCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }

            HStack(spacing: 16) {
                ShareLink(item: "Join my Oscar predictions competition! Use code: \(inviteCode)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    UIPasteboard.general.string = inviteCode
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Button("Done") {
                dismiss()
            }
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

    private func createCompetition() async {
        isLoading = true
        error = nil

        do {
            let response = try await CloudFunctionsService.shared.createCompetition(
                name: name,
                ceremonyYear: ceremonyYear
            )
            createdInviteCode = response.inviteCode
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    CreateCompetitionView()
}
