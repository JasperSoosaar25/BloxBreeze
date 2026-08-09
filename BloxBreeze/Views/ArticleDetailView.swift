import SwiftUI

struct ArticleDetailView: View {
    @EnvironmentObject private var store: NewsStore
    let item: NewsItem

    var body: some View {
        Group {
            if item.isFromX {
                XPostReader(item: item)
            } else {
                NativeArticleReader(item: item)
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

                    Text(verbatim: item.body)
                        .font(.title2)
                        .fontWeight(.medium)
                        .textSelection(.enabled)

                    if let imageURL = item.imageURL {
                        NativeRemoteImage(url: imageURL)
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

                    NativeReaderNotice(text: "Free RSS post - links are plain text and cannot open a browser.")
                }
                .padding(18)
                .padding(.bottom, 90)
            }
        }
    }
}

private struct NativeArticleReader: View {
    let item: NewsItem

    @State private var article: NativeArticle?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            BreezeBackground()

            if let article {
                articleBody(article)
            } else if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Turning this story into a native reader...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .breezeGlass(cornerRadius: 24)
            } else {
                ContentUnavailableView {
                    Label("Story could not be prepared", systemImage: "newspaper")
                } description: {
                    Text(errorMessage ?? "The source did not return readable story text.")
                } actions: {
                    Button("Try again") {
                        Task { await load() }
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding(24)
            }
        }
        .task(id: item.id) { await load() }
    }

    private func articleBody(_ article: NativeArticle) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                SourceBadge(source: item.source)

                if let heroImageURL = article.heroImageURL {
                    NativeRemoteImage(url: heroImageURL)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: article.title)
                        .font(.largeTitle.bold())
                        .textSelection(.enabled)

                    if let subtitle = article.subtitle {
                        Text(verbatim: subtitle)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 8) {
                        if let byline = article.byline {
                            Text(verbatim: byline)
                        }
                        if article.byline != nil {
                            Text("-")
                        }
                        Text(article.publishedAt.formatted(date: .long, time: .omitted))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                ForEach(article.blocks) { block in
                    NativeArticleBlockView(block: block)
                }

                NativeReaderNotice(
                    text: item.source.isOfficial
                        ? "Official source - native text and images, with no webpage or link-outs."
                        : "Native reader - no webpage or link-outs."
                )
                .padding(.top, 8)
            }
            .padding(18)
            .padding(.bottom, 90)
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            article = try await ArticleContentService().fetch(item: item)
        } catch is CancellationError {
            return
        } catch {
            article = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct NativeArticleBlockView: View {
    let block: NativeArticleBlock

    var body: some View {
        switch block.kind {
        case .heading:
            if let text = block.text {
                Text(verbatim: text)
                    .font(headingFont)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                    .textSelection(.enabled)
            }
        case .paragraph:
            if let text = block.text {
                Text(verbatim: text)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
        case .bullet:
            if let text = block.text {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Circle()
                        .fill(Color.breezeLavender)
                        .frame(width: 7, height: 7)
                    Text(verbatim: text)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                }
                .padding(.leading, 6)
            }
        case .quote:
            if let text = block.text {
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.breezeCoral)
                        .frame(width: 4)
                    Text(verbatim: text)
                        .font(.body.italic())
                        .lineSpacing(5)
                        .textSelection(.enabled)
                }
                .padding(18)
                .breezeGlass(cornerRadius: 22, tint: Color.breezeCoral.opacity(0.08))
            }
        case .image:
            if let imageURL = block.imageURL {
                VStack(alignment: .leading, spacing: 8) {
                    NativeRemoteImage(url: imageURL)
                    if let caption = block.caption {
                        Text(verbatim: caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var headingFont: Font {
        switch block.headingLevel ?? 2 {
        case ...2: return .title2
        case 3: return .title3
        default: return .headline
        }
    }
}

private struct NativeRemoteImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            case .failure:
                ContentUnavailableView("Image unavailable", systemImage: "photo")
                    .frame(maxWidth: .infinity, minHeight: 180)
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .clipShape(.rect(cornerRadius: 24))
        .accessibilityLabel("Story image")
    }
}

private struct NativeReaderNotice: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(14)
            .breezeGlass(cornerRadius: 18)
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
        .breezeGlass(cornerRadius: 22, tint: Color.breezeLavender.opacity(0.08))
    }
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
