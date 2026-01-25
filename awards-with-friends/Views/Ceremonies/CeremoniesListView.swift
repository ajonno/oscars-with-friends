import SwiftUI
import FirebaseCore

struct CeremoniesListView: View {
    @State private var ceremonies: [Ceremony] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedEvent: String? = nil
    @State private var showInviteSheet = false

    private var eventNames: [String] {
        let names = Set(ceremonies.map { $0.eventDisplayName })
        return Array(names).sorted()
    }

    private var filteredCeremonies: [Ceremony] {
        let visibleCeremonies = ceremonies.filter { $0.hidden != true }
        guard let selectedEvent else { return visibleCeremonies }
        return visibleCeremonies.filter { $0.eventDisplayName == selectedEvent }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Award Ceremonies")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        showInviteSheet = true
                    } label: {
                        Image(systemName: "person.2")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .offset(y: 3)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

                if !ceremonies.isEmpty {
                    eventFilter
                }

                if isLoading {
                    Spacer()
                    ProgressView("Loading ceremonies...")
                    Spacer()
                } else if ceremonies.isEmpty {
                    ContentUnavailableView(
                        "No Ceremonies",
                        systemImage: "calendar",
                        description: Text("No ceremonies available yet")
                    )
                } else if filteredCeremonies.isEmpty {
                    ContentUnavailableView(
                        "No Ceremonies",
                        systemImage: "calendar",
                        description: Text("No ceremonies for this event")
                    )
                } else {
                    ceremoniesList
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .inviteFriendsSheet(isPresented: $showInviteSheet)
        }
        .task {
            await loadCeremonies()
        }
    }

    private var eventFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedEvent == nil) {
                    selectedEvent = nil
                }

                ForEach(eventNames, id: \.self) { eventName in
                    FilterChip(title: eventName, isSelected: selectedEvent == eventName) {
                        selectedEvent = eventName
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    private var ceremoniesList: some View {
        List(filteredCeremonies) { ceremony in
            NavigationLink {
                CeremonyDetailView(ceremony: ceremony)
            } label: {
                CeremonyRow(ceremony: ceremony)
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 8, for: .scrollContent)
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

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invite Friends Component

struct InviteFriendsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showShareSheet: Bool

    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .bottom, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 28, height: 40)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow)
                    .frame(width: 28, height: 56)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.orange.opacity(0.7))
                    .frame(width: 28, height: 28)
            }
            .padding(.top, 8)

            VStack(spacing: 12) {
                Text("Invite Your Friends")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Awards With Friends is more fun with friends! Share the app and start competing to see who can predict the most winners.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button {
                    dismiss()
                    showShareSheet = true
                } label: {
                    Text("Invite")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }

                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct InviteFriendsModifier: ViewModifier {
    @Binding var showInviteSheet: Bool
    @State private var showShareSheet = false

    private let shareMessage = "Hey! I just installed Awards With Friends. You should grab it too so we can compete!\n\nhttps://apps.apple.com/app/id1638720136"

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showInviteSheet) {
                InviteFriendsSheet(showShareSheet: $showShareSheet)
                    .presentationDetents([.fraction(0.45)])
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareMessage])
                    .presentationDetents([.medium])
            }
    }
}

extension View {
    func inviteFriendsSheet(isPresented: Binding<Bool>) -> some View {
        modifier(InviteFriendsModifier(showInviteSheet: isPresented))
    }
}

// MARK: - Previews

#Preview("Ceremonies List") {
    CeremoniesListPreview()
}

private struct CeremoniesListPreview: View {
    @State private var selectedEvent: String? = nil

    private var eventNames: [String] {
        let names = Set(Ceremony.previewList.map { $0.eventDisplayName })
        return Array(names).sorted()
    }

    private var filteredCeremonies: [Ceremony] {
        guard let selectedEvent else { return Ceremony.previewList }
        return Ceremony.previewList.filter { $0.eventDisplayName == selectedEvent }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Award Ceremonies")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedEvent == nil) {
                            selectedEvent = nil
                        }

                        ForEach(eventNames, id: \.self) { eventName in
                            FilterChip(title: eventName, isSelected: selectedEvent == eventName) {
                                selectedEvent = eventName
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                List(filteredCeremonies) { ceremony in
                    NavigationLink {
                        Text(ceremony.name)
                    } label: {
                        CeremonyRow(ceremony: ceremony)
                    }
                }
                .listStyle(.insetGrouped)
                .contentMargins(.top, 0, for: .scrollContent)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
