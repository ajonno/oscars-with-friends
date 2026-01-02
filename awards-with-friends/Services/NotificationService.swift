import UIKit
import UserNotifications
import FirebaseMessaging

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermissionIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            // Never asked - request permission
            _ = await requestPermission()
        case .authorized, .provisional, .ephemeral:
            // Already authorized - just register for remote notifications
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        case .denied:
            // User denied - don't ask again
            break
        @unknown default:
            break
        }
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    func getCurrentToken() async -> String? {
        try? await Messaging.messaging().token()
    }
}
