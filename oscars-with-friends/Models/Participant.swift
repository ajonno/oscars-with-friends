import Foundation
import FirebaseFirestore

struct Participant: Codable, Identifiable {
    @DocumentID var id: String?
    let odUserId: String
    let displayName: String
    let photoUrl: String?
    let score: Int
    let joinedAt: Timestamp
    let lastVotedAt: Timestamp?

    var odUserIdValue: String {
        id ?? odUserId
    }
}
