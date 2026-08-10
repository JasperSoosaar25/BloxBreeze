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
            return try await fetchForum(item: item, url: url)
        case .x:
            if Self.isForumURL(url) {
                return try await fetchForum(item: item, url: url)
            }
            if Self.isNewsroomURL(url) {
                let html = try await fetchText(from: url)
                return try Self.parseNewsroom(html, item: item)
            }
            guard !Self.isPDFURL(url) else {
                throw FeedError.parsing("This source is a document and uses the native document reader.")
            }
            let html = try await fetchText(from: url)
            return try Self.parseGenericArticle(html, item: item)
        }
    }

    private func fetchForum(item: NewsItem, url: URL) async throws -> NativeArticle {
        let topicURL = Self.forumJSONURL(from: url)
        let data = try await fetchData(from: topicURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let topic = try decoder.decode(ForumTopic.self, from: data)
        guard let firstPost = topic.postStream.posts.first else {
            throw FeedError.parsing("The announcement did not contain a readable post.")
        }
        return try Self.parseForum(topic: topic, post: firstPost, item: item)
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

    static func parseGenericArticle(_ html: String, item: NewsItem) throws -> NativeArticle {
        let document = try SwiftSoup.parse(html, item.articleURL?.absoluteString ?? "")
        let openGraphTitle = try document
            .select("meta[property=og:title]")
            .first()?
            .attr("content")
            .nonEmpty
        let headingTitle = try document
            .select("article h1, main h1, h1")
            .first()?
            .text()
            .nonEmpty
        let documentTitle = try document.title().nonEmpty
        let title = openGraphTitle ?? headingTitle ?? documentTitle ?? item.title

        let openGraphDescription = try document
            .select("meta[property=og:description]")
            .first()?
            .attr("content")
            .nonEmpty
        let metaDescription = try document
            .select("meta[name=description]")
            .first()?
            .attr("content")
            .nonEmpty
        let subtitle = openGraphDescription ?? metaDescription

        let metaAuthor = try document
            .select("meta[name=author]")
            .first()?
            .attr("content")
            .nonEmpty
        let visibleAuthor = try document
            .select("[rel=author], [class*=author]")
            .first()?
            .text()
            .nonEmpty
        let author = metaAuthor ?? visibleAuthor

        let articleRoot = try document.select("article").first()
        let mainRoot = try document.select("main").first()
        let roleRoot = try document.select("[role=main]").first()
        let root = articleRoot ?? mainRoot ?? roleRoot ?? document.body()
        guard let root else {
            throw FeedError.parsing("The linked article did not contain readable content.")
        }

        let heroImageValue = try document
            .select("meta[property=og:image]")
            .first()?
            .attr("content")
            .nonEmpty
        let heroImageURL = heroImageValue.flatMap {
            URL(string: $0, relativeTo: item.articleURL)?.absoluteURL
        }
        var blocks = try parseBlocks(
            in: root,
            baseURL: item.articleURL,
            excludingImage: heroImageURL
        )
        if blocks.first?.kind == .heading && blocks.first?.text == title {
            blocks.removeFirst()
        }
        guard !blocks.isEmpty else {
            throw FeedError.parsing("The linked article was found, but its native text was empty.")
        }

        return NativeArticle(
            title: title,
            subtitle: subtitle,
            byline: author.map { $0.lowercased().hasPrefix("by ") ? $0 : "By \($0)" },
            publishedAt: item.publishedAt,
            heroImageURL: heroImageURL,
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
            let clean = Self.cleanAttachmentText(text)
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
            guard let rawSource = try Self.bestImageSource(for: image),
                  let resolved = Self.resolveMediaURL(rawSource, relativeTo: baseURL),
                  seenImages.insert(resolved.absoluteString).inserted else { return }
            let alt = Self.meaningfulImageCaption(try image.attr("alt"))
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

        func readableText(_ element: Element, excludingNestedLists: Bool = false) throws -> String {
            let fragment = try SwiftSoup.parseBodyFragment(try element.html())
            guard let body = fragment.body() else { return try element.text() }
            try body.select("img, svg, .lightbox-wrapper, .meta, a.attachment").remove()
            if excludingNestedLists {
                try body.select("ul, ol").remove()
            }
            return try body.text()
        }

        func addNestedListItems(_ element: Element) throws {
            for list in element.children().array()
                where ["ul", "ol"].contains(list.tagName().lowercased()) {
                for child in list.children().array() where child.tagName().lowercased() == "li" {
                    try visit(child)
                }
            }
        }

        func visit(_ element: Element) throws {
            let tag = element.tagName().lowercased()
            switch tag {
            case "h1", "h2", "h3", "h4", "h5", "h6":
                addText(try readableText(element), kind: .heading, level: Int(tag.dropFirst()))
                try addNestedImages(element)
            case "p":
                addText(try readableText(element), kind: .paragraph)
                try addNestedImages(element)
            case "li":
                addText(try readableText(element, excludingNestedLists: true), kind: .bullet)
                try addNestedImages(element)
                try addNestedListItems(element)
            case "blockquote":
                addText(try readableText(element), kind: .quote)
                try addNestedImages(element)
            case "img":
                try addImage(element)
            case "script", "style", "button", "nav", "footer", "header", "aside", "form", "svg", "noscript":
                return
            default:
                for child in element.children().array() { try visit(child) }
            }
        }

        for child in root.children().array() { try visit(child) }
        return blocks
    }

    private static func bestImageSource(for image: Element) throws -> String? {
        if let parent = image.parent(),
           parent.tagName().lowercased() == "a" {
            let href = try parent.attr("href")
            let parentClasses = try parent.attr("class").lowercased()
            if !href.isEmpty && (parentClasses.contains("lightbox") || looksLikeImageAddress(href)) {
                return href
            }
        }

        for attribute in ["data-orig-src", "data-original"] {
            let value = try image.attr(attribute)
            if isUsableImageAddress(value) { return value }
        }

        let srcset = try image.attr("srcset")
        if !srcset.isEmpty {
            for candidate in srcset.split(separator: ",").reversed() {
                let value = candidate
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(whereSeparator: { $0.isWhitespace })
                    .first
                    .map(String.init) ?? ""
                if isUsableImageAddress(value) { return value }
            }
        }

        let lazySource = try image.attr("data-src")
        if isUsableImageAddress(lazySource) { return lazySource }

        let source = try image.attr("src")
        return isUsableImageAddress(source) ? source : nil
    }

    private static func resolveMediaURL(_ value: String, relativeTo baseURL: URL?) -> URL? {
        let clean = value
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved: URL?
        if clean.hasPrefix("//") {
            resolved = URL(string: "\(baseURL?.scheme ?? "https"):\(clean)")
        } else {
            resolved = URL(string: clean, relativeTo: baseURL)?.absoluteURL
        }
        guard let resolved,
              ["http", "https"].contains(resolved.scheme?.lowercased() ?? "") else {
            return nil
        }
        return resolved
    }

    private static func isUsableImageAddress(_ value: String) -> Bool {
        let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !lowercased.isEmpty &&
            !lowercased.hasPrefix("data:") &&
            !lowercased.hasPrefix("blob:") &&
            !lowercased.hasPrefix("upload:")
    }

    private static func looksLikeImageAddress(_ value: String) -> Bool {
        let path = URL(string: value)?.path.lowercased() ?? value.lowercased()
        return [".avif", ".gif", ".heic", ".jpeg", ".jpg", ".png", ".webp"]
            .contains { path.hasSuffix($0) }
    }

    private static func meaningfulImageCaption(_ value: String) -> String? {
        let caption = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !caption.isEmpty,
              caption.range(
                of: #"^:[a-z0-9_+\-]+:$"#,
                options: [.regularExpression, .caseInsensitive]
              ) == nil else { return nil }

        let lowercased = caption.lowercased()
        if lowercased.range(of: #"^image\d*$"#, options: .regularExpression) != nil ||
            lowercased.range(of: #"^screenshot(?:[ _-]|$)"#, options: .regularExpression) != nil ||
            lowercased.range(of: #"^\d{4}[-_.]\d{2}[-_.]\d{2}"#, options: .regularExpression) != nil ||
            (!caption.contains(" ") && caption.contains("_")) ||
            lowercased.range(
                of: #"\.(?:avif|gif|heic|jpeg|jpg|png|webp)$"#,
                options: .regularExpression
            ) != nil {
            return nil
        }
        return caption
    }

    private static func cleanAttachmentText(_ value: String) -> String {
        value
            .replacingOccurrences(
                of: #"\d{2,5}[×x]\d{2,5}\s+\d+(?:\.\d+)?\s*(?:KB|MB)"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"\s*\(\d+(?:\.\d+)?\s*(?:KB|MB)\)\s*$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"\s+image\d*\s*$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
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
        request.setValue("BloxBreeze/1.5 (iOS; native article reader)", forHTTPHeaderField: "User-Agent")
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

    static func isPDFURL(_ url: URL) -> Bool {
        url.path.lowercased().hasSuffix(".pdf")
    }

    private static func isForumURL(_ url: URL) -> Bool {
        url.host?.caseInsensitiveCompare("devforum.roblox.com") == .orderedSame
    }

    private static func isNewsroomURL(_ url: URL) -> Bool {
        url.host?.caseInsensitiveCompare("about.roblox.com") == .orderedSame &&
            url.path.lowercased().contains("/newsroom/")
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
            "star2": "\u{1F31F}",
            "sparkles": "\u{2728}",
            "tada": "\u{1F389}",
            "rocket": "\u{1F680}",
            "fire": "\u{1F525}",
            "heart": "\u{2764}\u{FE0F}",
            "blue_heart": "\u{1F499}",
            "eyes": "\u{1F440}",
            "wave": "\u{1F44B}",
            "warning": "\u{26A0}\u{FE0F}",
            "white_check_mark": "\u{2705}",
            "information_source": "\u{2139}\u{FE0F}",
            "bulb": "\u{1F4A1}",
            "light_bulb": "\u{1F4A1}",
            "zap": "\u{26A1}",
            "high_voltage": "\u{26A1}",
            "hammer_and_wrench": "\u{1F6E0}\u{FE0F}",
            "bar_chart": "\u{1F4CA}",
            "construction": "\u{1F6A7}",
            "grinning_face": "\u{1F600}",
            "blush": "\u{1F60A}",
            "one": "1\u{FE0F}\u{20E3}",
            "two": "2\u{FE0F}\u{20E3}",
            "three": "3\u{FE0F}\u{20E3}",
            "plus": "\u{2795}",
            "+1": "\u{1F44D}",
            "shield": "\u{1F6E1}\u{FE0F}",
            "bug": "\u{1F41B}",
            "crystal_ball": "\u{1F52E}",
            "magnifying_glass_tilted_left": "\u{1F50D}",
            "new_button": "\u{1F195}",
            "black_square_button": "\u{1F532}"
        ]
        return replacements[name] ?? ""
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
