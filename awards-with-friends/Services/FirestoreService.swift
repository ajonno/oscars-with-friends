import Foundation
import FirebaseFirestore
import FirebaseAuth

@Observable
final class FirestoreService {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private let ceremonyVotesCollection = "ceremonyVotes"

    private init() {}

    deinit {
        removeAllListeners()
    }

    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    private func ceremonyKey(ceremonyYear: String, event: String?) -> String {
        "\(event ?? "default"):\(ceremonyYear)"
    }

    private func ceremonyVoteQuery(
        ceremonyYear: String,
        event: String?,
        userId: String? = nil
    ) -> Query {
        var query: Query = db.collection(ceremonyVotesCollection)
            .whereField("ceremonyKey", isEqualTo: ceremonyKey(ceremonyYear: ceremonyYear, event: event))

        if let userId {
            query = query.whereField("odUserId", isEqualTo: userId)
        }

        return query
    }

    private func competitionContext(
        competitionId: String,
        source: FirestoreSource = .default
    ) async throws -> (ceremonyYear: String, event: String?) {
        let snapshot = try await db.collection("competitions")
            .document(competitionId)
            .getDocument(source: source)

        guard let competition = try? snapshot.data(as: Competition.self) else {
            throw NSError(domain: "FirestoreService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Competition not found"
            ])
        }

