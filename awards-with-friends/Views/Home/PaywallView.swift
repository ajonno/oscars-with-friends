import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var error: String?

    private var storeService: StoreService { StoreService.shared }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "trophy.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                // Title
                VStack(spacing: 8) {
                    Text("Unlock Competitions")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Create and join competitions with friends")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "plus.circle.fill",
                        title: "Create Competitions",
                        description: "Set up your own competition and invite friends"
                    )

                    FeatureRow(
                        icon: "person.badge.plus.fill",
                        title: "Join Competitions",
                        description: "Enter invite codes to join friends' competitions"
                    )

                    FeatureRow(
                        icon: "trophy.fill",
                        title: "Compete & Win",
                        description: "Track scores and see who picks the most winners"
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)

                Spacer()

                // Error message
                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // Purchase button
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await purchase()
                        }
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(priceText)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isPurchasing || isRestoring || storeService.isLoading)

                    // Restore purchases
                    Button {
                        Task {
                            await restore()
                        }
                    } label: {
                        if isRestoring {
                            ProgressView()
                        } else {
                            Text("Restore Purchases")
                                .font(.subheadline)
                        }
                    }
                    .disabled(isPurchasing || isRestoring)

                    Text("One-time purchase. No subscription.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Competitions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var priceText: String {
        if let product = storeService.competitionsProduct {
            return "Unlock for \(product.displayPrice)"
        }
        return "Unlock for $2.99"
    }

    private func purchase() async {
        isPurchasing = true
        error = nil

        do {
            let success = try await storeService.purchase()
            if success {
                dismiss()
            }
        } catch {
            self.error = error.localizedDescription
        }

        isPurchasing = false
    }

    private func restore() async {
        isRestoring = true
        error = nil

        do {
            try await storeService.restorePurchases()
            if storeService.hasCompetitionsAccess {
                dismiss()
            } else {
                error = "No previous purchases found"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isRestoring = false
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PaywallView()
}
