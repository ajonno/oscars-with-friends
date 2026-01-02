import SwiftUI
import FirebaseAuth

struct CompetitionDetailView: View {
    let initialCompetition: Competition

    @State private var competition: Competition
    @Environment(\.dismiss) private var dismiss
    @State private var showLeaveConfirmation = false
    @State private var isLeaving = false
    @State private var showShareSheet = false
    @State private var showInactiveConfirmation = false
    @State private var isTogglingInactive = false

    init(competition: Competition) {
        self.initialCompetition = competition
        self._competition = State(initialValue: competition)
    }

    private var isOwner: Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        return competition.createdBy == userId
    }

    private var isInactive: Bool {
        competition.status == .inactive
    }

    var body: some View {
        List {
            // Competition Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(competition.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Spacer()

                        if isOwner {
                            Text("Owner")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundStyle(.blue)
                                .cornerRadius(4)
                        }

                        StatusBadge(status: competition.status)
                    }

                    Text("\(competition.ceremonyYear) \(competition.eventDisplayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Label("\(competition.participantCount) participants", systemImage: "person.2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Invite Code Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invite Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(competition.inviteCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                    }

                    Spacer()

                    Button {
                        UIPasteboard.general.string = competition.inviteCode
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    ShareLink(
                        item: "Join my Oscar predictions competition! Use code: \(competition.inviteCode)"
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            } footer: {
                Text("Share this code with friends to invite them")
            }

            // Actions Section
            Section {
                NavigationLink {
                    LeaderboardView(competition: competition)
                } label: {
                    Label("Leaderboard", systemImage: "trophy")
                }
            }

            // Owner Actions Section
            if isOwner {
                Section {
                    Button(role: isInactive ? nil : .destructive) {
                        showInactiveConfirmation = true
                    } label: {
                        HStack {
                            Label(
                                isInactive ? "Reactivate Competition" : "Set as Inactive",
                                systemImage: isInactive ? "checkmark.circle" : "pause.circle"
                            )
                            .foregroundStyle(isInactive ? .blue : .red)

                            if isTogglingInactive {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isTogglingInactive)
                } footer: {
                    Text(isInactive
                         ? "Reactivating will allow participants to access the competition again"
                         : "Inactive competitions are hidden from participants")
                }
            }

            // Leave Section (only for non-owners)
            if !isOwner {
                Section {
                    Button(role: .destructive) {
                        showLeaveConfirmation = true
                    } label: {
                        HStack {
                            Label("Leave Competition", systemImage: "rectangle.portrait.and.arrow.right")

                            if isLeaving {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLeaving)
                }
            }
        }
        .navigationTitle("Competition")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Leave Competition",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                Task {
                    await leaveCompetition()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to leave \"\(competition.name)\"? Your votes will be deleted.")
        }
        .confirmationDialog(
            isInactive ? "Reactivate Competition" : "Set Competition as Inactive",
            isPresented: $showInactiveConfirmation,
            titleVisibility: .visible
        ) {
            Button(isInactive ? "Reactivate" : "Set Inactive", role: isInactive ? nil : .destructive) {
                Task {
                    await toggleInactive()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isInactive
                 ? "This will make the competition accessible to all participants again."
                 : "Participants will no longer be able to access this competition. You can reactivate it later.")
        }
    }

    private func leaveCompetition() async {
        isLeaving = true

        do {
            try await CloudFunctionsService.shared.leaveCompetition(competitionId: competition.id!)
            dismiss()
        } catch {
            // Handle error - could show alert
            print("Failed to leave competition: \(error)")
        }

        isLeaving = false
    }

    private func toggleInactive() async {
        isTogglingInactive = true
        let newInactiveState = !isInactive

        do {
            _ = try await CloudFunctionsService.shared.setCompetitionInactive(
                competitionId: competition.id!,
                inactive: newInactiveState
            )
            // Update local state to reflect the change
            competition = competition.withStatus(newInactiveState ? .inactive : .open)
        } catch {
            print("Failed to toggle inactive: \(error)")
        }

        isTogglingInactive = false
    }
}

