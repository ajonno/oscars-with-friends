import Foundation
import FirebaseFirestore

struct Nominee: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let imageUrl: String
    let tmdbId: String?
    let trailerYouTubeId: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        tmdbId = try container.decodeIfPresent(String.self, forKey: .tmdbId)
        trailerYouTubeId = try container.decodeIfPresent(String.self, forKey: .trailerYouTubeId)
    }

    init(id: String, title: String, subtitle: String?, imageUrl: String, tmdbId: String?, trailerYouTubeId: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageUrl = imageUrl
        self.tmdbId = tmdbId
        self.trailerYouTubeId = trailerYouTubeId
    }
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
    static func preview(title: String, subtitle: String? = nil, trailerYouTubeId: String? = nil) -> Nominee {
        Nominee(
            id: UUID().uuidString,
            title: title,
            subtitle: subtitle,
            imageUrl: "https://image.tmdb.org/t/p/w500/placeholder.jpg",
            tmdbId: nil,
            trailerYouTubeId: trailerYouTubeId
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
