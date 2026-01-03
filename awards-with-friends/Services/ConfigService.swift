import Foundation
import FirebaseFirestore

@Observable
class ConfigService {
    static let shared = ConfigService()

    private(set) var requiresPaymentForCompetitions = true
    private(set) var isLoaded = false

    private var listener: ListenerRegistration?

    init() {
        startListening()
    }

    deinit {
        listener?.remove()
    }

    private func startListening() {
        let db = Firestore.firestore()

        listener = db.collection("config").document("features")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Error fetching feature flags: \(error)")
                    self.isLoaded = true
                    return
                }

                guard let data = snapshot?.data() else {
                    // Document doesn't exist, use defaults
                    self.isLoaded = true
                    return
                }

                self.requiresPaymentForCompetitions = data["requiresPaymentForCompetitions"] as? Bool ?? true
                self.isLoaded = true
            }
    }
}
