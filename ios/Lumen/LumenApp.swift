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
                }
        }
    }
}
