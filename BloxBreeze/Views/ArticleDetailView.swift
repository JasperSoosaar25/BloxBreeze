import PDFKit
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
    @State private var detail: XPostDetail?
    @State private var selectedImage: ZoomableImageItem?
    @State private var isResolvingMedia = false
    @State private var mediaError: String?

    var body: some View {
        ZStack {
            BreezeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SourceBadge(source: item.source)

                    SocialPostText(text: primaryText)

                    ForEach(displayMedia) { media in
                        switch media.kind {
                        case .image:
                            RemoteMediaImage(url: media.url) {
                                selectedImage = ZoomableImageItem(url: media.url)
                            }
                        case .video:
                            InlineVideoView(media: media)
                        }
                    }

                    if item.hasVideoPreview && displayMedia.isEmpty {
                        VideoResolutionPanel(
                            previewURL: item.imageURL,
                            isLoading: isResolvingMedia,
                            message: mediaError,
                            retry: { Task { await resolvePost() } }
                        )
                    }

                    if !item.orderedThreadReplies.isEmpty {
                        XThreadRepliesView(
                            replies: item.orderedThreadReplies,
                            source: item.source
                        )
                    }

                    if item.articleURL != nil {
                        CompanionArticleLink(item: item)
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

                    NativeReaderNotice(
                        text: item.articleURL == nil
                            ? "Free native thread. Highlighted mentions and source addresses do not open a browser."
                            : "The source link opens only in BloxBreeze's native reader."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .padding(.bottom, 90)
            }
        }
        .task(id: item.id) {
            await resolvePost()
        }
        .fullScreenCover(item: $selectedImage) { image in
            FullScreenImageViewer(item: image)
        }
    }

    private var primaryText: String {
        guard let resolvedText = detail?.text, !resolvedText.isEmpty else { return item.body }
        return resolvedText.count >= item.body.count ? resolvedText : item.body
    }

    private var displayMedia: [XPostMedia] {
        if let detail, !detail.media.isEmpty { return detail.media }
        if let media = item.media, !media.isEmpty { return media }
        if item.hasVideoPreview { return [] }
        guard let imageURL = item.imageURL else { return [] }
        return [
            XPostMedia(
                kind: .image,
                url: imageURL,
                previewURL: imageURL,
                aspectRatio: nil
            )
        ]
    }

    @MainActor
    private func resolvePost() async {
        guard !isResolvingMedia else { return }
        isResolvingMedia = true
        mediaError = nil
        do {
            detail = try await XPostDetailService().fetch(for: item)
            if item.hasVideoPreview && detail?.media.contains(where: { $0.kind == .video }) != true {
                mediaError = "The source returned a preview but no playable video stream."
            }
        } catch is CancellationError {
            isResolvingMedia = false
            return
        } catch {
            mediaError = "Video could not load. Tap to retry."
        }
        isResolvingMedia = false
    }
}

private struct XThreadRepliesView: View {
    let replies: [XThreadReply]
    let source: NewsSource

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Thread - \(replies.count + 1) posts", systemImage: "text.bubble.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(source.tint)

            ForEach(replies.indices, id: \.self) { index in
                let reply = replies[index]
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .foregroundStyle(source.tint)
                        Text("Reply \(index + 1) of \(replies.count)")
                            .fontWeight(.semibold)
                        Spacer(minLength: 8)
                        Text(reply.publishedAt.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)

                    SocialPostText(text: reply.text)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .breezeGlass(cornerRadius: 22, tint: source.tint.opacity(0.065))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SocialPostText: View {
    let text: String

    var body: some View {
        styledText
            .font(.body)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var styledText: Text {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?<![A-Za-z0-9_])@[A-Za-z0-9_]{1,30}|(?<![A-Za-z0-9_])#[A-Za-z0-9_]+|https?://[^\s]+"#
        ) else { return Text(verbatim: text) }

        let matches = regex.matches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )
        var output = Text("")
        var cursor = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            if cursor < range.lowerBound {
                output = output + Text(verbatim: String(text[cursor..<range.lowerBound]))
            }
            output = output + Text(verbatim: String(text[range]))
                .foregroundColor(.blue)
                .fontWeight(.semibold)
            cursor = range.upperBound
        }

        if cursor < text.endIndex {
            output = output + Text(verbatim: String(text[cursor...]))
        }
        return output
    }
}

private struct CompanionArticleLink: View {
    let item: NewsItem

