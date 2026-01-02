import SwiftUI
import FirebaseCore

struct CeremoniesListView: View {
    @State private var ceremonies: [Ceremony] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading ceremonies...")
                } else if ceremonies.isEmpty {
                    ContentUnavailableView(
                        "No Ceremonies",
                        systemImage: "calendar",
                        description: Text("No ceremonies available yet")
                    )
                } else {
                    ceremoniesList
                }
            }
            .navigationTitle("Ceremonies")
        }
        .task {
            await loadCeremonies()
        }
    }

    private var ceremoniesList: some View {
        List(ceremonies) { ceremony in
            NavigationLink {
                CeremonyDetailView(ceremony: ceremony)
            } label: {
                CeremonyRow(ceremony: ceremony)
            }
            .contentShape(Rectangle())
        }
    }

    private func loadCeremonies() async {
        isLoading = true
        error = nil

        do {
            for try await updatedCeremonies in FirestoreService.shared.ceremoniesStream() {
                ceremonies = updatedCeremonies
                isLoading = false
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}

struct CeremonyRow: View {
    let ceremony: Ceremony
    @State private var fetchedCategoryCount: Int?

    private var categoryCount: Int? {
        ceremony.categoryCount ?? fetchedCategoryCount
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(.yellow)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(ceremony.name)
                    .font(.headline)

                Text(ceremony.eventDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let date = ceremony.date {
                    Text(date.dateValue(), style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    if let count = categoryCount {
                        Text("\(count) categories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }

                    Spacer()

                    statusBadge
                        .fixedSize()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .task {
            // Listen for category count in real-time if not stored on ceremony
            if ceremony.categoryCount == nil, let eventId = ceremony.event {
                do {
                    for try await categories in FirestoreService.shared.categoriesStream(
                        for: ceremony.year,
                        event: eventId
                    ) {
                        fetchedCategoryCount = categories.count
                    }
                } catch {
                    // Silently fail - just won't show count
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch ceremony.status {
        case .upcoming:
            Text("Upcoming")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .foregroundStyle(.blue)
                .cornerRadius(4)
        case .live:
            Text("Live")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.2))
                .foregroundStyle(.red)
                .cornerRadius(4)
        case .complete, .completed:
            Text("Completed")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .foregroundStyle(.green)
                .cornerRadius(4)
        }
    }
}

#Preview("Ceremonies List") {
    CeremoniesListPreview()
}

private struct CeremoniesListPreview: View {
    var body: some View {
        NavigationStack {
            List(Ceremony.previewList) { ceremony in
                NavigationLink {
                    Text(ceremony.name)
                } label: {
                    CeremonyRow(ceremony: ceremony)
                }
            }
            .navigationTitle("Ceremonies")
        }
    }
}
