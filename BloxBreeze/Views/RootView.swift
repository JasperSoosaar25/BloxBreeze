import SwiftUI

struct RootView: View {
    private enum TabSelection: Hashable {
        case today
        case saved
        case settings
    }

    @State private var selection: TabSelection = .today

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "newspaper.fill", value: .today) {
                FeedView()
            }

            Tab("Saved", systemImage: "heart.fill", value: .saved) {
                SavedView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
    }
}

