import SwiftUI
import UIKit

@main
struct LumenApp: App {
    @StateObject private var auth = AuthManager()
    @StateObject private var sync = SyncManager()

    init() {
        // Glass chrome so Designer washes show through tab / nav bars (not opaque black slabs).
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tab.backgroundColor = UIColor(red: 16/255, green: 14/255, blue: 12/255, alpha: 0.35)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = UIColor(red: 232/255, green: 228/255, blue: 217/255, alpha: 1)

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        nav.backgroundColor = UIColor(red: 16/255, green: 14/255, blue: 12/255, alpha: 0.35)
        nav.titleTextAttributes = [.foregroundColor: UIColor(red: 244/255, green: 241/255, blue: 234/255, alpha: 1)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(red: 244/255, green: 241/255, blue: 234/255, alpha: 1)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(red: 232/255, green: 228/255, blue: 217/255, alpha: 1)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(sync)
                // Fill the window; safe areas handled by chrome / viewer intentionally.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.dark)
                .onAppear {
                    auth.loadTokens()
                    sync.registerBackgroundTasks()
                    if UserDefaults.standard.string(forKey: "server_url") == nil {
                        UserDefaults.standard.set("http://localhost", forKey: "server_url")
                    }
                }
        }
    }
}
