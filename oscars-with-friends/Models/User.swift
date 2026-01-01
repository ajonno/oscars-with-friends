import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    let email: String
    let displayName: String
    let photoUrl: String?
    let fcmTokens: [String]
    let createdAt: Timestamp
    let updatedAt: Timestamp

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case photoUrl
        case fcmTokens
        case createdAt
        case updatedAt
    }
}
