import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// Replay mode is temporarily disabled for the next release while the
// canonical-vote changes ship to production.
private let isReplayFeatureEnabled = false

struct LeaderboardView: View {
    let competition: Competition

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var participants: [Participant] = []
    @State private var categories: [Category] = []
    @State private var competitionVotes: [Vote] = []
    @State private var isLoading = true
    @State private var showDisplayMode = false
    @State private var showReplaySettings = false
    @State private var showReplayDisableConfirmation = false
    @State private var selectedParticipant: Participant?
    @State private var error: String?
    @State private var areCategoriesLoaded = false
    @State private var areCompetitionVotesLoaded = false
    @State private var replayState = CompetitionReplayState()

    private var visibleCategories: [Category] {
        categories
            .filter { !$0.isHidden }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    private var totalCategories: Int {
        visibleCategories.count
    }

    private var completedCategories: Int {
        visibleCategories.filter(\.hasWinner).count
    }

    private var revealedCategoriesCount: Int {
        visibleCategories.filter { replayState.revealedCategoryIds.contains($0.id ?? "") }.count
    }

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private var canUseReplay: Bool {
        isReplayFeatureEnabled && completedCategories > 0
    }

    private var isReplayLoading: Bool {
        isReplayFeatureEnabled && replayState.isEnabled && (!areCategoriesLoaded || !areCompetitionVotesLoaded)
    }

    private var competitionVotesByParticipantId: [String: [String: Vote]] {
        Dictionary(grouping: competitionVotes, by: \.odUserId).mapValues { votes in
            Dictionary(uniqueKeysWithValues: votes.map { ($0.categoryId, $0) })
        }
    }

    private var replayScoresByParticipantId: [String: Int] {
        guard isReplayFeatureEnabled, replayState.isEnabled else { return [:] }
        return Dictionary(uniqueKeysWithValues: participants.map { participant in
            let score = ReplayScoring.revealedScore(
                votesByCategoryId: competitionVotesByParticipantId[participant.odUserId] ?? [:],
                categories: visibleCategories,
                revealedCategoryIds: replayState.revealedCategoryIds
            )
            return (participant.odUserId, score)
        })
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
            if canUseReplay {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if replayState.isEnabled {
                            showReplayDisableConfirmation = true
                        } else {
                            replayState.isEnabled = true
                            showReplaySettings = true
                        }
                    } label: {
                        Label(
                            replayState.isEnabled ? "Replay on" : "Replay off",
                            systemImage: replayState.isEnabled ? "eye.slash" : "eye"
                        )
                    }
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
                participants: participants,
                displayScoresByUserId: replayScoresByParticipantId,
                isReplayMode: replayState.isEnabled,
                revealedCount: revealedCategoriesCount
            )
        }
        .sheet(isPresented: $showReplaySettings) {
            ReplayRevealView(
                replayState: $replayState,
                categories: visibleCategories
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Turn off replay mode?", isPresented: $showReplayDisableConfirmation) {
            Button("Keep replay on", role: .cancel) {}
            Button("Turn off", role: .destructive) {
                replayState.isEnabled = false
            }
        } message: {
            Text("This will stop hiding unrevealed winners and return the leaderboard to its normal scores.")
        }
        .sheet(item: $selectedParticipant) { participant in
            ParticipantPicksView(
                participant: participant,
                competition: competition,
                categories: categories,
                replayState: replayState
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
        .task {
            await loadCompetitionVotes()
        }
        .task {
            loadReplayState()
        }
        .onChange(of: replayState) { _, newValue in
            guard isReplayFeatureEnabled else { return }
            saveReplayState(newValue)
        }
    }

    private var leaderboardList: some View {
        List {
            if canUseReplay {
                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        replayState.isEnabled ? "Replay mode is on" : "Replay mode is off",
                        systemImage: replayState.isEnabled ? "eye" : "eye.slash"
                    )
                    .font(.headline)

                    Button {
                        if !replayState.isEnabled {
                            replayState.isEnabled = true
                        }
                        showReplaySettings = true
                    } label: {
                        Label("Replay reveals", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.borderedProminent)

                    if replayState.isEnabled {
                        Text("\(revealedCategoriesCount) of \(totalCategories) categories revealed")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if isReplayLoading {
                            ProgressView("Loading replay data...")
                                .font(.caption)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            if !categories.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Categories: \(totalCategories)", systemImage: "list.number")
                        Spacer()
                        Label("Announced: \(completedCategories)", systemImage: "checkmark.circle")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if replayState.isEnabled {
                        HStack {
                            Label("Revealed: \(revealedCategoriesCount)", systemImage: "eye")
                            Spacer()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

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
                            displayScore: displayScore(for: participant),
                            isCurrentUser: participant.id == currentUserId
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    LeaderboardRow(
                        rank: index + 1,
                        participant: participant,
                        displayScore: displayScore(for: participant),
                        isCurrentUser: participant.id == currentUserId
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 8, for: .scrollContent)
    }

    private var sortedParticipants: [Participant] {
        participants.sorted { lhs, rhs in
            let lhsScore = displayScore(for: lhs)
            let rhsScore = displayScore(for: rhs)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func displayScore(for participant: Participant) -> Int {
        guard isReplayFeatureEnabled, replayState.isEnabled else { return participant.score }
        guard !isReplayLoading else { return participant.score }
        return replayScoresByParticipantId[participant.odUserId] ?? 0
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
                areCategoriesLoaded = true
            }
        } catch {
            // Silently fail - category counts are supplementary info
        }
    }

    private func loadCompetitionVotes() async {
        guard let competitionId = competition.id else { return }

        do {
            for try await updatedVotes in FirestoreService.shared.competitionVotesStream(competitionId: competitionId) {
                competitionVotes = updatedVotes
                areCompetitionVotesLoaded = true
            }
        } catch {
            // Silently fail - replay mode can remain unavailable if votes can't load.
        }
    }

    private func loadReplayState() {
        guard isReplayFeatureEnabled else {
            replayState = CompetitionReplayState()
            return
        }
        replayState = CompetitionReplayStore.load(
            competitionId: competition.id,
            userId: currentUserId
        )
    }

    private func saveReplayState(_ state: CompetitionReplayState) {
        CompetitionReplayStore.save(
            state,
            competitionId: competition.id,
            userId: currentUserId
        )
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
                    displayScore: participant.score,
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
    let replayState: CompetitionReplayState

    @Environment(\.dismiss) private var dismiss
    @State private var categories: [Category]
    @State private var votes: [Vote] = []
    @State private var isLoading = true

    init(participant: Participant, competition: Competition, categories: [Category], replayState: CompetitionReplayState) {
        self.participant = participant
        self.competition = competition
        self.replayState = replayState
        _categories = State(initialValue: categories)
    }

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

    private func isCategoryRevealed(_ category: Category) -> Bool {
        !replayState.isEnabled || replayState.revealedCategoryIds.contains(category.id ?? "")
    }

    private func winnerNames(for category: Category) -> String {
        ReplayScoring.winnerNames(for: category).joined(separator: "; ")
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
            await loadPicks()
        }
    }

    private var picksList: some View {
        List(visibleCategories) { category in
            let userVote = vote(for: category)
            let isRevealed = isCategoryRevealed(category)
            let isCorrect = userVote.map { isRevealed && ReplayScoring.isCorrect($0, for: category) } ?? false

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

                    if replayState.isEnabled && category.hasWinner && !isRevealed {
                        Text("Winner hidden in replay mode")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    } else if category.hasWinner, !winnerNames(for: category).isEmpty, !isCorrect {
                        HStack(spacing: 4) {
                            Text("Winner:")
                                .foregroundStyle(.secondary)
                            Text(winnerNames(for: category))
                                .foregroundStyle(.green)
                        }
                        .font(.callout)
                    }
                }

                Spacer()

                if category.hasWinner, userVote != nil, isRevealed {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isCorrect ? .green : .red)
                }
            }
            .padding(.vertical, 2)
        }
        .listStyle(.insetGrouped)
    }

    private func loadPicks() async {
        guard let competitionId = competition.id else {
            isLoading = false
            return
        }

        do {
            async let freshCategories = FirestoreService.shared.getCategories(
                for: competition.ceremonyYear,
                event: competition.event,
                source: .server
            )
            async let freshVotes = FirestoreService.shared.votesForUser(
                competitionId: competitionId,
                userId: participant.odUserId,
                source: .server
            )

            categories = try await freshCategories
            votes = try await freshVotes
        } catch {
            do {
                async let cachedCategories = FirestoreService.shared.getCategories(
                    for: competition.ceremonyYear,
                    event: competition.event,
                    source: .default
                )
                async let cachedVotes = FirestoreService.shared.votesForUser(
                    competitionId: competitionId,
                    userId: participant.odUserId,
                    source: .default
                )

                categories = try await cachedCategories
                votes = try await cachedVotes
            } catch {
                // Keep the injected categories so the sheet can still render.
            }
        }

        let knownCategoryIds = Set(categories.compactMap(\.id))
        let unmatchedVotes = votes.filter { !knownCategoryIds.contains($0.categoryId) }
        if !unmatchedVotes.isEmpty {
            print("Participant picks has \(unmatchedVotes.count) unmatched votes for \(participant.displayName) in competition \(competitionId)")
        }
        isLoading = false
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let participant: Participant
    let displayScore: Int
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

                Text("Score: \(displayScore)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(displayScore)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(displayScore == 1 ? "point" : "points")
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

struct CompetitionReplayState: Codable, Equatable {
    var isEnabled = false
    var revealedCategoryIds: Set<String> = []
}

private enum CompetitionReplayStore {
    static func load(competitionId: String?, userId: String?) -> CompetitionReplayState {
        guard let key = storageKey(competitionId: competitionId, userId: userId),
              let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(CompetitionReplayState.self, from: data) else {
            return CompetitionReplayState()
        }
        return state
    }

    static func save(_ state: CompetitionReplayState, competitionId: String?, userId: String?) {
        guard let key = storageKey(competitionId: competitionId, userId: userId),
              let data = try? JSONEncoder().encode(state) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func storageKey(competitionId: String?, userId: String?) -> String? {
        guard let competitionId else { return nil }
        return "ReplayState.\(userId ?? "anonymous").\(competitionId)"
    }
}

private enum ReplayScoring {
    static func revealedScore(
        votesByCategoryId: [String: Vote],
        categories: [Category],
        revealedCategoryIds: Set<String>
    ) -> Int {
        categories.reduce(into: 0) { score, category in
            guard let categoryId = category.id,
                  revealedCategoryIds.contains(categoryId),
                  let vote = votesByCategoryId[categoryId],
                  isCorrect(vote, for: category) else {
                return
            }
            score += 1
        }
    }

    static func isCorrect(_ vote: Vote, for category: Category) -> Bool {
        category.isCorrectNominee(vote.nomineeId)
    }

    static func winnerNames(for category: Category) -> [String] {
        category.resolvedCorrectNomineeIds.compactMap { nomineeId in
            category.nominees.first { $0.id == nomineeId }?.title
        }
    }
}

private struct ReplayRevealView: View {
    @Binding var replayState: CompetitionReplayState
    let categories: [Category]

    @Environment(\.dismiss) private var dismiss

    private var visibleCategories: [Category] {
        categories
            .filter { !$0.isHidden }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    var body: some View {
        NavigationStack {
            List(visibleCategories) { category in
                Toggle(isOn: isRevealedBinding(for: category)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                        if !category.hasWinner {
                            Text("Winner not available yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!category.hasWinner || category.id == nil)
            }
            .navigationTitle("Replay Reveals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func isRevealedBinding(for category: Category) -> Binding<Bool> {
        let categoryId = category.id ?? ""
        return Binding(
            get: {
                replayState.revealedCategoryIds.contains(categoryId)
            },
            set: { isRevealed in
                if isRevealed {
                    replayState.revealedCategoryIds.insert(categoryId)
                } else {
                    replayState.revealedCategoryIds.remove(categoryId)
                }
            }
        )
    }
}