    var body: some View {
        NavigationLink {
            CompanionContentView(item: item)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3.bold())
                    .foregroundStyle(item.source.tint)
                    .frame(width: 46, height: 46)
                    .glassEffect(
                        .regular.tint(item.source.tint.opacity(0.16)).interactive(),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("More details")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(sourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(.rect(cornerRadius: 22))
            .breezeGlass(
                cornerRadius: 22,
                tint: item.source.tint.opacity(0.08),
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the linked source inside BloxBreeze")
    }

    private var sourceLabel: String {
        guard let host = item.articleURL?.host else { return "Read inside BloxBreeze" }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

private struct CompanionContentView: View {
    let item: NewsItem

    var body: some View {
        Group {
            if let url = item.articleURL, ArticleContentService.isPDFURL(url) {
                NativePDFReader(url: url)
            } else {
                NativeArticleReader(item: item)
            }
        }
        .navigationTitle("More details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NativePDFReader: View {
    let url: URL
    @State private var document: PDFDocument?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            BreezeBackground()

            if let document {
                PDFDocumentView(document: document)
                    .clipShape(.rect(cornerRadius: 22))
                    .breezeGlass(cornerRadius: 22, tint: Color.breezeLavender.opacity(0.04))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 82)
            } else if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Preparing the source document...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .breezeGlass(cornerRadius: 24)
            } else {
                ContentUnavailableView {
                    Label("Document unavailable", systemImage: "doc.text")
                } description: {
                    Text(errorMessage ?? "The source did not return a readable document.")
                } actions: {
                    Button("Try again") {
                        Task { await load() }
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding(24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let document {
                Label(
                    "Native document - \(document.pageCount) pages",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .breezeGlass(cornerRadius: 18)
                .padding(.bottom, 6)
            }
        }
        .task(id: url) { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        document = nil
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 45
            request.cachePolicy = .returnCacheDataElseLoad
            request.setValue("BloxBreeze/1.6 (iOS; native document reader)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let loaded = PDFDocument(data: data) else {
                throw FeedError.invalidResponse
            }
            document = loaded
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "The source document could not be downloaded."
        }
        isLoading = false
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.backgroundColor = .clear
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.document = document
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
            view.autoScales = true
        }
    }
}

private struct VideoResolutionPanel: View {
    let previewURL: URL?
    let isLoading: Bool
    let message: String?
    let retry: () -> Void

    var body: some View {
        Button(action: retry) {
            ZStack {
                if let previewURL {
                    HighQualityAsyncImage(url: previewURL) { phase in
                        if case let .success(image) = phase {
                            NativeUIImageView(image: image, contentMode: .scaleAspectFill)
                        } else {
                            Color(uiColor: .secondarySystemBackground)
                        }
                    }
                } else {
                    Color(uiColor: .secondarySystemBackground)
                }

                Rectangle().fill(.black.opacity(0.28))

                VStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.large)
                        Text("Preparing video...")
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 46))
                            .frame(width: 62, height: 62)
                            .glassEffect(
                                .regular.tint(.black.opacity(0.18)).interactive(),
                                in: Circle()
                            )
                        Text(message ?? "Tap to load video")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 22))
            .breezeGlass(cornerRadius: 22, tint: Color.breezeLavender.opacity(0.05))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "Preparing video" : "Retry video")
    }
}

private struct NativeArticleReader: View {
    let item: NewsItem

    @State private var article: NativeArticle?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var selectedImage: ZoomableImageItem?

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
        .fullScreenCover(item: $selectedImage) { image in
            FullScreenImageViewer(item: image)
        }
    }

    private func articleBody(_ article: NativeArticle) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                SourceBadge(source: item.source)

                if let heroImageURL = article.heroImageURL {
                    RemoteMediaImage(url: heroImageURL) {
                        selectedImage = ZoomableImageItem(url: heroImageURL)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: article.title)
                        .font(.title2.bold())
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
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
                    NativeArticleBlockView(block: block) { imageURL in
                        selectedImage = ZoomableImageItem(url: imageURL)
                    }
                }

                NativeReaderNotice(
                    text: item.source.isOfficial
                        ? "Official source - native text and images, with no webpage or link-outs."
                        : "Native reader - no webpage or link-outs."
                )
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    let onImageTap: (URL) -> Void

    var body: some View {
        switch block.kind {
        case .heading:
            if let text = block.text {
                Text(verbatim: text)
                    .font(headingFont)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        case .paragraph:
            if let text = block.text {
                Text(verbatim: text)
                    .font(.body)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
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
                        .fixedSize(horizontal: false, vertical: true)
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
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(18)
                .breezeGlass(cornerRadius: 22, tint: Color.breezeCoral.opacity(0.08))
            }
        case .image:
            if let imageURL = block.imageURL {
                VStack(alignment: .leading, spacing: 8) {
                    RemoteMediaImage(url: imageURL) {
                        onImageTap(imageURL)
                    }
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
