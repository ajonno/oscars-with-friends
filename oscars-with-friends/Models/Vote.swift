import Foundation
import FirebaseFirestore

struct Vote: Codable, Identifiable {
    @DocumentID var id: String?
    let odUserId: String
    let categoryId: String
    let nomineeId: String
    let votedAt: Timestamp
    let isCorrect: Bool?
}
