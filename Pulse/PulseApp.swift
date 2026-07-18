import SwiftUI

/// Relays the APNs device token to whoever cares (SettingsStore).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .pulsePushToken, object: hex)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Push registration failed: \(error.localizedDescription)")
    }
}

@main
@MainActor
struct PulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth: AuthManager
    @StateObject private var artists: ArtistStore
    @StateObject private var events: EventStore
    @StateObject private var favourites: FavouritesStore
    @StateObject private var settings: SettingsStore
    @StateObject private var router = AppRouter()

    init() {
        let auth = AuthManager()
        let api = APIClient(auth: auth)
        _auth = StateObject(wrappedValue: auth)
        _artists = StateObject(wrappedValue: ArtistStore(api: api))
        _events = StateObject(wrappedValue: EventStore(api: api))
        _favourites = StateObject(wrappedValue: FavouritesStore(api: api))
        _settings = StateObject(wrappedValue: SettingsStore(api: api))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(artists)
                .environmentObject(events)
                .environmentObject(favourites)
                .environmentObject(settings)
                .environmentObject(router)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .background(Color.pulseBg.ignoresSafeArea())
    }
}
