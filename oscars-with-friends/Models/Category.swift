import Foundation
import FirebaseFirestore

struct Nominee: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let imageUrl: String
    let tmdbId: String?
}

struct Category: Codable, Identifiable {
    @DocumentID var id: String?
    let ceremonyYear: String
    let name: String
    let displayOrder: Int
    let winnerId: String?
    let winnerAnnouncedAt: Timestamp?
    let votingLocked: Bool?
    let votingLockedAt: Timestamp?
    let hidden: Bool?
    let nominees: [Nominee]
    let createdAt: Timestamp
    let updatedAt: Timestamp

    var isVotingLocked: Bool {
        votingLocked == true
    }

    var isHidden: Bool {
        hidden == true
    }

    var hasWinner: Bool {
        winnerId != nil
    }

    var winner: Nominee? {
        guard let winnerId else { return nil }
        return nominees.first { $0.id == winnerId }
    }
}
