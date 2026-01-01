import SwiftUI
import Kingfisher

extension String: @retroactive Identifiable {
    public var id: String { self }
}

extension Notification.Name {
    static let switchToCompetitionsTab = Notification.Name("switchToCompetitionsTab")
}

struct CeremonyDetailView: View {
    let ceremony: Ceremony

    @State private var categories: [Category] = []
    @State private var votes: [String: Vote] = [:] // categoryId -> Vote
    @State private var competitionCount: Int = 0
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedCategoryId: String?

    // Only show votes if user has active competitions
    private var activeVotes: [String: Vote] {
        competitionCount > 0 ? votes : [:]
    }

    private var votedCount: Int {
        categories.filter { activeVotes[$0.id ?? ""] != nil }.count
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading categories...")
            } else if categories.isEmpty {
                ContentUnavailableView(
                    "No Categories",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Categories haven't been added yet")
                )
            } else {
                categoriesList
            }
        }
        .navigationTitle(ceremony.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(ceremony.name)
                        .font(.headline)
                    if !categories.isEmpty {
                        Text("\(votedCount)/\(categories.count) predictions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .sheet(item: $selectedCategoryId) { categoryId in
            CategoryViewSheet(categoryId: categoryId, ceremonyYear: ceremony.year)
        }
    }

    private var categoriesList: some View {
        List {
            Section {
                Button {
                    NotificationCenter.default.post(name: .switchToCompetitionsTab, object: nil)
                } label: {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(competitionCount > 0 ? .blue : .orange)
                        if competitionCount > 0 {
                            Text("You can vote in \(competitionCount) active \(competitionCount == 1 ? "competition" : "competitions")")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Join a competition to vote on awards!")
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
            }

            Section {
                ForEach(categories) { category in
                    Button {
                        selectedCategoryId = category.id
                    } label: {
                        BrowseCategoryRow(category: category, vote: activeVotes[category.id ?? ""])
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    private func loadData() async {
        // Listen for categories
        Task {
            do {
                for try await updatedCategories in FirestoreService.shared.categoriesStream(for: ceremony.year) {
                    categories = updatedCategories.sorted { $0.displayOrder < $1.displayOrder }
                    if isLoading {
                        isLoading = false
                    }
                }
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }

        // Listen for votes
        Task {
            do {
                for try await updatedVotes in FirestoreService.shared.myCeremonyVotesStream(ceremonyYear: ceremony.year) {
                    votes = updatedVotes
                }
            } catch {
                // Handle silently
            }
        }

        // Listen for competitions count
        Task {
            do {
                for try await competitions in FirestoreService.shared.myCompetitionsStream() {
                    let activeForCeremony = competitions.filter {
                        $0.ceremonyYear == ceremony.year && $0.status == .open
                    }
                    competitionCount = activeForCeremony.count
                }
            } catch {
                // Handle silently
            }
        }
    }
}

struct BrowseCategoryRow: View {
    let category: Category
    let vote: Vote?

    private var votedNomineeTitle: String? {
        guard let vote else { return nil }
        return category.nominees.first { $0.id == vote.nomineeId }?.title
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let votedNomineeTitle {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Your pick: \(votedNomineeTitle)")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption)
                } else {
                    Text("\(category.nominees.count) nominees")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let winner = category.winner {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("Winner: \(winner.title)")
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if category.isVotingLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                if category.hasWinner {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }

                // Vote status indicator
                if vote != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if category.isVotingLocked {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.gray)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CategoryViewSheet: View {
    let categoryId: String
    let ceremonyYear: String
    @Environment(\.dismiss) private var dismiss
    @State private var category: Category?
    @State private var currentVote: Vote?
    @State private var selectedNomineeId: String?
    @State private var isVoting = false
    @State private var error: String?
    @State private var showVoteSuccess = false
    @State private var hasActiveCompetition = false
    @State private var showJoinCompetitionPrompt = false

    private var canVote: Bool {
        guard let category else { return false }
        return !category.isVotingLocked && !category.hasWinner && hasActiveCompetition
    }

    private var votingDisabledReason: String? {
        guard let category else { return nil }
        if category.hasWinner { return nil }
        if category.isVotingLocked { return nil }
        if !hasActiveCompetition { return "Join a competition to vote on awards!" }
        return nil
    }

    private var hasChanges: Bool {
        selectedNomineeId != nil && selectedNomineeId != currentVote?.nomineeId
    }

    var body: some View {
        NavigationStack {
            Group {
                if let category {
                    List {
                        // Status Section
                        if category.isVotingLocked && !category.hasWinner {
                            Section {
                                Label("Voting is locked for this category", systemImage: "lock.fill")
                                    .foregroundStyle(.orange)
                            }
                        }

                        // Winner Section
                        if category.hasWinner, let winner = category.winner {
                            Section {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Winner -")
                                        Image(systemName: "trophy.fill")
                                            .foregroundStyle(.yellow)
                                        Text(winner.title)
                                    }
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                    if let subtitle = winner.subtitle {
                                        Text(subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let url = URL(string: winner.imageUrl) {
                                        KFImage(url)
                                            .placeholder {
                                                ProgressView()
                                                    .frame(height: 200)
                                            }
                                            .fade(duration: 0.25)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 250)
                                            .cornerRadius(12)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        }

                        // Join Competition Prompt
                        if let reason = votingDisabledReason {
                            Section {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.3.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.blue)

                                    Text(reason)
                                        .font(.headline)
                                        .multilineTextAlignment(.center)

                                    Text("Create or join a competition with friends to start voting on the Oscars!")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)

                                    Button {
                                        showJoinCompetitionPrompt = true
                                    } label: {
                                        Text("Go to Competitions")
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        }

                        // Nominees Section
                        Section {
                            if category.nominees.isEmpty {
                                Text("No nominees available")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(category.nominees) { nominee in
                                    NomineeVoteRow(
                                        nominee: nominee,
                                        isSelected: selectedNomineeId == nominee.id,
                                        isWinner: category.winnerId == nominee.id,
                                        isLocked: !canVote,
                                        onTap: {
                                            if canVote {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    selectedNomineeId = nominee.id
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        } header: {
                            Text(canVote ? "Select your prediction" : "Nominees")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if canVote {
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
                        .disabled(!hasChanges || isVoting)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .sensoryFeedback(.success, trigger: showVoteSuccess)
        .alert("Join a Competition", isPresented: $showJoinCompetitionPrompt) {
            Button("Go to Competitions") {
                dismiss()
                // Post notification to switch to competitions tab
                NotificationCenter.default.post(name: .switchToCompetitionsTab, object: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To make predictions, you need to create or join a competition first.")
        }
    }

    private func loadData() async {
        // Listen for category updates
        Task {
            do {
                for try await categories in FirestoreService.shared.categoriesStream(for: ceremonyYear) {
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
                for try await votes in FirestoreService.shared.myCeremonyVotesStream(ceremonyYear: ceremonyYear) {
                    if let vote = votes[categoryId] {
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

        // Check for active competitions
        Task {
            await checkForActiveCompetitions()
        }
    }

    private func checkForActiveCompetitions() async {
        do {
            for try await competitions in FirestoreService.shared.myCompetitionsStream() {
                let activeForCeremony = competitions.filter {
                    $0.ceremonyYear == ceremonyYear && $0.status == .open
                }
                hasActiveCompetition = !activeForCeremony.isEmpty
            }
        } catch {
            // Handle silently
        }
    }

    private func castVote() async {
        guard let nomineeId = selectedNomineeId else { return }

        isVoting = true
        error = nil

        do {
            _ = try await CloudFunctionsService.shared.castCeremonyVote(
                ceremonyYear: ceremonyYear,
                categoryId: categoryId,
                nomineeId: nomineeId
            )
            showVoteSuccess = true
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isVoting = false
        }
    }
}

struct NomineeVoteRow: View {
    let nominee: Nominee
    let isSelected: Bool
    let isWinner: Bool
    let isLocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator (only show if voting is open)
                if !isLocked {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .gray)
                        .font(.title2)
                }

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
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

struct NomineeViewRow: View {
    let nominee: Nominee
    let isWinner: Bool

    var body: some View {
        HStack(spacing: 12) {
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
        .padding(.vertical, 4)
    }
}
