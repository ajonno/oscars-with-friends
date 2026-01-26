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
    @State private var hasAnyCompetition: Bool = false  // User is in at least one competition for this ceremony
    @State private var openCompetitionCount: Int = 0    // Count of open competitions (can vote)
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedCategory: Category?
    @State private var showInviteSheet = false

    // Show votes if user has ANY competition for this ceremony (not just open ones)
    private var activeVotes: [String: Vote] {
        hasAnyCompetition ? votes : [:]
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInviteSheet = true
                } label: {
                    Image(systemName: "person.2")
                        .foregroundStyle(.blue)
                }
            }
        }
        .inviteFriendsSheet(isPresented: $showInviteSheet)
        .task {
            await loadData()
        }
        .sheet(item: $selectedCategory) { category in
            CategoryViewSheet(
                category: category,
                ceremonyYear: ceremony.year,
                initialVote: votes[category.id ?? ""],
                hasActiveCompetition: openCompetitionCount > 0,
                onVoteConfirmed: { vote in
                    // Immediately update local votes so UI refreshes
                    if let categoryId = category.id {
                        votes[categoryId] = vote
                    }
                }
            )
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
                            .foregroundStyle(openCompetitionCount > 0 ? .blue : .orange)
                        if openCompetitionCount > 0 {
                            Text("You can vote in \(openCompetitionCount) active \(openCompetitionCount == 1 ? "competition" : "competitions")")
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
                        selectedCategory = category
                    } label: {
                        BrowseCategoryRow(category: category, vote: activeVotes[category.id ?? ""])
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
        .contentMargins(.top, 10, for: .scrollContent)
        .listSectionSpacing(20)
    }

    private func loadData() async {
        // Listen for categories
        Task {
            do {
                for try await updatedCategories in FirestoreService.shared.categoriesStream(for: ceremony.year, event: ceremony.event) {
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
                for try await updatedVotes in FirestoreService.shared.myCeremonyVotesStream(ceremonyYear: ceremony.year, event: ceremony.event) {
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
                    // All competitions for this ceremony (to show votes)
                    let allForCeremony = competitions.filter { comp in
                        guard comp.ceremonyYear == ceremony.year && comp.status != .inactive else {
                            return false
                        }
                        // Match by event (nil matches anything)
                        if let compEvent = comp.event, let ceremonyEvent = ceremony.event {
                            return compEvent == ceremonyEvent
                        }
                        return true // Either event is nil, allow match
                    }
                    hasAnyCompetition = !allForCeremony.isEmpty

                    // Only open competitions (to enable voting)
                    let openForCeremony = allForCeremony.filter { $0.status == .open }
                    openCompetitionCount = openForCeremony.count
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

    private var votedNominee: Nominee? {
        guard let vote else { return nil }
        return category.nominees.first { $0.id == vote.nomineeId }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let votedNominee {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Your pick: \(votedNominee.title)")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption)

                    if let subtitle = votedNominee.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                    }
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
        .contentShape(Rectangle())
    }
}

struct CategoryViewSheet: View {
    let category: Category
    let ceremonyYear: String
    let initialVote: Vote?
    let hasActiveCompetition: Bool
    var onVoteConfirmed: ((Vote) -> Void)?  // Callback to notify parent of confirmed vote

    @Environment(\.dismiss) private var dismiss
    @State private var currentVote: Vote?
    @State private var selectedNomineeId: String?
    @State private var isVoting = false
    @State private var error: String?
    @State private var showVoteSuccess = false
    @State private var pendingNomineeId: String?  // The nominee we're waiting to confirm

    private var canVote: Bool {
        !category.isVotingLocked && !category.hasWinner && hasActiveCompetition
    }

    private var votingDisabledReason: String? {
        if category.hasWinner { return nil }
        if category.isVotingLocked { return nil }
        if !hasActiveCompetition {
            return "Join a competition to vote on awards!"
        }
        return nil
    }

    private var hasChanges: Bool {
        selectedNomineeId != nil && selectedNomineeId != currentVote?.nomineeId
    }

    var body: some View {
        NavigationStack {
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
                                dismiss()
                                NotificationCenter.default.post(name: .switchToCompetitionsTab, object: nil)
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
                            let isDefinitelyLocked = category.isVotingLocked || category.hasWinner || !hasActiveCompetition
                            NomineeVoteRow(
                                nominee: nominee,
                                isSelected: selectedNomineeId == nominee.id,
                                isWinner: category.winnerId == nominee.id,
                                isLocked: isDefinitelyLocked,
                                onTap: {
                                    if !isDefinitelyLocked {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedNomineeId = nominee.id
                                        }
                                    }
                                }
                            )
                        }
                    }
                    // Vote Button - inside the nominees section
                    if canVote {
                        Button {
                            Task {
                                await castVote()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if isVoting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(currentVote != nil ? "Update Prediction" : "Submit Prediction")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(
                                hasChanges && !isVoting
                                    ? Color.blue
                                    : Color.gray.opacity(0.4)
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasChanges || isVoting)
                        .listRowSeparator(.hidden)
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
            .navigationBarTitleDisplayMode(.inline)
            .contentMargins(.top, category.hasWinner || votingDisabledReason != nil ? 8 : -10, for: .scrollContent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Initialize from passed data
            currentVote = initialVote
            selectedNomineeId = initialVote?.nomineeId
        }
        .task {
            // Set up live vote listener for this category
            guard let categoryId = category.id else { return }
            do {
                for try await vote in FirestoreService.shared.myCategoryVoteStream(
                    ceremonyYear: ceremonyYear,
                    categoryId: categoryId,
                    event: category.event
                ) {
                    currentVote = vote
                    // If we have no selection yet, use the vote's nominee
                    if selectedNomineeId == nil {
                        selectedNomineeId = vote?.nomineeId
                    }
                    // Check if we were waiting for this vote to be confirmed
                    if let pending = pendingNomineeId, let confirmedVote = vote, confirmedVote.nomineeId == pending {
                        // Vote confirmed! Notify parent and dismiss the sheet
                        showVoteSuccess = true
                        pendingNomineeId = nil
                        isVoting = false
                        onVoteConfirmed?(confirmedVote)
                        try? await Task.sleep(for: .milliseconds(200))
                        dismiss()
                    }
                }
            } catch {
                // Handle silently
            }
        }
        .sensoryFeedback(.success, trigger: showVoteSuccess)
    }

    private func castVote() async {
        guard let nomineeId = selectedNomineeId,
              let categoryId = category.id else { return }

        isVoting = true
        error = nil
        pendingNomineeId = nomineeId  // Mark which nominee we're waiting to confirm

        do {
            _ = try await CloudFunctionsService.shared.castCeremonyVote(
                ceremonyYear: ceremonyYear,
                categoryId: categoryId,
                nomineeId: nomineeId
            )
            // Don't dismiss here - wait for the vote listener to confirm
            // The .task listener will detect the vote and dismiss

            // Add a timeout in case the listener doesn't catch it
            Task {
                try? await Task.sleep(for: .seconds(5))
                if pendingNomineeId != nil {
                    // Timeout - dismiss anyway since cloud function succeeded
                    pendingNomineeId = nil
                    isVoting = false
                    dismiss()
                }
            }
        } catch {
            self.error = error.localizedDescription
            pendingNomineeId = nil
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

// MARK: - Previews

#Preview("Category Vote Sheet") {
    CategoryVoteSheetPreview()
}

private struct CategoryVoteSheetPreview: View {
    @State private var selectedNomineeId: String? = nil

    private let category = Category.preview(name: "Best Picture")

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(category.nominees) { nominee in
                        NomineeVoteRow(
                            nominee: nominee,
                            isSelected: selectedNomineeId == nominee.id,
                            isWinner: false,
                            isLocked: false,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedNomineeId = nominee.id
                                }
                            }
                        )
                    }

                    Button {
                        // Preview action
                    } label: {
                        HStack {
                            Spacer()
                            Text("Submit Prediction")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(selectedNomineeId != nil ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedNomineeId == nil)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Select your prediction")
                }
            }
            .navigationTitle("Best Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {}
                }
            }
        }
    }
}
