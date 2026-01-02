import Foundation
import FirebaseFirestore
import FirebaseAuth

@Observable
final class FirestoreService {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    private init() {}

    deinit {
        removeAllListeners()
    }

    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
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

    /// One-time fetch of categories (for counts, etc.)
    func getCategories(for ceremonyYear: String, event: String) async throws -> [Category] {
        let snapshot = try await db.collection("categories")
            .whereField("ceremonyYear", isEqualTo: ceremonyYear)
            .whereField("event", isEqualTo: event)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> Category? in
            try? doc.data(as: Category.self)
        }.filter { !$0.isHidden }
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
                    }

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
            let listener = db.collection("competitions")
                .document(competitionId)
                .collection("votes")
                .whereField("odUserId", isEqualTo: userId)
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

            self.listeners.append(listener)

            continuation.onTermination = { @Sendable _ in
                listener.remove()
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
            var competitionListeners: [String: ListenerRegistration] = [:] // competitionId -> listener
            var votesByCompetition: [String: [String: Vote]] = [:] // competitionId -> (categoryId -> Vote)
            var activeCompetitionIds: Set<String> = []

            func emitMergedVotes() {
                // Merge votes from all competitions, keeping most recent per category
                var mergedVotes: [String: Vote] = [:]
                for (_, competitionVotes) in votesByCompetition {
                    for (categoryId, vote) in competitionVotes {
                        if let existing = mergedVotes[categoryId] {
                            // Keep the most recent vote
                            if vote.votedAt.dateValue() > existing.votedAt.dateValue() {
                                mergedVotes[categoryId] = vote
                            }
                        } else {
                            mergedVotes[categoryId] = vote
                        }
                    }
                }
                continuation.yield(mergedVotes)
            }

            // First, find competitions user is in for this ceremony year
            let participantListener = db.collectionGroup("participants")
                .whereField("odUserId", isEqualTo: userId)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self else { return }

                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([:])
                        return
                    }

                    // Get competition IDs
                    let newCompetitionIds = Set(documents.compactMap { doc -> String? in
                        doc.reference.parent.parent?.documentID
                    })

                    // Remove listeners for competitions user left
                    let removedIds = activeCompetitionIds.subtracting(newCompetitionIds)
                    for compId in removedIds {
                        competitionListeners[compId]?.remove()
                        competitionListeners.removeValue(forKey: compId)
                        votesByCompetition.removeValue(forKey: compId)
                    }

                    // Add listeners for new competitions
                    let addedIds = newCompetitionIds.subtracting(activeCompetitionIds)
                    for competitionId in addedIds {
                        Task {
                            do {
                                let compDoc = try await self.db.collection("competitions")
                                    .document(competitionId)
                                    .getDocument()

                                guard let compData = compDoc.data(),
                                      compData["ceremonyYear"] as? String == ceremonyYear else {
                                    return
                                }

                                // Also filter by event if specified
                                if let event {
                                    let compEvent = compData["event"] as? String
                                    if compEvent != event && compEvent != nil {
                                        return
                                    }
                                }

                                // Listen to votes in this competition
                                let votesListener = self.db.collection("competitions")
                                    .document(competitionId)
                                    .collection("votes")
                                    .whereField("odUserId", isEqualTo: userId)
                                    .addSnapshotListener { votesSnapshot, error in
                                        if error != nil { return }

                                        guard let voteDocs = votesSnapshot?.documents else { return }

                                        // Replace all votes for this competition (not accumulate)
                                        var competitionVotes: [String: Vote] = [:]
                                        for voteDoc in voteDocs {
                                            if let vote = try? voteDoc.data(as: Vote.self) {
                                                competitionVotes[vote.categoryId] = vote
                                            }
                                        }
                                        votesByCompetition[competitionId] = competitionVotes

                                        emitMergedVotes()
                                    }

                                competitionListeners[competitionId] = votesListener
                            } catch {
                                // Handle silently
                            }
                        }
                    }

                    activeCompetitionIds = newCompetitionIds

                    // If user has no competitions, emit empty
                    if newCompetitionIds.isEmpty {
                        votesByCompetition.removeAll()
                        emitMergedVotes()
                    }
                }

            self.listeners.append(participantListener)

            continuation.onTermination = { @Sendable _ in
                participantListener.remove()
                competitionListeners.values.forEach { $0.remove() }
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
