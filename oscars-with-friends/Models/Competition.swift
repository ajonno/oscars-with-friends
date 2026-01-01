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
    let inviteCode: String
    let participantCount: Int
    let status: CompetitionStatus
    let inactivatedAt: Timestamp?
    let createdAt: Timestamp
    let updatedAt: Timestamp

    var isOpen: Bool {
        status == .open || status == .locked
    }

    var canVote: Bool {
        status == .open || status == .locked
    }

    func withStatus(_ newStatus: CompetitionStatus) -> Competition {
        Competition(
            id: id,
            name: name,
            createdBy: createdBy,
            ceremonyYear: ceremonyYear,
            inviteCode: inviteCode,
            participantCount: participantCount,
            status: newStatus,
            inactivatedAt: inactivatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
