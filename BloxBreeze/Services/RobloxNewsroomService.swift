import Foundation
import UIKit

struct RobloxNewsroomService: Sendable {
    private let feedURL = URL(string: "https://about.roblox.com/newsroom")!

    func fetch() async throws -> [NewsItem] {
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 30
        request.setValue("BloxBreeze/1.0 (iOS; in-app news reader)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FeedError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.server(status: http.statusCode, message: nil)
        }
        guard let html = String(data: data, encoding: .utf8) else { throw FeedError.invalidResponse }
        let summaries = try Self.parse(html)

        return await withTaskGroup(of: NewsItem.self) { group in
            for summary in summaries {
                group.addTask { await Self.enrichDate(for: summary) }
            }
            var enriched: [NewsItem] = []
            for await item in group { enriched.append(item) }
            return enriched.sorted { $0.publishedAt > $1.publishedAt }
        }
    }

    static func parse(_ html: String) throws -> [NewsItem] {
        let pattern = #"<a href=\"(?<path>/newsroom/\d{4}/\d{2}/[^\"]+)\"[^>]*class=\"[^\"]*PreviewCard[^\"]*\"[^>]*>(?<card>.*?)</a>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)

        var seen = Set<String>()
        var items: [NewsItem] = []

        for (index, match) in matches.enumerated() {
            guard let pathRange = Range(match.range(withName: "path"), in: html),
                  let cardRange = Range(match.range(withName: "card"), in: html) else { continue }

            let path = String(html[pathRange])
            guard seen.insert(path).inserted else { continue }
            let card = String(html[cardRange])

            guard let rawTitle = firstCapture(
                in: card,
                pattern: #"PreviewCard_preview-card__heading[^\"]*\">(?<value>.*?)</h3>"#
            ) else { continue }

            let title = rawTitle.decodedHTML.trimmingCharacters(in: .whitespacesAndNewlines)
            let category = firstCapture(
                in: card,
                pattern: #"PreviewCard_preview-card__eyebrow[^\"]*\">(?<value>.*?)</h4>"#
            )?.decodedHTML.trimmingCharacters(in: .whitespacesAndNewlines)
            let imageString = firstCapture(in: card, pattern: #"<img[^>]+src=\"(?<value>[^\"]+)\""#)
            let articleURL = URL(string: "https://about.roblox.com\(path)")

            items.append(
                NewsItem(
                    id: "newsroom:\(path)",
                    source: .robloxNewsroom,
                    title: title,
                    body: "Open this story to read the complete official Roblox Newsroom article inside BloxBreeze.",
                    category: category,
                    articleURL: articleURL,
                    imageURL: imageString.flatMap(URL.init(string:)),
                    publishedAt: approximateDate(from: path, order: index),
                    metrics: nil
                )
            )
        }

        guard !items.isEmpty else {
            throw FeedError.parsing("Roblox Newsroom changed its page layout, so no stories could be read.")
        }
        return items
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(withName: "value"), in: text) else { return nil }
        return String(text[valueRange])
    }

    private static func approximateDate(from path: String, order: Int) -> Date {
        let parts = path.split(separator: "/")
        guard parts.count >= 3,
              let year = Int(parts[1]),
              let month = Int(parts[2]),
              let base = Calendar(identifier: .gregorian).date(
                from: DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: 1, hour: 12)
              ) else { return .now.addingTimeInterval(TimeInterval(-order)) }
        return base.addingTimeInterval(TimeInterval(-order))
    }

    private static func enrichDate(for item: NewsItem) async -> NewsItem {
        guard let url = item.articleURL else { return item }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("BloxBreeze/1.0 (iOS; in-app news reader)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8),
              let value = firstCapture(
                in: html,
                pattern: #"property=\"article:published_time\"\s+content=\"(?<value>[^\"]+)\""#
              ) else { return item }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: value) else { return item }
        return item.withPublishedAt(date)
    }
}

private extension String {
    var decodedHTML: String {
        guard let data = data(using: .utf8),
              let value = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ).string else { return self }
        return value
    }
}
