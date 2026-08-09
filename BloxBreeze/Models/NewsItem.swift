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

    var searchableText: String {
        [title, body, category, source.name, source.handle]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    var isFromX: Bool { source.kind == .x }

    var readingTime: Int {
        max(1, Int(ceil(Double(max(body.split(separator: " ").count, 120)) / 220.0)))
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
            metrics: metrics
        )
    }
}
