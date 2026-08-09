import Foundation

struct FreeXFeedService: Sendable {
    private let mirrorHosts = [
        "https://nitter.net",
        "https://nitter.space",
        "https://lightbrd.com",
        "https://nitter.catsarch.com"
    ]

    func fetch(sources: [NewsSource] = NewsSource.xSources) async throws -> [NewsItem] {
        var combined: [NewsItem] = []
        var failures: [String] = []

        for source in sources {
            do {
                combined.append(contentsOf: try await fetch(source: source))
            } catch {
                failures.append("\(source.name): \(error.localizedDescription)")
            }
        }

        guard !combined.isEmpty else {
            throw FeedError.parsing(
                failures.isEmpty
                    ? "The free X feed mirrors did not return any posts."
                    : failures.joined(separator: "\n")
            )
        }

        return combined.sorted { $0.publishedAt > $1.publishedAt }
    }

    private func fetch(source: NewsSource) async throws -> [NewsItem] {
        guard let handle = source.handle else { return [] }
        var lastError: Error = FeedError.invalidResponse

        for host in mirrorHosts {
            guard let encodedHandle = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "\(host)/\(encodedHandle)/rss") else { continue }

            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadRevalidatingCacheData
                request.setValue("BloxBreeze/1.1 (iOS; free native RSS reader)", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw FeedError.invalidResponse }
                guard (200..<300).contains(http.statusCode) else {
                    throw FeedError.server(status: http.statusCode, message: nil)
                }

                let items = try Self.parse(data, source: source)
                if !items.isEmpty { return Array(items.prefix(20)) }
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    static func parse(_ data: Data, source: NewsSource) throws -> [NewsItem] {
        let delegate = FreeXFeedDelegate(source: source)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw FeedError.parsing(parser.parserError?.localizedDescription ?? "A free X feed could not be read.")
        }
        return delegate.items
    }
}

private final class FreeXFeedDelegate: NSObject, XMLParserDelegate {
    private let source: NewsSource
    private var buffer = ""
    private var current: [String: String] = [:]
    private var insideItem = false
    private(set) var items: [NewsItem] = []

    init(source: NewsSource) {
        self.source = source
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
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

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard insideItem else { return }
        if elementName == "item" {
            makeItem()
            insideItem = false
        } else if ["title", "description", "pubDate", "guid", "link", "dc:creator", "creator"].contains(elementName) {
            current[elementName] = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        buffer = ""
    }

    private func makeItem() {
        let rawDescription = current["description"] ?? ""
        let body = rawDescription.nativePlainText
        let rawTitle = current["title"]?.nativePlainText ?? body
        let displayText = body.isEmpty ? rawTitle : body
        guard !displayText.isEmpty else { return }

        let firstLine = displayText.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? displayText
        let title = firstLine.count > 100 ? String(firstLine.prefix(97)) + "…" : firstLine
        let identifier = current["guid"] ?? "\(source.id)-\(current["pubDate"] ?? title)"
        let imageURL = Self.firstImageURL(in: rawDescription)

        items.append(
            NewsItem(
                id: "x:\(identifier)",
                source: source,
                title: title,
                body: displayText,
                category: "@\(source.handle ?? source.name)",
                articleURL: nil,
                imageURL: imageURL,
                publishedAt: Self.date(from: current["pubDate"]) ?? .distantPast,
                metrics: nil
            )
        )
    }

    private static func firstImageURL(in html: String) -> URL? {
        guard let regex = try? NSRegularExpression(
            pattern: #"<img[^>]+src=[\"'](?<url>[^\"']+)[\"']"#,
            options: [.caseInsensitive]
        ) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let urlRange = Range(match.range(withName: "url"), in: html) else { return nil }
        let value = String(html[urlRange]).replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: value)
    }

    private static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd MMM yyyy HH:mm:ss Z"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}

private extension String {
    var nativePlainText: String {
        replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

