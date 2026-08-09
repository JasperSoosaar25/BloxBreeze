import SwiftUI

struct ArticleDetailView: View {
    @EnvironmentObject private var store: NewsStore
    let item: NewsItem

    var body: some View {
        Group {
            if item.isFromX {
                XPostReader(item: item)
            } else if let url = item.articleURL {
                OfficialArticleReader(item: item, url: url)
            } else {
                Text(item.body)
                    .padding()
            }
        }
        .navigationTitle(item.source.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleSaved(item)
                } label: {
                    Image(systemName: store.savedIDs.contains(item.id) ? "heart.fill" : "heart")
                }
                .accessibilityLabel(store.savedIDs.contains(item.id) ? "Remove from saved" : "Save story")
            }
        }
        .onAppear { store.markRead(item) }
    }
}

private struct XPostReader: View {
    let item: NewsItem

    var body: some View {
        ZStack {
            BreezeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SourceBadge(source: item.source)

                    Text(item.body)
                        .font(.title2)
                        .fontWeight(.medium)
                        .textSelection(.enabled)

                    if let imageURL = item.imageURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                ContentUnavailableView("Media unavailable", systemImage: "photo")
                                    .frame(height: 220)
                            default:
                                ProgressView().frame(maxWidth: .infinity, minHeight: 220)
                            }
                        }
                        .clipShape(.rect(cornerRadius: 24))
                    }

                    if let metrics = item.metrics {
                        MetricsBar(metrics: metrics)
                    }

                    HStack {
                        Label(item.publishedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        Spacer()
                        Text("@\(item.source.handle ?? "")")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Label("Links in posts are shown as text and never open outside the app.", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .breezeGlass(cornerRadius: 18)
                }
                .padding(18)
                .padding(.bottom, 90)
            }
        }
    }
}

private struct MetricsBar: View {
    let metrics: NewsItem.Metrics

    var body: some View {
        HStack {
            Metric(symbol: "bubble.left", value: metrics.replies)
            Spacer()
            Metric(symbol: "arrow.2.squarepath", value: metrics.reposts)
            Spacer()
            Metric(symbol: "heart", value: metrics.likes)
            if let views = metrics.views {
                Spacer()
                Metric(symbol: "chart.bar", value: views)
            }
        }
        .padding(16)
        .breezeGlass(cornerRadius: 22, tint: itemTint)
    }

    private var itemTint: Color { Color.breezeLavender.opacity(0.08) }
}

private struct Metric: View {
    let symbol: String
    let value: Int

    var body: some View {
        Label(value.formatted(.number.notation(.compactName)), systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

private struct OfficialArticleReader: View {
    let item: NewsItem
    let url: URL
    @State private var isLoading = true

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            ReaderWebView(url: url, isLoading: $isLoading)

            if isLoading {
                HStack(spacing: 9) {
                    ProgressView()
                    Text("Preparing the in-app reader…")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .breezeGlass(cornerRadius: 18)
                .padding(.top, 10)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: item.source.isOfficial ? "checkmark.seal.fill" : item.source.symbol)
                    .foregroundStyle(item.source.tint)
                Text(item.source.isOfficial ? "Official source · links disabled" : "In-app reader · links disabled")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect()
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }
}
