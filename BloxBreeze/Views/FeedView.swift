import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var store: NewsStore

    var body: some View {
        NavigationStack {
            ZStack {
                BreezeBackground()

                ScrollView {
                    LazyVStack(spacing: 18) {
                        CozyDigestCard()
                        SourceFilterStrip()
                        FreeFeedsNote()

                        if let status = store.statusMessage {
                            FeedNotice(text: status)
                        }

                        if store.isLoading && store.items.isEmpty {
                            ProgressView("Gathering the latest breeze…")
                                .controlSize(.large)
                                .padding(.top, 60)
                        } else if store.filteredItems.isEmpty {
                            ContentUnavailableView(
                                store.searchText.isEmpty ? "Nothing in this breeze" : "No matching stories",
                                systemImage: "wind",
                                description: Text(store.searchText.isEmpty ? "Try another source or pull to refresh." : "Try a softer search term.")
                            )
                            .padding(.top, 42)
                        } else {
                            ForEach(store.filteredItems) { item in
                                NavigationLink(value: item) {
                                    NewsCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 100)
                }
                .refreshable { await store.refresh() }
            }
            .navigationTitle("Today")
            .searchable(text: $store.searchText, prompt: "Search your news")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        if store.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Refresh news")
                    .disabled(store.isLoading)
                }
            }
            .navigationDestination(for: NewsItem.self) { item in
                ArticleDetailView(item: item)
            }
            .task {
                if store.items.isEmpty { await store.refresh() }
            }
        }
    }
}

private struct FreeFeedsNote: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(Color.breezeMint)
                .frame(width: 30, height: 30)
                .glassEffect(.regular.tint(Color.breezeMint.opacity(0.14)), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Every source is free")
                    .font(.subheadline.weight(.semibold))
                Text("The three X accounts arrive through free RSS mirrors—no login, token, or subscription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .breezeGlass(cornerRadius: 20, tint: Color.breezeMint.opacity(0.06))
    }
}

private struct CozyDigestCard: View {
    @EnvironmentObject private var store: NewsStore

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(store.unreadCount == 0 ? "You’re all caught up ✨" : "\(store.unreadCount) stories in your breeze")
                        .font(.title2.bold())
                }
                Spacer()
                Image(systemName: "cloud.sun.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.breezePeach, Color.breezeLavender)
            }

            HStack(spacing: 18) {
                Label("\(store.readingStreak) day streak", systemImage: "flame.fill")
                if let updated = store.lastUpdated {
                    Label(updated.formatted(.relative(presentation: .named)), systemImage: "clock")
                } else {
                    Label("Ready to refresh", systemImage: "clock")
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .breezeGlass(cornerRadius: 28, tint: Color.breezeLavender.opacity(0.10))
    }
}

private struct SourceFilterStrip: View {
    @EnvironmentObject private var store: NewsStore

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(NewsSource.all) { source in
                        let selected = store.selectedSourceIDs.contains(source.id)
                        Button {
                            withAnimation(.snappy) { store.toggleSource(source) }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: source.symbol)
                                Text(source.name)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected ? source.tint : Color(uiColor: .secondaryLabel))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            .regular.tint(selected ? source.tint.opacity(0.16) : .clear).interactive()
                        )
                        .accessibilityValue(selected ? "Included" : "Hidden")
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FeedNotice: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.breezePeach)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .breezeGlass(cornerRadius: 18, tint: Color.breezePeach.opacity(0.08))
    }
}
