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
    let event: String?
    let date: Timestamp?
    let status: CeremonyStatus
    let categoryCount: Int?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?

    var eventDisplayName: String {
        EventTypeCache.shared.displayName(for: event)
    }

    static func preview(name: String, year: String, event: String = "oscars", status: CeremonyStatus, categoryCount: Int = 23) -> Ceremony {
        Ceremony(
            id: UUID().uuidString,
            name: name,
            year: year,
            event: event,
            date: Timestamp(date: Date()),
            status: status,
            categoryCount: categoryCount,
            createdAt: Timestamp(date: Date()),
            updatedAt: Timestamp(date: Date())
        )
    }

    static var previewList: [Ceremony] {
        [
            Ceremony.preview(name: "97th Academy Awards", year: "2025", event: "oscars", status: .upcoming),
            Ceremony.preview(name: "Golden Globes 2026", year: "2026", event: "golden-globes", status: .upcoming),
            Ceremony.preview(name: "96th Academy Awards", year: "2024", event: "oscars", status: .completed),
        ]
    }
}
