import SwiftUI
import Kingfisher

struct CategoriesListView: View {
    let competition: Competition

    @State private var categories: [Category] = []
    @State private var votes: [String: Vote] = [:] // categoryId -> Vote
    @State private var isLoading = true
    @State private var error: String?

    private var votedCount: Int {
        categories.filter { votes[$0.id!] != nil }.count
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
        .navigationTitle("Vote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Vote")
                        .font(.headline)
                    Text("\(votedCount)/\(categories.count) predictions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private var categoriesList: some View {
        List {
            ForEach(categories) { category in
                NavigationLink {
                    CategoryDetailView(
                        categoryId: category.id!,
                        competition: competition
                    )
                } label: {
                    CategoryRow(
                        category: category,
                        vote: votes[category.id!]
                    )
                }
            }
        }
    }

    private func loadData() async {
        // Listen for categories
        Task {
            do {
                for try await updatedCategories in FirestoreService.shared.categoriesStream(for: competition.ceremonyYear) {
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
            guard let competitionId = competition.id else { return }
            do {
                for try await updatedVotes in FirestoreService.shared.myVotesStream(competitionId: competitionId) {
                    votes = Dictionary(uniqueKeysWithValues: updatedVotes.map { ($0.categoryId, $0) })
                }
            } catch {
                // Handle silently
            }
        }
    }
}

struct CategoryRow: View {
    let category: Category
    let vote: Vote?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)

                if let votedNomineeTitle = votedNomineeTitle {
                    Text("Your pick: \(votedNomineeTitle)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if let winner = category.winner {
                    Text("Winner: \(winner.title)")
                        .font(.caption)
                        .foregroundStyle(.green)
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

                statusIcon
            }
        }
        .padding(.vertical, 4)
    }

    private var votedNomineeTitle: String? {
        guard let vote = vote else { return nil }
        return category.nominees.first { $0.id == vote.nomineeId }?.title
    }

    private var statusIcon: some View {
        Group {
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
        }
    }
}
