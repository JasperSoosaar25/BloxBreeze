import Foundation

struct DeveloperForumService: Sendable {
    private let feedURL = URL(string: "https://devforum.roblox.com/c/updates/announcements/36.rss")!

    func fetch() async throws -> [NewsItem] {
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 30
        request.setValue("BloxBreeze/1.0 (iOS; in-app news reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FeedError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.server(status: http.statusCode, message: nil)
        }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> [NewsItem] {
        let delegate = RSSDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw FeedError.parsing(parser.parserError?.localizedDescription ?? "The Creator Updates feed could not be read.")
        }
        return delegate.items
    }
}

private final class RSSDelegate: NSObject, XMLParserDelegate {
    private var element = ""
    private var buffer = ""
    private var current: [String: String] = [:]
    private var insideItem = false
    private(set) var items: [NewsItem] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        element = elementName
        buffer = ""
        if elementName == "item" {
            insideItem = true
            current = [:]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard insideItem, let value = String(data: CDATABlock, encoding: .utf8) else { return }
        buffer += value
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard insideItem else { return }
        if elementName == "item" {
            makeItem()
            insideItem = false
        } else if ["title", "link", "pubDate", "description", "category"].contains(elementName) {
            current[elementName] = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        element = ""
        buffer = ""
    }

    private func makeItem() {
        guard let title = current["title"],
              let link = current["link"],
              let url = URL(string: link) else { return }

        items.append(
            NewsItem(
                id: "devforum:\(link)",
                source: .developerForum,
                title: title.plainText,
                body: (current["description"] ?? "Official Roblox creator announcement.").plainText,
                category: current["category"],
                articleURL: url,
                imageURL: nil,
                publishedAt: Self.date(from: current["pubDate"]) ?? .distantPast,
                metrics: nil
            )
        )
    }

    private static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}

private extension String {
    var plainText: String {
        let withoutTags = replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

