import Foundation

struct HashtagStat: Identifiable, Hashable, Sendable {
    let tag: String
    let postCount: Int
    let storyCount: Int
    let sourceCount: Int

    var id: String { tag.lowercased() }
}

enum ContentEntityRoute: Identifiable, Hashable, Sendable {
    case profile(String)
    case hashtag(String)
    case link(URL)

    var id: String {
        switch self {
        case let .profile(handle): return "profile:\(handle.lowercased())"
        case let .hashtag(tag): return "hashtag:\(tag.lowercased())"
        case let .link(url): return "link:\(url.absoluteString)"
        }
    }

    var deepLink: URL? {
        var components = URLComponents()
        components.scheme = "bloxbreeze"
        switch self {
        case let .profile(handle):
            components.host = "profile"
            components.queryItems = [URLQueryItem(name: "handle", value: handle)]
        case let .hashtag(tag):
            components.host = "hashtag"
            components.queryItems = [URLQueryItem(name: "tag", value: tag)]
        case let .link(url):
            components.host = "link"
            components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        }
        return components.url
    }

    init?(deepLink: URL) {
        guard deepLink.scheme?.lowercased() == "bloxbreeze",
              let components = URLComponents(url: deepLink, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let values = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )
        switch components.host?.lowercased() {
        case "profile":
            guard let handle = values["handle"], !handle.isEmpty else { return nil }
            self = .profile(handle)
        case "hashtag":
            guard let tag = values["tag"], !tag.isEmpty else { return nil }
            self = .hashtag(tag)
        case "link":
            guard let value = values["url"], let url = URL(string: value) else { return nil }
            self = .link(NativeLinkResolver.secure(url))
        default:
            return nil
        }
    }
}

enum PostEntity: Hashable, Sendable {
    case mention(String)
    case hashtag(String)
    case link(URL)

    var route: ContentEntityRoute {
        switch self {
        case let .mention(handle): return .profile(handle)
        case let .hashtag(tag): return .hashtag(tag)
        case let .link(url): return .link(url)
        }
    }
}

struct PostEntityMatch: Hashable, Sendable {
    let range: NSRange
    let entity: PostEntity
}

enum PostEntityExtractor {
    private static let expression = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_])@[A-Za-z0-9_]{1,30}|(?<![\p{L}\p{N}_])#[\p{L}\p{N}_]+|https?://[^\s<]+"#,
        options: [.caseInsensitive]
    )

    static func matches(in text: String) -> [PostEntityMatch] {
        guard let expression else { return [] }
        return expression.matches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        ).compactMap { match in
            guard var stringRange = Range(match.range, in: text) else { return nil }
            var token = String(text[stringRange])

            if token.lowercased().hasPrefix("http") {
                while let last = token.last, ".,;:!?)]}".contains(last) {
                    token.removeLast()
                    stringRange = stringRange.lowerBound..<text.index(before: stringRange.upperBound)
                }
                guard let url = URL(string: token) else { return nil }
                return PostEntityMatch(
                    range: NSRange(stringRange, in: text),
                    entity: .link(NativeLinkResolver.secure(url))
                )
            }
            if token.hasPrefix("@") {
                return PostEntityMatch(
                    range: match.range,
                    entity: .mention(String(token.dropFirst()))
                )
            }
            return PostEntityMatch(
                range: match.range,
                entity: .hashtag(String(token.dropFirst()))
            )
        }
    }

    static func hashtags(in text: String) -> [String] {
        matches(in: text).compactMap {
            guard case let .hashtag(tag) = $0.entity else { return nil }
            return tag
        }
    }

    static func mentions(in text: String) -> [String] {
        matches(in: text).compactMap {
            guard case let .mention(handle) = $0.entity else { return nil }
            return handle
        }
    }
}

enum NativeLinkResolver {
    static func secure(_ url: URL) -> URL {
        guard url.scheme?.caseInsensitiveCompare("http") == .orderedSame,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.scheme = "https"
        if components.port == 80 { components.port = nil }
        return components.url ?? url
    }
}
