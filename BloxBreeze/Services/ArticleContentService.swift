import Foundation
import SwiftSoup

struct ArticleContentService: Sendable {
    func fetch(item: NewsItem) async throws -> NativeArticle {
        guard let url = item.articleURL else {
            throw FeedError.parsing("This story has no article address.")
        }

        switch item.source.kind {
        case .newsroom:
            let html = try await fetchText(from: url)
            return try Self.parseNewsroom(html, item: item)
        case .developerForum:
            let topicURL = Self.forumJSONURL(from: url)
            let data = try await fetchData(from: topicURL)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let topic = try decoder.decode(ForumTopic.self, from: data)
            guard let firstPost = topic.postStream.posts.first else {
                throw FeedError.parsing("The official announcement did not contain a readable post.")
            }
            return try Self.parseForum(topic: topic, post: firstPost, item: item)
        case .x:
            throw FeedError.parsing("X posts are already displayed natively.")
        }
    }

    static func parseNewsroom(_ html: String, item: NewsItem) throws -> NativeArticle {
        let document = try SwiftSoup.parse(html)
        guard let article = try document.select("article").first() else {
            throw FeedError.parsing("The Roblox article could not be found in the response.")
        }

        let content = try article.select("[class*=NewsArticle_news__content__]").first() ?? article
        let title = try article.select("h1").first()?.text().nonEmpty ?? item.title
        let subtitle = try article.select("[class*=NewsArticle_news__text-group__] p.body--large").first()?.text().nonEmpty
        let bylineParts = try article.select("[class*=NewsArticle_news__byline__] p")
            .array()
            .compactMap { try? $0.text().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let byline = bylineParts.first(where: { $0.lowercased().hasPrefix("by ") })
        let blocks = try parseBlocks(in: content, baseURL: item.articleURL, excludingImage: item.imageURL)

        guard !blocks.isEmpty else {
            throw FeedError.parsing("The Roblox article was found, but its native text was empty.")
        }

        return NativeArticle(
            title: title,
            subtitle: subtitle,
            byline: byline,
            publishedAt: item.publishedAt,
            heroImageURL: item.imageURL,
            blocks: blocks
        )
    }

    private static func parseForum(topic: ForumTopic, post: ForumPost, item: NewsItem) throws -> NativeArticle {
        let document = try SwiftSoup.parseBodyFragment(normalizeForumEmojiImages(post.cooked))
        guard let body = try document.select("body").first() else {
            throw FeedError.parsing("The official announcement body could not be read.")
        }
        let blocks = try parseBlocks(in: body, baseURL: item.articleURL, excludingImage: nil)
        guard !blocks.isEmpty else {
            throw FeedError.parsing("The official announcement did not contain native text.")
        }

        return NativeArticle(
            title: topic.title,
            subtitle: nil,
            byline: post.displayUsername.map { "By \($0)" },
            publishedAt: isoDate(post.createdAt) ?? item.publishedAt,
            heroImageURL: nil,
            blocks: blocks
        )
    }

    private static func parseBlocks(
        in root: Element,
        baseURL: URL?,
        excludingImage: URL?
    ) throws -> [NativeArticleBlock] {
        var blocks: [NativeArticleBlock] = []
        var seenImages = Set<String>()
        if let excludingImage { seenImages.insert(excludingImage.absoluteString) }

        func addText(_ text: String, kind: NativeArticleBlock.Kind, level: Int? = nil) {
            let clean = text
                .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return }
            blocks.append(
                NativeArticleBlock(
                    id: "block-\(blocks.count)",
                    kind: kind,
                    text: clean,
                    imageURL: nil,
                    caption: nil,
                    headingLevel: level
                )
            )
        }

        func addImage(_ image: Element) throws {
            let source = try image.attr("src")
            let classes = try image.attr("class").lowercased()
            let altText = try image.attr("alt")
            if classes.split(separator: " ").contains("emoji") ||
                source.localizedCaseInsensitiveContains("/emoji/") ||
                altText.range(of: #"^:[a-z0-9_+\-]+:$"#, options: [.regularExpression, .caseInsensitive]) != nil {
                return
            }
            let rawSource: String
            if source.isEmpty {
                rawSource = try image.attr("data-src")
            } else {
                rawSource = source
            }
            guard !rawSource.isEmpty,
                  let resolved = URL(string: rawSource, relativeTo: baseURL)?.absoluteURL,
                  seenImages.insert(resolved.absoluteString).inserted else { return }
            let alt = try image.attr("alt").trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            blocks.append(
                NativeArticleBlock(
                    id: "block-\(blocks.count)",
                    kind: .image,
                    text: nil,
                    imageURL: resolved,
                    caption: alt,
                    headingLevel: nil
                )
            )
        }

        func addNestedImages(_ element: Element) throws {
            for image in try element.select("img").array() { try addImage(image) }
        }

        func visit(_ element: Element) throws {
            let tag = element.tagName().lowercased()
            switch tag {
            case "h1", "h2", "h3", "h4", "h5", "h6":
                addText(try element.text(), kind: .heading, level: Int(tag.dropFirst()))
                try addNestedImages(element)
            case "p":
                addText(try element.text(), kind: .paragraph)
                try addNestedImages(element)
            case "li":
                addText(try element.text(), kind: .bullet)
                try addNestedImages(element)
            case "blockquote":
                addText(try element.text(), kind: .quote)
                try addNestedImages(element)
            case "img":
                try addImage(element)
            case "script", "style", "button", "nav", "footer":
                return
            default:
                for child in element.children().array() { try visit(child) }
            }
        }

        for child in root.children().array() { try visit(child) }
        return blocks
    }

