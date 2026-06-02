import UIKit
import WidgetKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let baseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "http://localhost:3000"
    }()

    // 13.2 — Register for remote notifications
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        application.registerForRemoteNotifications()
        return true
    }

    // 13.2 — Send device token to backend
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        // Always persist so SpotifyAuthManager can retry after login if userId isn't set yet
        UserDefaults(suiteName: AppGroup.suiteName)?.set(token, forKey: AppGroup.Keys.deviceToken)
        postDeviceToken(token)
    }

    func postDeviceToken(_ token: String) {
        guard let userId = UserDefaults(suiteName: AppGroup.suiteName)?.string(forKey: AppGroup.Keys.userId),
              !userId.isEmpty,
              let url = URL(string: "\(baseURL)/device-token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["userId": userId, "deviceToken": token])
        URLSession.shared.dataTask(with: request).resume()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { await refreshLiveActivity() }
    }

    // Handle silent push → reload widget timelines + update Live Activity
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        WidgetCenter.shared.reloadAllTimelines()
        Task {
            await refreshLiveActivity()
            completionHandler(.newData)
        }
    }

    private func refreshLiveActivity() async {
        guard #available(iOS 16.2, *) else { return }
        guard let userId = UserDefaults(suiteName: AppGroup.suiteName)?.string(forKey: AppGroup.Keys.userId),
              !userId.isEmpty,
              let url = URL(string: "\(baseURL)/group-feed?userId=\(userId)") else { return }
        do {
            let sessionToken = UserDefaults(suiteName: AppGroup.suiteName)?.string(forKey: AppGroup.Keys.sessionToken) ?? ""
            var request = URLRequest(url: url)
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: request)
            let members = try JSONDecoder().decode([MemberStatus].self, from: data)
            LiveActivityManager.shared.updateOrStart(with: members)
        } catch {}
    }
}
