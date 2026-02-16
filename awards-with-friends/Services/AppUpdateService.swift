import Foundation

@Observable
class AppUpdateService {
    static let shared = AppUpdateService()

    private(set) var updateAvailable = false
    private(set) var appStoreURL: URL?

    private let appId = "1638720136"
    private let checkInterval: TimeInterval = 24 * 60 * 60
    private let lastCheckKey = "AppUpdateService.lastCheckDate"
    private let dismissedVersionKey = "AppUpdateService.dismissedVersion"
    private let dismissedDateKey = "AppUpdateService.dismissedDate"
    private let dismissCooldown: TimeInterval = 3 * 24 * 60 * 60 // 3 days
    private var latestVersion: String?

    func checkIfNeeded() async {
        let now = Date()
        if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date,
           now.timeIntervalSince(lastCheck) < checkInterval {
            return
        }
        await check()
    }

    private func check() async {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(appId)&country=au") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(ITunesLookupResult.self, from: data)
            guard let entry = result.results.first else { return }

            let currentVersion = Bundle.main.appVersion
            latestVersion = entry.version

            let isNewer = entry.version.compare(currentVersion, options: .numeric) == .orderedDescending
            let dismissedVersion = UserDefaults.standard.string(forKey: dismissedVersionKey)
            let dismissedDate = UserDefaults.standard.object(forKey: dismissedDateKey) as? Date
            let wasDismissed = dismissedVersion == entry.version
                && dismissedDate.map({ Date().timeIntervalSince($0) < dismissCooldown }) ?? false

            await MainActor.run {
                self.updateAvailable = isNewer && !wasDismissed
                self.appStoreURL = URL(string: "https://apps.apple.com/app/id\(self.appId)")
            }

            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
        } catch {
            print("App update check failed: \(error)")
        }
    }

    func dismiss() {
        updateAvailable = false
        if let version = latestVersion {
            UserDefaults.standard.set(version, forKey: dismissedVersionKey)
            UserDefaults.standard.set(Date(), forKey: dismissedDateKey)
        }
    }
}

private struct ITunesLookupResult: Decodable {
    let results: [ITunesAppEntry]
}

private struct ITunesAppEntry: Decodable {
    let version: String
}
