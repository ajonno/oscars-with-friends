import SwiftUI

struct LeaderboardDisplayView: View {
    let competition: Competition
    let participants: [Participant]

    @Environment(\.dismiss) private var dismiss
    @State private var categories: [Category] = []

    private var sortedParticipants: [Participant] {
        participants.sorted { $0.score > $1.score }
    }

    private var totalCategories: Int {
        categories.filter { !$0.isHidden }.count
    }

    private var completedCategories: Int {
        categories.filter { !$0.isHidden && $0.hasWinner }.count
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text(competition.name)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)

                    Text("\(competition.ceremonyYear) \(competition.eventDisplayName)")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    if !categories.isEmpty {
                        HStack(spacing: 24) {
                            HStack(spacing: 6) {
                                Text("Total Categories:")
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("\(totalCategories)")
                                    .foregroundStyle(.white)
                            }
                            HStack(spacing: 6) {
                                Text("Announced:")
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("\(completedCategories)")
                                    .foregroundStyle(.white)
                            }
                        }
                        .font(.system(size: 18, weight: .medium))
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                if participants.isEmpty {
                    Spacer()
                    Text("No participants yet")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(sortedParticipants.enumerated()), id: \.element.id) { index, participant in
                                DisplayRow(
                                    rank: index + 1,
                                    participant: participant,
                                    isEvenRow: index % 2 == 0
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                }

                Text("Tap anywhere to exit")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .onTapGesture {
            dismiss()
        }
        .task {
            await loadCategories()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
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

private struct DisplayRow: View {
    let rank: Int
    let participant: Participant
    let isEvenRow: Bool

    var body: some View {
        HStack(spacing: 20) {
            rankView
                .frame(width: 60)

            Text(participant.displayName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(participant.score)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("pts")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isEvenRow ? Color.white.opacity(0.06) : Color.clear)
        )
    }

    @ViewBuilder
    private var rankView: some View {
        switch rank {
        case 1:
            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)
        case 2:
            Image(systemName: "medal.fill")
                .font(.system(size: 32))
                .foregroundStyle(.gray)
        case 3:
            Image(systemName: "medal.fill")
                .font(.system(size: 32))
                .foregroundStyle(.brown)
        default:
            Text("\(rank)")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

#Preview("Display Mode") {
    LeaderboardDisplayView(
        competition: Competition.preview(name: "Oscar Pool 2026"),
        participants: [
            Participant.preview(name: "Sarah Johnson", score: 12),
            Participant.preview(name: "Mike Chen", score: 10),
            Participant.preview(name: "Emma Wilson", score: 8),
            Participant.preview(name: "James Brown", score: 6),
            Participant.preview(name: "Alex Rivera", score: 5),
            Participant.preview(name: "Olivia Park", score: 3),
        ]
    )
}
