import Foundation

struct NewsItem: Identifiable, Codable, Hashable, Sendable {
    struct Metrics: Codable, Hashable, Sendable {
        let replies: Int
        let reposts: Int
        let likes: Int
        let views: Int?
    }

    let id: String
    let source: NewsSource
    let title: String
    let body: String
    let category: String?
    let articleURL: URL?
    let imageURL: URL?
    let publishedAt: Date
    let metrics: Metrics?
    let media: [XPostMedia]?
    let threadReplies: [XThreadReply]?

    init(
        id: String,
        source: NewsSource,
        title: String,
        body: String,
        category: String?,
        articleURL: URL?,
        imageURL: URL?,
        publishedAt: Date,
        metrics: Metrics?,
        media: [XPostMedia]? = nil,
        threadReplies: [XThreadReply]? = nil
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.body = body
        self.category = category
        self.articleURL = articleURL
        self.imageURL = imageURL
        self.publishedAt = publishedAt
        self.metrics = metrics
        self.media = media
        self.threadReplies = threadReplies
    }

    private var searchableParts: [String] {
        [title, body, category, source.name, source.handle]
            .compactMap { $0 }
            + orderedThreadReplies.map(\.text)
    }

    var searchableText: String {
        searchableParts
            .joined(separator: " ")
    }

    var isFromX: Bool { source.kind == .x }

    var hasVideoPreview: Bool {
        if media?.contains(where: { $0.kind == .video }) == true { return true }
        guard let value = imageURL?.absoluteString.lowercased() else { return false }
        return value.contains("video_thumb") || value.contains("amplify_video_thumb")
    }

    var readingTime: Int {
        let words = ([body] + orderedThreadReplies.map(\.text))
            .joined(separator: " ")
            .split(separator: " ")
            .count
        return max(1, Int(ceil(Double(max(words, 120)) / 220.0)))
    }

    var orderedThreadReplies: [XThreadReply] {
        (threadReplies ?? []).sorted {
            if $0.publishedAt == $1.publishedAt { return $0.id < $1.id }
            return $0.publishedAt < $1.publishedAt
        }
    }

    func withPublishedAt(_ date: Date) -> NewsItem {
        NewsItem(
            id: id,
            source: source,
            title: title,
            body: body,
            category: category,
            articleURL: articleURL,
            imageURL: imageURL,
            publishedAt: date,
            metrics: metrics,
            media: media,
            threadReplies: threadReplies
        )
    }

    func withMedia(_ media: [XPostMedia]) -> NewsItem {
        NewsItem(
            id: id,
            source: source,
            title: title,
            body: body,
            category: category,
            articleURL: articleURL,
            imageURL: imageURL,
            publishedAt: publishedAt,
            metrics: metrics,
            media: media,
            threadReplies: threadReplies
        )
    }

    func withArticleURL(_ articleURL: URL) -> NewsItem {
        NewsItem(
            id: id,
            source: source,
            title: title,
            body: body,
            category: category,
            articleURL: articleURL,
            imageURL: imageURL,
            publishedAt: publishedAt,
            metrics: metrics,
            media: media,
            threadReplies: threadReplies
        )
    }

    func withThreadReply(_ reply: XThreadReply) -> NewsItem {
        var replies = threadReplies ?? []
        if !replies.contains(where: { $0.id == reply.id }) {
            replies.append(reply)
        }
        return NewsItem(
            id: id,
            source: source,
            title: title,
            body: body,
            category: category,
            articleURL: articleURL,
            imageURL: imageURL,
            publishedAt: publishedAt,
            metrics: metrics,
            media: media,
            threadReplies: replies
        )
    }
}
