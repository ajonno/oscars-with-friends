import Foundation
import FirebaseFirestore

enum CompetitionStatus: String, Codable {
    case open
    case locked
    case complete
    case closed
    case inactive
}

struct Competition: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let name: String
    let createdBy: String
    let ceremonyYear: String
    let event: String?
    let inviteCode: String
    let participantCount: Int
    let status: CompetitionStatus
    let hidden: Bool?
    let inactivatedAt: Timestamp?
    let createdAt: Timestamp
    let updatedAt: Timestamp

    var isOpen: Bool {
        status == .open || status == .locked
    }

    var canVote: Bool {
        status == .open
    }

    var eventDisplayName: String {
        EventTypeCache.shared.displayName(for: event)
    }

    func withStatus(_ newStatus: CompetitionStatus) -> Competition {
        Competition(
            id: id,
            name: name,
            createdBy: createdBy,
            ceremonyYear: ceremonyYear,
            event: event,
            inviteCode: inviteCode,
            participantCount: participantCount,
            status: newStatus,
            hidden: hidden,
            inactivatedAt: inactivatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func preview(name: String = "Oscar Pool 2026", event: String = "oscars", status: CompetitionStatus = .open) -> Competition {
        Competition(
            id: UUID().uuidString,
            name: name,
            createdBy: "user123",
            ceremonyYear: "2026",
            event: event,
            inviteCode: "ABC123",
            participantCount: 5,
            status: status,
            hidden: false,
            inactivatedAt: nil,
            createdAt: Timestamp(date: Date()),
            updatedAt: Timestamp(date: Date())
        )
    }
}
