import Foundation
import FirebaseFirestore

enum CeremonyStatus: String, Codable {
    case upcoming
    case live
    case complete
    case completed
}

struct Ceremony: Codable, Identifiable {
    @DocumentID var id: String?
    let name: String
    let year: String
    let date: Timestamp?
    let status: CeremonyStatus
    let categoryCount: Int?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
}