    private func fetchText(from url: URL) async throws -> String {
        let data = try await fetchData(from: url)
        guard let text = String(data: data, encoding: .utf8) else { throw FeedError.invalidResponse }
        return text
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("BloxBreeze/1.3 (iOS; native article reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FeedError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.server(status: http.statusCode, message: nil)
        }
        return data
    }

    private static func forumJSONURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.query = nil
        components.fragment = nil
        while components.path.hasSuffix("/") { components.path.removeLast() }
        if !components.path.hasSuffix(".json") { components.path += ".json" }
        return components.url ?? url
    }

    private static func isoDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = formatter.date(from: string) { return value }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    static func normalizeForumEmojiImages(_ html: String) -> String {
        guard let imageRegex = try? NSRegularExpression(
            pattern: #"<img\b[^>]*>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ), let nameRegex = try? NSRegularExpression(
            pattern: #"(?:title|alt)=[\"']:(?<name>[a-z0-9_+\-]+):[\"']"#,
            options: [.caseInsensitive]
        ) else { return html }

        var result = html
        let imageMatches = imageRegex.matches(
            in: result,
            range: NSRange(result.startIndex..<result.endIndex, in: result)
        )

        for imageMatch in imageMatches.reversed() {
            guard let imageRange = Range(imageMatch.range, in: result) else { continue }
            let tag = String(result[imageRange])
            let lowercased = tag.lowercased()

            let tagRange = NSRange(tag.startIndex..<tag.endIndex, in: tag)
            let name = nameRegex.firstMatch(in: tag, range: tagRange).flatMap { match -> String? in
                guard let range = Range(match.range(withName: "name"), in: tag) else { return nil }
                return String(tag[range]).lowercased()
            }
            let isEmoji = lowercased.contains("class=\"emoji") ||
                lowercased.contains("class='emoji") ||
                lowercased.contains("/emoji/") ||
                name != nil
            guard isEmoji else { continue }
            let replacement = name.map { forumEmoji(named: $0) } ?? ""
            result.replaceSubrange(imageRange, with: replacement)
        }
        return result
    }

    private static func forumEmoji(named name: String) -> String {
        let replacements: [String: String] = [
            "star2": "🌟",
            "sparkles": "✨",
            "tada": "🎉",
            "rocket": "🚀",
            "fire": "🔥",
            "heart": "❤️",
            "eyes": "👀",
            "wave": "👋",
            "warning": "⚠️",
            "white_check_mark": "✅",
            "information_source": "ℹ️",
            "bulb": "💡",
            "zap": "⚡"
        ]
        return replacements[name] ?? ":\(name):"
    }
}

private struct ForumTopic: Decodable {
    let title: String
    let postStream: ForumPostStream
}

private struct ForumPostStream: Decodable {
    let posts: [ForumPost]
}

private struct ForumPost: Decodable {
    let cooked: String
    let createdAt: String?
    let displayUsername: String?
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
