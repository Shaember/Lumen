import SwiftUI

@main
struct LumenApp: App {
    @StateObject private var auth = AuthManager()
    @StateObject private var sync = SyncManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(sync)
                .onAppear {
                    auth.loadTokens()
                    sync.registerBackgroundTasks()
                    
                    // Set default server URL if not configured
                    if UserDefaults.standard.string(forKey: "server_url") == nil {
                        UserDefaults.standard.set("http://localhost", forKey: "server_url")
                    }
                }
        }
    }
}
