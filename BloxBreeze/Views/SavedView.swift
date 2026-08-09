import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var store: NewsStore

    var body: some View {
        NavigationStack {
            ZStack {
                BreezeBackground()

                if store.savedItems.isEmpty {
                    ContentUnavailableView(
                        "A cozy empty pocket",
                        systemImage: "heart",
                        description: Text("Tap the heart while reading a story and it’ll wait here for you.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(store.savedItems) { item in
                                NavigationLink(value: item) {
                                    NewsCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 90)
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationDestination(for: NewsItem.self) { item in
                ArticleDetailView(item: item)
            }
        }
    }
}

