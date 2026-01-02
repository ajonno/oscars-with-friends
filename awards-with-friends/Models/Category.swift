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
    let event: String?
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

    static func preview(name: String, event: String = "oscars", nominees: [Nominee] = Nominee.previewList) -> Category {
        Category(
            id: UUID().uuidString,
            ceremonyYear: "2026",
            event: event,
            name: name,
            displayOrder: 0,
            winnerId: nil,
            winnerAnnouncedAt: nil,
            votingLocked: false,
            votingLockedAt: nil,
            hidden: false,
            nominees: nominees,
            createdAt: Timestamp(date: Date()),
            updatedAt: Timestamp(date: Date())
        )
    }
}

extension Nominee {
    static func preview(title: String, subtitle: String? = nil) -> Nominee {
        Nominee(
            id: UUID().uuidString,
            title: title,
            subtitle: subtitle,
            imageUrl: "https://image.tmdb.org/t/p/w500/placeholder.jpg",
            tmdbId: nil
        )
    }

    static var previewList: [Nominee] {
        [
            Nominee.preview(title: "Anora", subtitle: "Sean Baker"),
            Nominee.preview(title: "The Brutalist", subtitle: "Brady Corbet"),
            Nominee.preview(title: "A Complete Unknown", subtitle: "James Mangold"),
            Nominee.preview(title: "Conclave", subtitle: "Edward Berger"),
            Nominee.preview(title: "Emilia Pérez", subtitle: "Jacques Audiard"),
        ]
    }
}
