import SwiftUI

@main
struct BloxBreezeApp: App {
    @StateObject private var store = NewsStore()
    @AppStorage("has-seen-welcome-v1") private var hasSeenWelcome = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenWelcome {
                    RootView()
                        .environmentObject(store)
                } else {
                    WelcomeView {
                        withAnimation(.smooth) {
                            hasSeenWelcome = true
                        }
                    }
                }
            }
            .tint(Color.breezeCoral)
        }
    }
}
