import SwiftUI
import FirebaseAuth

struct LeaderboardView: View {
    let competition: Competition

    @State private var participants: [Participant] = []
    @State private var isLoading = true
    @State private var error: String?

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
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadParticipants()
        }
        .refreshable {
            await loadParticipants()
        }
    }

    private var leaderboardList: some View {
        List {
            ForEach(Array(sortedParticipants.enumerated()), id: \.element.id) { index, participant in
                LeaderboardRow(
                    rank: index + 1,
                    participant: participant,
                    isCurrentUser: participant.id == currentUserId
                )
            }
        }
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

