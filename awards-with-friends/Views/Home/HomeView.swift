import SwiftUI
import FirebaseAuth
import FirebaseCore

enum CompetitionFilter: String, CaseIterable {
    case all = "All"
    case mine = "Mine"
    case joined = "Joined"
}

struct HomeView: View {
    @State private var competitions: [Competition] = []
    @State private var isLoading = true
    @State private var showCreateCompetition = false
    @State private var showJoinCompetition = false
    @State private var selectedCompetition: Competition?
    @State private var leaderboardCompetition: Competition?
    @State private var error: String?
    @State private var filter: CompetitionFilter = .all
    @State private var refreshTrigger = UUID()

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private var filteredCompetitions: [Competition] {
        guard let userId = currentUserId else { return sortedCompetitions }

        let filtered: [Competition]
        switch filter {
        case .all:
            filtered = sortedCompetitions
        case .mine:
            filtered = sortedCompetitions.filter { $0.createdBy == userId }
        case .joined:
            filtered = sortedCompetitions.filter { $0.createdBy != userId }
        }
        return filtered
    }

    private var sortedCompetitions: [Competition] {
        competitions.sorted { comp1, comp2 in
            // Inactive competitions go to the bottom
            if comp1.status == .inactive && comp2.status != .inactive {
                return false
            }
            if comp1.status != .inactive && comp2.status == .inactive {
                return true
            }
            // Otherwise sort by creation date (newest first)
            return comp1.createdAt.dateValue() > comp2.createdAt.dateValue()
        }
    }

    private func isCompetitionTappable(_ competition: Competition) -> Bool {
        guard let userId = currentUserId else { return false }
        // Inactive competitions can only be tapped by the owner
        if competition.status == .inactive {
            return competition.createdBy == userId
        }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !competitions.isEmpty {
                    Picker("Filter", selection: $filter) {
                        ForEach(CompetitionFilter.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Group {
                    if isLoading {
                        Spacer()
                        ProgressView("Loading competitions...")
                        Spacer()
                    } else if competitions.isEmpty {
                        emptyState
                    } else if filteredCompetitions.isEmpty {
                        filteredEmptyState
                    } else {
                        competitionsList
                    }
                }
            }
            .navigationTitle("Competitions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showCreateCompetition = true
                        } label: {
                            Label("Create Competition", systemImage: "plus.circle")
                        }

                        Button {
                            showJoinCompetition = true
                        } label: {
                            Label("Join Competition", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateCompetition) {
                CreateCompetitionView()
            }
            .sheet(isPresented: $showJoinCompetition) {
                JoinCompetitionView()
            }
            .onChange(of: showCreateCompetition) { _, isShowing in
                if !isShowing {
                    refreshTrigger = UUID()
                }
            }
            .onChange(of: showJoinCompetition) { _, isShowing in
                if !isShowing {
                    refreshTrigger = UUID()
                }
            }
            .navigationDestination(item: $selectedCompetition) { competition in
                CompetitionDetailView(competition: competition)
            }
            .navigationDestination(item: $leaderboardCompetition) { competition in
                LeaderboardView(competition: competition)
            }
            .task(id: refreshTrigger) {
                await loadCompetitions()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Competitions", systemImage: "trophy")
        } description: {
            Text("Create a new competition or join one with an invite code")
        } actions: {
            HStack(spacing: 16) {
                Button("Create") {
                    showCreateCompetition = true
                }
                .buttonStyle(.borderedProminent)

                Button("Join") {
                    showJoinCompetition = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var filteredEmptyState: some View {
        ContentUnavailableView {
            Label(filter == .mine ? "No Competitions Created" : "No Competitions Joined", systemImage: "trophy")
        } description: {
            Text(filter == .mine
                 ? "You haven't created any competitions yet"
                 : "You haven't joined any competitions from others")
        } actions: {
            Button(filter == .mine ? "Create Competition" : "Join Competition") {
                if filter == .mine {
                    showCreateCompetition = true
                } else {
                    showJoinCompetition = true
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var competitionsList: some View {
        List(filteredCompetitions) { competition in
            let isTappable = isCompetitionTappable(competition)

            CompetitionCard(
                competition: competition,
                isDisabled: !isTappable,
                onLeaderboardTap: {
                    leaderboardCompetition = competition
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if isTappable {
                    selectedCompetition = competition
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private func loadCompetitions() async {
        isLoading = true
        error = nil

        do {
            for try await updatedCompetitions in FirestoreService.shared.myCompetitionsStream() {
                competitions = updatedCompetitions
                isLoading = false
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview("Home View") {
    HomeView()
}

#Preview("With Competitions") {
    HomeViewPreview()
}

private struct HomeViewPreview: View {
    var body: some View {
        NavigationStack {
            List {
                // Filter picker
                Picker("Filter", selection: .constant(CompetitionFilter.all)) {
                    ForEach(CompetitionFilter.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Sample competitions
                ForEach(0..<3) { i in
                    CompetitionCard(
                        competition: Competition.preview(
                            name: ["Oscar Pool 2026", "Family Picks", "Movie Buffs"][i],
                            status: [.open, .open, .inactive][i]
                        ),
                        onLeaderboardTap: {}
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Competitions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
