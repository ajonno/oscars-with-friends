import SwiftUI
import FirebaseAuth

struct LeaderboardView: View {
    let competition: Competition

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var participants: [Participant] = []
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var showDisplayMode = false
    @State private var selectedParticipant: Participant?
    @State private var error: String?

    private var totalCategories: Int {
        categories.filter { !$0.isHidden }.count
    }

    private var completedCategories: Int {
        categories.filter { !$0.isHidden && $0.hasWinner }.count
    }

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading leaderboard...")
            } else if participants.isEmpty {
                ContentUnavailableView(
                    "No Participants",
                    systemImage: "person.3",
                    description: Text("No one has joined yet")
                )
            } else {
                leaderboardList
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Leaderboard")
                        .font(.headline)
                    Text(competition.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            if horizontalSizeClass == .regular {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDisplayMode = true
                    } label: {
                        Image(systemName: "tv")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showDisplayMode) {
            LeaderboardDisplayView(
                competition: competition,
                participants: participants
            )
        }
        .sheet(item: $selectedParticipant) { participant in
            ParticipantPicksView(
                participant: participant,
                competition: competition,
                categories: categories
            )
            .presentationDetents([.medium, .large])
            .presentationSizing(.page)
        }
        .task {
            await loadParticipants()
        }
        .task {
            await loadCategories()
        }
    }

    private var leaderboardList: some View {
        List {
            if !categories.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Categories: \(totalCategories)", systemImage: "list.number")
                        Spacer()
                        Label("Announced: \(completedCategories)", systemImage: "checkmark.circle")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if !competition.canVote {
                        Text("Tap on a row to see that person's votes")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 5)
                    }
                }
                .listRowBackground(Color.clear)
            }

            ForEach(Array(sortedParticipants.enumerated()), id: \.element.id) { index, participant in
                if !competition.canVote {
                    Button {
                        selectedParticipant = participant
                    } label: {
                        LeaderboardRow(
                            rank: index + 1,
                            participant: participant,
                            isCurrentUser: participant.id == currentUserId
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    LeaderboardRow(
                        rank: index + 1,
                        participant: participant,
                        isCurrentUser: participant.id == currentUserId
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 8, for: .scrollContent)
    }

    private var sortedParticipants: [Participant] {
        participants.sorted { $0.score > $1.score }
    }

    private func loadParticipants() async {
        guard let competitionId = competition.id else { return }

        isLoading = true
        error = nil

        do {
            for try await updatedParticipants in FirestoreService.shared.participantsStream(competitionId: competitionId) {
                participants = updatedParticipants
                isLoading = false
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func loadCategories() async {
        do {
            for try await updatedCategories in FirestoreService.shared.categoriesStream(for: competition.ceremonyYear, event: competition.event) {
                categories = updatedCategories
            }
        } catch {
            // Silently fail - category counts are supplementary info
        }
    }
}

#Preview("Leaderboard") {
    NavigationStack {
        LeaderboardPreview()
    }
}

private struct LeaderboardPreview: View {
    private let competition = Competition.preview(name: "Oscar Pool 2026")
    private let participants = [
        Participant.preview(name: "Sarah Johnson", score: 12),
        Participant.preview(name: "Mike Chen", score: 10),
        Participant.preview(name: "Emma Wilson", score: 8),
        Participant.preview(name: "James Brown", score: 6),
        Participant.preview(name: "You", score: 5),
    ]

    var body: some View {
        List {
            ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                LeaderboardRow(
                    rank: index + 1,
                    participant: participant,
                    isCurrentUser: participant.displayName == "You"
                )
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 8, for: .scrollContent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Leaderboard")
                        .font(.headline)
                    Text(competition.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ParticipantPicksView: View {
    let participant: Participant
    let competition: Competition
    let categories: [Category]

    @Environment(\.dismiss) private var dismiss
    @State private var votes: [Vote] = []
    @State private var isLoading = true

    private var visibleCategories: [Category] {
        categories
            .filter { !$0.isHidden }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    private func vote(for category: Category) -> Vote? {
        votes.first { $0.categoryId == category.id }
    }

    private func nomineeName(for vote: Vote, in category: Category) -> String {
        category.nominees.first { $0.id == vote.nomineeId }?.title ?? "Unknown"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading picks...")
                } else if votes.isEmpty {
                    ContentUnavailableView(
                        "No Picks",
                        systemImage: "hand.tap"
                    )
                } else {
                    picksList
                }
            }
            .navigationTitle("\(participant.displayName)'s Picks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadVotes()
        }
    }

    private var picksList: some View {
        List(visibleCategories) { category in
            let userVote = vote(for: category)
            let isCorrect = userVote.map { $0.nomineeId == category.winnerId } ?? false

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let userVote {
                        HStack(spacing: 4) {
                            Text("Voted for:")
                                .foregroundStyle(.secondary)
                            Text(nomineeName(for: userVote, in: category))
                        }
                        .font(.body)
                        .fontWeight(.medium)
                    } else {
                        Text("No pick")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }

                    if category.hasWinner, let winner = category.winner, !isCorrect {
                        HStack(spacing: 4) {
                            Text("Winner:")
                                .foregroundStyle(.secondary)
                            Text(winner.title)
                                .foregroundStyle(.green)
                        }
                        .font(.callout)
                    }
                }

                Spacer()

                if category.hasWinner, userVote != nil {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isCorrect ? .green : .red)
                }
            }
            .padding(.vertical, 2)
        }
        .listStyle(.insetGrouped)
    }

    private func loadVotes() async {
        guard let competitionId = competition.id else {
            isLoading = false
            return
        }

        do {
            votes = try await FirestoreService.shared.votesForUser(
                competitionId: competitionId,
                userId: participant.odUserId
            )
        } catch {
            // Silently fail
        }
        isLoading = false
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let participant: Participant
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Rank
            rankView

            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.displayName)
                    .font(.headline)
                    .foregroundStyle(isCurrentUser ? .blue : .primary)

                Text("Score: \(participant.score)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(participant.score)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(participant.score == 1 ? "point" : "points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isCurrentUser ? Color.blue.opacity(0.1) : nil)
    }

    @ViewBuilder
    private var rankView: some View {
        switch rank {
        case 1:
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 36)
        case 2:
            Image(systemName: "medal.fill")
                .font(.title2)
                .foregroundStyle(.gray)
                .frame(width: 36)
        case 3:
            Image(systemName: "medal.fill")
                .font(.title2)
                .foregroundStyle(.brown)
                .frame(width: 36)
        default:
            Text("\(rank)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 36)
        }
    }
}

