import SwiftUI
import Kingfisher

struct CategoryDetailView: View {
    let categoryId: String
    let competition: Competition

    @Environment(\.dismiss) private var dismiss
    @State private var category: Category?
    @State private var currentVote: Vote?
    @State private var selectedNomineeId: String?
    @State private var isVoting = false
    @State private var error: String?
    @State private var showVoteSuccess = false

    var body: some View {
        Group {
            if let category {
                List {
                    // Status Section
                    if category.isVotingLocked || category.hasWinner {
                        Section {
                            if category.hasWinner {
                                Label("Winner announced", systemImage: "trophy.fill")
                                    .foregroundStyle(.yellow)
                            } else if category.isVotingLocked {
                                Label("Voting is locked", systemImage: "lock.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    // Nominees Section
                    Section {
                        ForEach(category.nominees) { nominee in
                            NomineeCard(
                                nominee: nominee,
                                isSelected: selectedNomineeId == nominee.id,
                                isWinner: category.winnerId == nominee.id,
                                isLocked: category.isVotingLocked,
                                onTap: {
                                    if !category.isVotingLocked {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedNomineeId = nominee.id
                                        }
                                    }
                                }
                            )
                        }
                    } header: {
                        Text("Select your prediction")
                    }

                    // Error Section
                    if let error {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle(category.name)
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let category, !category.isVotingLocked {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await castVote()
                        }
                    } label: {
                        if isVoting {
                            ProgressView()
                        } else {
                            Text(currentVote != nil ? "Update" : "Vote")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(selectedNomineeId == nil || isVoting || selectedNomineeId == currentVote?.nomineeId)
                }
            }
        }
        .task {
            await loadData()
        }
        .sensoryFeedback(.success, trigger: showVoteSuccess)
    }

    private func loadData() async {
        guard let competitionId = competition.id else { return }

        // Listen for category updates
        Task {
            do {
                for try await categories in FirestoreService.shared.categoriesStream(for: competition.ceremonyYear) {
                    if let cat = categories.first(where: { $0.id == categoryId }) {
                        category = cat
                    }
                }
            } catch {
                self.error = error.localizedDescription
            }
        }

        // Listen for vote updates
        Task {
            do {
                for try await votes in FirestoreService.shared.myVotesStream(competitionId: competitionId) {
                    if let vote = votes.first(where: { $0.categoryId == categoryId }) {
                        currentVote = vote
                        if selectedNomineeId == nil {
                            selectedNomineeId = vote.nomineeId
                        }
                    }
                }
            } catch {
                // Handle silently
            }
        }
    }

    private func castVote() async {
        guard let nomineeId = selectedNomineeId,
              let competitionId = competition.id else { return }

        isVoting = true
        error = nil

        do {
            _ = try await CloudFunctionsService.shared.castVote(
                competitionId: competitionId,
                categoryId: categoryId,
                nomineeId: nomineeId
            )
            showVoteSuccess = true

            // Brief delay then pop back
            try? await Task.sleep(for: .milliseconds(300))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isVoting = false
    }
}

struct NomineeCard: View {
    let nominee: Nominee
    let isSelected: Bool
    let isWinner: Bool
    let isLocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .font(.title2)

                // Nominee image
                if let url = URL(string: nominee.imageUrl) {
                    KFImage(url)
                        .placeholder {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                        }
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 70)
                        .cornerRadius(6)
                }

                // Nominee info
                VStack(alignment: .leading, spacing: 4) {
                    Text(nominee.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let subtitle = nominee.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Winner badge
                if isWinner {
                    Label("Winner", systemImage: "trophy.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked && !isSelected && !isWinner ? 0.6 : 1)
    }
}
