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
                request.setValue("BloxBreeze/1.6 (iOS; free native RSS reader)", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw FeedError.invalidResponse }
                guard (200..<300).contains(http.statusCode) else {
                    throw FeedError.server(status: http.statusCode, message: nil)
                }

                let items = try Self.parse(data, source: source)
                if !items.isEmpty {
                    return await enrichVideoMedia(in: Array(items.prefix(20)))
                }
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    private func enrichVideoMedia(in items: [NewsItem]) async -> [NewsItem] {
        await withTaskGroup(of: NewsItem.self) { group in
            for item in items {
                group.addTask {
                    guard item.hasVideoPreview else { return item }
                    guard let detail = try? await XPostDetailService().fetch(for: item),
                          detail.media.contains(where: { $0.kind == .video }) else { return item }
                    return item.withMedia(detail.media)
                }
            }

            var enriched: [NewsItem] = []
            for await item in group { enriched.append(item) }
            return enriched.sorted { $0.publishedAt > $1.publishedAt }
        }
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
    private struct ParsedEntry {
        let position: Int
        let identifier: String
        let rawTitle: String
        let displayText: String
        let companionURL: URL?
        let imageURL: URL?
        let publishedAt: Date
    }

    private let source: NewsSource
    private var buffer = ""
    private var current: [String: String] = [:]
    private var insideItem = false
    private var entries: [ParsedEntry] = []
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
            makeEntry()
            insideItem = false
        } else if ["title", "description", "pubDate", "guid", "link", "dc:creator", "creator"].contains(elementName) {
            current[elementName] = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        buffer = ""
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        buildItems()
    }

    private func makeEntry() {
        let rawDescription = current["description"] ?? ""
        let body = rawDescription.nativePostText
        let rawTitle = current["title"]?.nativePlainText ?? body
        let displayText = body.isEmpty ? rawTitle : body
        guard !displayText.isEmpty else { return }

        let companionURL = Self.firstCompanionURL(in: rawDescription)

        let identifier = current["guid"] ?? "\(source.id)-\(current["pubDate"] ?? displayText)"
        let imageURL = Self.firstImageURL(in: rawDescription)

        entries.append(
            ParsedEntry(
                position: entries.count,
                identifier: identifier,
                rawTitle: rawTitle,
                displayText: displayText,
                companionURL: companionURL,
                imageURL: imageURL,
                publishedAt: Self.date(from: current["pubDate"]) ?? .distantPast
            )
        )
    }

    private func buildItems() {
        var grouped: [(position: Int, item: NewsItem)] = []
        var threadParentIndex: Int?
        let chronologicalEntries = entries.sorted {
            if $0.publishedAt == $1.publishedAt { return $0.position < $1.position }
            return $0.publishedAt < $1.publishedAt
        }

        for entry in chronologicalEntries {
            let isSelfReply = Self.isSelfReply(entry.rawTitle, source: source)
            if isSelfReply,
               let threadParentIndex,
               grouped.indices.contains(threadParentIndex) {
                let reply = XThreadReply(
                    id: "x:\(entry.identifier)",
                    text: entry.displayText,
                    publishedAt: entry.publishedAt,
                    articleURL: entry.companionURL
                )
                var parent = grouped[threadParentIndex].item.withThreadReply(reply)
                if parent.articleURL == nil, let companionURL = entry.companionURL {
                    parent = parent.withArticleURL(companionURL)
                }
                grouped[threadParentIndex].item = parent
                continue
            }

            grouped.append((entry.position, makeNewsItem(from: entry)))
            threadParentIndex = isSelfReply ? nil : grouped.indices.last
        }

        items = grouped
            .sorted { $0.position < $1.position }
            .map { $0.item }
    }

    private func makeNewsItem(from entry: ParsedEntry) -> NewsItem {
        let firstLine = entry.displayText
            .split(separator: "\n", maxSplits: 1)
            .first
            .map(String.init) ?? entry.displayText
        let cleanTitle = firstLine
            .replacingOccurrences(of: #"\s+https?://\S+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return NewsItem(
            id: "x:\(entry.identifier)",
            source: source,
            title: cleanTitle.isEmpty ? firstLine : cleanTitle,
            body: entry.displayText,
            category: "@\(source.handle ?? source.name)",
            articleURL: entry.companionURL,
            imageURL: entry.imageURL,
            publishedAt: entry.publishedAt,
            metrics: nil
        )
    }

    private static func isSelfReply(_ title: String, source: NewsSource) -> Bool {
        guard let handle = source.handle else { return false }
        return title.range(
            of: "R to @\(handle):",
            options: [.anchored, .caseInsensitive]
        ) != nil
    }

    private static func firstCompanionURL(in html: String) -> URL? {
        guard let regex = try? NSRegularExpression(
            pattern: #"href\s*=\s*[\"'](?<url>https?://[^\"']+)[\"']"#,
            options: [.caseInsensitive]
        ) else { return nil }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for match in regex.matches(in: html, range: range) {
            guard let urlRange = Range(match.range(withName: "url"), in: html) else { continue }
            let value = String(html[urlRange])
                .replacingOccurrences(of: "&amp;", with: "&")
            guard let url = URL(string: value), isReadableCompanionURL(url) else { continue }
            return url
        }
        return nil
    }

    private static func isReadableCompanionURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let path = url.path.lowercased()

        if path.hasSuffix(".pdf") { return true }
        if host == "devforum.roblox.com" { return true }
        if host == "about.roblox.com" && path.contains("/newsroom/") { return true }
        if host == "ir.roblox.com" && path.contains("/news/") { return true }
        if host == "robloxrtc.com" || host == "www.robloxrtc.com" { return path.contains("/blog") }
        if host == "bloxy.news" || host == "www.bloxy.news" { return path.contains("/post/") }
        if host == "bloxynews.info" || host == "www.bloxynews.info" { return true }
        if host == "medium.com" || host.hasSuffix(".medium.com") { return true }
        return false
    }

    private static func firstImageURL(in html: String) -> URL? {
        let patterns = [
            #"<img[^>]+src=[\"'](?<url>[^\"']+)[\"']"#,
            #"<video[^>]+poster=[\"'](?<url>[^\"']+)[\"']"#
        ]
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: html, range: range),
                  let urlRange = Range(match.range(withName: "url"), in: html) else { continue }
            let value = String(html[urlRange]).replacingOccurrences(of: "&amp;", with: "&")
            if let url = URL(string: value) { return url }
        }
        return nil
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
    var nativePostText: String {
        let primaryHTML: String = {
            guard let regex = try? NSRegularExpression(
                pattern: #"<p\b[^>]*>(?<body>.*?)</p>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else { return self }
            let fullRange = NSRange(startIndex..<endIndex, in: self)
            guard let match = regex.firstMatch(in: self, range: fullRange),
                  let range = Range(match.range(withName: "body"), in: self) else { return self }
            return String(self[range])
        }()

        var withoutLinkCards = primaryHTML
        if let anchorRegex = try? NSRegularExpression(
            pattern: #"<a\b(?=[^>]*\bhref\s*=\s*[\"'](?<url>[^\"']+)[\"'])[^>]*>(?<label>.*?)</a>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) {
            let matches = anchorRegex.matches(
                in: withoutLinkCards,
                range: NSRange(withoutLinkCards.startIndex..<withoutLinkCards.endIndex, in: withoutLinkCards)
            )
            for match in matches.reversed() {
                guard let wholeRange = Range(match.range, in: withoutLinkCards),
                      let labelRange = Range(match.range(withName: "label"), in: withoutLinkCards),
                      let urlRange = Range(match.range(withName: "url"), in: withoutLinkCards) else { continue }
                let label = String(withoutLinkCards[labelRange]).nativePlainText
                let href = String(withoutLinkCards[urlRange])
                    .replacingOccurrences(of: "&amp;", with: "&")
                let replacement: String
                if label.hasPrefix("@") || label.hasPrefix("#") {
                    replacement = label
                } else if href.lowercased().hasPrefix("http://") || href.lowercased().hasPrefix("https://") {
                    replacement = href
                } else {
                    replacement = label
                }
                withoutLinkCards.replaceSubrange(wholeRange, with: replacement)
            }
        }

        return withoutLinkCards.nativePlainText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare("Video") != .orderedSame && $0.caseInsensitiveCompare("Link") != .orderedSame }
            .joined(separator: "\n\n")
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nativePlainText: String {
        replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
