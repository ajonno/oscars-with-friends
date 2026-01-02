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

    static func preview(name: String, score: Int) -> Participant {
        Participant(
            id: UUID().uuidString,
            odUserId: UUID().uuidString,
            displayName: name,
            photoUrl: nil,
            score: score,
            joinedAt: Timestamp(date: Date()),
            lastVotedAt: nil
        )
    }
}
