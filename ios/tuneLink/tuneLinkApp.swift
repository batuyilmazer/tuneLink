import SwiftUI

@main
struct tuneLinkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = SpotifyAuthManager()

    @AppStorage("userId", store: UserDefaults(suiteName: AppGroup.suiteName))
    private var userId: String = ""

    var body: some Scene {
        WindowGroup {
            if userId.isEmpty {
                LoginView()
                    .environmentObject(authManager)
            } else {
                GroupFeedView()
            }
        }
    }
}