        return (competition.ceremonyYear, competition.event)
    }

    // MARK: - Categories

    func categoriesStream(for ceremonyYear: String, event: String? = nil) -> AsyncThrowingStream<[Category], Error> {
        AsyncThrowingStream { continuation in
            let listener = db.collection("categories")
                .whereField("ceremonyYear", isEqualTo: ceremonyYear)
                .order(by: "displayOrder")
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }

                    var categories = documents.compactMap { doc -> Category? in
                        try? doc.data(as: Category.self)
                    }.filter { !$0.isHidden }

                    // Filter by event client-side to avoid composite index requirement
                    if let event {
                        categories = categories.filter { $0.event == event || $0.event == nil }
                    }

                    continuation.yield(categories)
                }

            self.listeners.append(listener)

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }

    /// One-time fetch of categories (used when a view needs a fresh, server-backed snapshot)
    func getCategories(
        for ceremonyYear: String,
        event: String? = nil,
        source: FirestoreSource = .default
    ) async throws -> [Category] {
        let snapshot = try await db.collection("categories")
            .whereField("ceremonyYear", isEqualTo: ceremonyYear)
            .order(by: "displayOrder")
            .getDocuments(source: source)

        var categories = snapshot.documents.compactMap { doc -> Category? in
            do {
                return try doc.data(as: Category.self)
            } catch {
                print("Failed to decode category \(doc.documentID): \(error)")
                return nil
            }
        }.filter { !$0.isHidden }

        if let event {
            categories = categories.filter { $0.event == event || $0.event == nil }
        }

        return categories
    }

    // MARK: - Competitions

    func myCompetitionsStream() -> AsyncThrowingStream<[Competition], Error> {
        guard let userId = Auth.auth().currentUser?.uid else {
            return AsyncThrowingStream { continuation in
                continuation.yield([])
                continuation.finish()
            }
        }

        return AsyncThrowingStream { continuation in
            var competitionListeners: [ListenerRegistration] = []
            var currentCompetitionIds: Set<String> = []
            var competitions: [String: Competition] = [:]

            // Listen for participant documents to get competition IDs
            let participantListener = db.collectionGroup("participants")
                .whereField("odUserId", isEqualTo: userId)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self else { return }

                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }

                    let newCompetitionIds = Set(documents.compactMap { doc -> String? in
                        doc.reference.parent.parent?.documentID
                    })

                    // Remove listeners for competitions user left
                    let removedIds = currentCompetitionIds.subtracting(newCompetitionIds)
                    for id in removedIds {
                        competitions.removeValue(forKey: id)
                    }

                    // Add listeners for new competitions
                    let addedIds = newCompetitionIds.subtracting(currentCompetitionIds)
                    for competitionId in addedIds {
                        let listener = self.db.collection("competitions")
                            .document(competitionId)
                            .addSnapshotListener { docSnapshot, error in
                                if error != nil { return }

                                if let doc = docSnapshot, doc.exists,
                                   let competition = try? doc.data(as: Competition.self) {
                                    competitions[competitionId] = competition
                                } else {
                                    competitions.removeValue(forKey: competitionId)
                                }

                                // Emit updated list
                                let sorted = Array(competitions.values).sorted {
                                    $0.createdAt.dateValue() > $1.createdAt.dateValue()
                                }
                                continuation.yield(sorted)
                            }
                        competitionListeners.append(listener)
                    }

                    currentCompetitionIds = newCompetitionIds

                    if newCompetitionIds.isEmpty {
                        continuation.yield([])
                    }
                }

            self.listeners.append(participantListener)

            continuation.onTermination = { @Sendable _ in
                participantListener.remove()
                competitionListeners.forEach { $0.remove() }
            }
        }
    }

    func competition(id: String) async throws -> Competition? {
        let doc = try await db.collection("competitions").document(id).getDocument()
        return try doc.data(as: Competition.self)
    }

    // MARK: - Participants (Leaderboard)

    func participantsStream(competitionId: String) -> AsyncThrowingStream<[Participant], Error> {
        AsyncThrowingStream { continuation in
            let listener = db.collection("competitions")
                .document(competitionId)
                .collection("participants")
                .order(by: "score", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }

                    let participants = documents.compactMap { doc -> Participant? in
                        try? doc.data(as: Participant.self)
                    }.filter { $0.blocked != true }

                    continuation.yield(participants)
                }

            self.listeners.append(listener)

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }

    // MARK: - Votes

    func myVotesStream(competitionId: String) -> AsyncThrowingStream<[Vote], Error> {
        guard let userId = Auth.auth().currentUser?.uid else {
            return AsyncThrowingStream { continuation in
                continuation.yield([])
                continuation.finish()
            }
        }

        return AsyncThrowingStream { continuation in
            var listener: ListenerRegistration?
            let task = Task {
                do {
                    let context = try await self.competitionContext(competitionId: competitionId)
                    listener = self.ceremonyVoteQuery(
                        ceremonyYear: context.ceremonyYear,
                        event: context.event,
                        userId: userId
                    )
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            continuation.finish(throwing: error)
                            return
                        }

                        guard let documents = snapshot?.documents else {
                            continuation.yield([])
                            return
                        }

                        let votes = documents.compactMap { doc -> Vote? in
                            try? doc.data(as: Vote.self)
                        }

                        continuation.yield(votes)
                    }

                    if let listener {
                        self.listeners.append(listener)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                listener?.remove()
            }
        }
    }

    func votesForUser(
        competitionId: String,
        userId: String,
        source: FirestoreSource = .default
    ) async throws -> [Vote] {
        let context = try await competitionContext(competitionId: competitionId, source: source)
        let snapshot = try await ceremonyVoteQuery(
            ceremonyYear: context.ceremonyYear,
            event: context.event,
            userId: userId
        )
            .getDocuments(source: source)

        return snapshot.documents.compactMap { doc -> Vote? in
            do {
                return try doc.data(as: Vote.self)
            } catch {
                print("Failed to decode vote \(doc.documentID): \(error)")
                return nil
            }
        }
    }

    func competitionVotesStream(competitionId: String) -> AsyncThrowingStream<[Vote], Error> {
        AsyncThrowingStream { continuation in
            var participantsListener: ListenerRegistration?
            var voteListeners: [ListenerRegistration] = []
            var votesByChunk: [Int: [Vote]] = [:]

            func emitVotes() {
                continuation.yield(votesByChunk.values.flatMap { $0 })
            }

            let task = Task {
                do {
                    let context = try await self.competitionContext(competitionId: competitionId)
                    participantsListener = self.db.collection("competitions")
                        .document(competitionId)
                        .collection("participants")
                        .addSnapshotListener { snapshot, error in
                            if let error {
                                continuation.finish(throwing: error)
                                return
                            }

                            let participantIds = snapshot?.documents.compactMap { doc -> String? in
                                let blocked = doc.data()["blocked"] as? Bool ?? false
                                return blocked ? nil : doc.documentID
                            } ?? []

                            voteListeners.forEach { $0.remove() }
                            voteListeners.removeAll()
                            votesByChunk.removeAll()

                            if participantIds.isEmpty {
                                emitVotes()
                                return
                            }

                            for (index, chunk) in participantIds.chunked(into: 30).enumerated() {
                                let listener = self.db.collection(self.ceremonyVotesCollection)
                                    .whereField("ceremonyKey", isEqualTo: self.ceremonyKey(ceremonyYear: context.ceremonyYear, event: context.event))
                                    .whereField("odUserId", in: chunk)
                                    .addSnapshotListener { votesSnapshot, error in
                                        if let error {
                                            continuation.finish(throwing: error)
                                            return
                                        }

                                        let votes = votesSnapshot?.documents.compactMap { doc -> Vote? in
                                            do {
                                                return try doc.data(as: Vote.self)
                                            } catch {
                                                print("Failed to decode canonical vote \(doc.documentID): \(error)")
                                                return nil
                                            }
                                        } ?? []

                                        votesByChunk[index] = votes
                                        emitVotes()
                                    }

                                voteListeners.append(listener)
                            }
                        }

                    if let participantsListener {
                        self.listeners.append(participantsListener)
                    }
                    self.listeners.append(contentsOf: voteListeners)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                participantsListener?.remove()
                voteListeners.forEach { $0.remove() }
            }
        }
    }

    // MARK: - Ceremony Votes (across all competitions)

    func myCeremonyVotesStream(ceremonyYear: String, event: String? = nil) -> AsyncThrowingStream<[String: Vote], Error> {
        guard let userId = Auth.auth().currentUser?.uid else {
            return AsyncThrowingStream { continuation in
                continuation.yield([:])
                continuation.finish()
            }
        }

        return AsyncThrowingStream { continuation in
            let listener = ceremonyVoteQuery(ceremonyYear: ceremonyYear, event: event, userId: userId)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([:])
                        return
                    }

                    let mergedVotes = documents.compactMap { doc -> Vote? in
                        try? doc.data(as: Vote.self)
                    }.reduce(into: [String: Vote]()) { result, vote in
                        result[vote.categoryId] = vote
                    }
                    continuation.yield(mergedVotes)
                }

            self.listeners.append(listener)

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }

    // MARK: - Single Category Vote Stream (for vote confirmation)

    /// Streams the user's vote for a specific category across all their competitions for a ceremony.
    /// Used by the voting sheet to confirm when a vote has been saved.
    func myCategoryVoteStream(ceremonyYear: String, categoryId: String, event: String?) -> AsyncThrowingStream<Vote?, Error> {
        guard let userId = Auth.auth().currentUser?.uid else {
            return AsyncThrowingStream { continuation in
                continuation.yield(nil)
                continuation.finish()
            }
        }

        return AsyncThrowingStream { continuation in
            let listener = ceremonyVoteQuery(ceremonyYear: ceremonyYear, event: event, userId: userId)
                .whereField("categoryId", isEqualTo: categoryId)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    let vote = snapshot?.documents.compactMap { doc -> Vote? in
                        try? doc.data(as: Vote.self)
                    }.max(by: { $0.votedAt.dateValue() < $1.votedAt.dateValue() })

                    continuation.yield(vote)
                }

            self.listeners.append(listener)

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }

    // MARK: - Ceremonies

    func currentCeremony() async throws -> Ceremony? {
        let snapshot = try await db.collection("ceremonies")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments()

        return snapshot.documents.first.flatMap { try? $0.data(as: Ceremony.self) }
    }

    func ceremoniesList() async throws -> [Ceremony] {
        let snapshot = try await db.collection("ceremonies")
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Ceremony.self) }
    }

    func ceremoniesStream() -> AsyncThrowingStream<[Ceremony], Error> {
        AsyncThrowingStream { continuation in
            let listener = db.collection("ceremonies")
                .order(by: "date", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }

                    let ceremonies = documents.compactMap { try? $0.data(as: Ceremony.self) }
                    continuation.yield(ceremonies)
                }

            self.listeners.append(listener)

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
