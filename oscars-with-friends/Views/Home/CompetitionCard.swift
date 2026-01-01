import SwiftUI

struct CompetitionCard: View {
    let competition: Competition
    var isDisabled: Bool = false

    private var isInactive: Bool {
        competition.status == .inactive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(competition.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text("\(competition.ceremonyYear) Academy Awards")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(status: competition.status)
            }

            HStack {
                Label("\(competition.participantCount)", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Code: \(competition.inviteCode)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .opacity(isInactive || isDisabled ? 0.5 : 1.0)
    }
}

struct StatusBadge: View {
    let status: CompetitionStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundStyle(status.color)
            .cornerRadius(6)
    }
}

extension CompetitionStatus {
    var displayName: String {
        switch self {
        case .open: return "Open"
        case .locked: return "Locked"
        case .complete: return "Complete"
        case .closed: return "Closed"
        case .inactive: return "Inactive"
        }
    }

    var color: Color {
        switch self {
        case .open: return .green
        case .locked: return .orange
        case .complete: return .blue
        case .closed: return .red
        case .inactive: return .gray
        }
    }
}

