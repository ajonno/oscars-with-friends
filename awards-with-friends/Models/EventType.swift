import Foundation
import FirebaseFirestore

struct EventType: Codable, Identifiable {
    @DocumentID var id: String?
    let slug: String
    let displayName: String
    let color: String?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?

    static var previewList: [EventType] {
        [
            EventType(id: "abc123", slug: "oscars", displayName: "Oscars", color: "#c9a227", createdAt: nil, updatedAt: nil),
            EventType(id: "def456", slug: "golden-globes", displayName: "Golden Globes", color: "#d4af37", createdAt: nil, updatedAt: nil),
        ]
    }
}

/// Shared cache for event types - synced in real-time
@Observable
final class EventTypeCache {
    static let shared = EventTypeCache()

    private(set) var eventTypes: [EventType] = []
    private(set) var isLoaded = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private init() {}

    /// Start listening to event types from Firestore (call on app start)
    func startListening() {
        guard listener == nil else { return }

        listener = db.collection("eventTypes").addSnapshotListener { [weak self] snapshot, error in
            guard let self, let snapshot else {
                if let error {
                    print("Failed to load event types: \(error)")
                }
                return
            }

            self.eventTypes = snapshot.documents.compactMap { try? $0.data(as: EventType.self) }
            self.isLoaded = true
        }
    }

    /// Stop listening (call on app termination if needed)
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    /// Legacy async load for backwards compatibility
    func load() async {
        startListening()
    }

    /// Get display name for an event type (by slug or document ID)
    func displayName(for eventId: String?) -> String {
        guard let eventId else { return "Unknown Event" }
        // Try matching by slug first (ceremonies store the slug), then by document ID as fallback
        return eventTypes.first { $0.slug == eventId || $0.id == eventId }?.displayName ?? "Unknown Event"
    }

    /// Get color for an event type (by slug or document ID)
    func color(for eventId: String?) -> String? {
        guard let eventId else { return nil }
        // Try matching by slug first (ceremonies store the slug), then by document ID as fallback
        return eventTypes.first { $0.slug == eventId || $0.id == eventId }?.color
    }
}
