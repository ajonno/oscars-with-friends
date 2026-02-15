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
    @State private var trailerYouTubeId: String?
    @State private var trailerConfirmNominee: Nominee?

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
                                categoryName: category.name,
                                isSelected: selectedNomineeId == nominee.id,
                                isWinner: category.winnerId == nominee.id,
                                isLocked: category.isVotingLocked,
                                onTap: {
                                    if !category.isVotingLocked {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedNomineeId = nominee.id
                                        }
                                    }
                                },
                                onPlayTrailer: nominee.trailerYouTubeId != nil ? {
                                    trailerConfirmNominee = nominee
                                } : nil
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
        .alert(
            "Play trailer?",
            isPresented: Binding(
                get: { trailerConfirmNominee != nil },
                set: { if !$0 { trailerConfirmNominee = nil } }
            )
        ) {
            Button("Play") {
                trailerYouTubeId = trailerConfirmNominee?.trailerYouTubeId
                trailerConfirmNominee = nil
            }
            Button("Cancel", role: .cancel) {
                trailerConfirmNominee = nil
            }
        } message: {
            if let nominee = trailerConfirmNominee {
                Text("Watch the \(nominee.title) trailer?")
            }
        }
        .fullScreenCover(item: $trailerYouTubeId) { youtubeId in
            TrailerPlayerView(youTubeId: youtubeId)
        }
    }

    private func loadData() async {
        guard let competitionId = competition.id else { return }

        // Listen for category updates
        Task {
            do {
                for try await categories in FirestoreService.shared.categoriesStream(for: competition.ceremonyYear, event: competition.event) {
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
    let categoryName: String
    let isSelected: Bool
    let isWinner: Bool
    let isLocked: Bool
    let onTap: () -> Void
    var onPlayTrailer: (() -> Void)? = nil

    // Placeholder images hosted on Firebase
    private static let personPlaceholder = URL(string: "https://awardswithfriends-25718.web.app/placeholders/person.svg")!
    private static let moviePlaceholder = URL(string: "https://awardswithfriends-25718.web.app/placeholders/movie.svg")!

    private var isPeopleCategory: Bool {
        let lowercased = categoryName.lowercased()
        return lowercased.contains("actor") ||
               lowercased.contains("actress") ||
               lowercased.contains("director") ||
               lowercased.contains("performer") ||
               lowercased.contains("supporting")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Radio button + image — taps to vote
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .gray)
                        .font(.title2)

                    nomineeImage
                }
            }
            .buttonStyle(.plain)
            .disabled(isLocked)

            // Text area — taps to play trailer (or vote if no trailer)
            Button(action: onPlayTrailer ?? onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(nominee.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let subtitle = nominee.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if onPlayTrailer != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "play.circle")
                            Text("Trailer Available")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLocked && onPlayTrailer == nil)

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
        .opacity(isLocked && !isSelected && !isWinner ? 0.6 : 1)
    }

    @ViewBuilder
    private var nomineeImage: some View {
        let imageUrl: URL = {
            if !nominee.imageUrl.isEmpty, let url = URL(string: nominee.imageUrl) {
                return url
            }
            return isPeopleCategory ? Self.personPlaceholder : Self.moviePlaceholder
        }()

        KFImage(imageUrl)
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
}
