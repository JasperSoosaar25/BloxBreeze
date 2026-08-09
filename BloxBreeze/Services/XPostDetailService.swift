import Foundation

struct XPostDetailService: Sendable {
    func fetch(for item: NewsItem) async throws -> XPostDetail {
        guard let statusID = Self.statusID(in: item.id),
              var components = URLComponents(string: "https://cdn.syndication.twimg.com/tweet-result") else {
            throw FeedError.parsing("This post did not contain a readable status ID.")
        }

        components.queryItems = [
            URLQueryItem(name: "id", value: statusID),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "token", value: "bloxbreeze")
        ]
        guard let url = components.url else { throw FeedError.invalidResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("BloxBreeze/1.2 (iOS; native media reader)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw FeedError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(SyndicatedPost.self, from: data)
        let media = (payload.mediaDetails ?? []).compactMap(Self.makeMedia)
        let cleanText = Self.cleanPostText(payload.text)

        return XPostDetail(
            text: cleanText.isEmpty ? item.body : cleanText,
            media: media
        )
    }

    static func statusID(in value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"/status/(\d+)"#),
              let match = regex.firstMatch(
                in: value,
                range: NSRange(value.startIndex..<value.endIndex, in: value)
              ),
              let range = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[range])
    }

    static func cleanPostText(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s*https?://\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[?\s*Source:\s*\]?"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"(?:Learn more|Watch on YouTube):\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n[ \\t]+", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeMedia(_ item: SyndicatedMedia) -> XPostMedia? {
        let ratio: Double? = {
            if let values = item.videoInfo?.aspectRatio,
               values.count == 2,
               values[1] != 0 {
                return values[0] / values[1]
            }
            if let info = item.originalInfo, info.height != 0 {
                return Double(info.width) / Double(info.height)
            }
            return nil
        }()

        let previewURL = highQualityImageURL(item.mediaUrlHttps)
        if item.type == "video" || item.type == "animated_gif" {
            let variants = item.videoInfo?.variants ?? []
            let mp4 = variants
                .filter { $0.contentType == "video/mp4" }
                .max { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) }
            let stream = mp4 ?? variants.first(where: { $0.contentType == "application/x-mpegURL" })
            guard let stream, let url = URL(string: stream.url) else { return nil }
            return XPostMedia(kind: .video, url: url, previewURL: previewURL, aspectRatio: ratio)
        }

        guard let imageURL = previewURL else { return nil }
        return XPostMedia(kind: .image, url: imageURL, previewURL: imageURL, aspectRatio: ratio)
    }

    private static func highQualityImageURL(_ value: String) -> URL? {
        guard var components = URLComponents(string: value) else { return nil }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "name" }
        items.append(URLQueryItem(name: "name", value: "large"))
        components.queryItems = items
        return components.url
    }
}

private struct SyndicatedPost: Decodable {
    let text: String
    let mediaDetails: [SyndicatedMedia]?
}

private struct SyndicatedMedia: Decodable {
    let type: String
    let mediaUrlHttps: String
    let originalInfo: SyndicatedOriginalInfo?
    let videoInfo: SyndicatedVideoInfo?
}

private struct SyndicatedOriginalInfo: Decodable {
    let height: Int
    let width: Int
}

private struct SyndicatedVideoInfo: Decodable {
    let aspectRatio: [Double]?
    let variants: [SyndicatedVideoVariant]
}

private struct SyndicatedVideoVariant: Decodable {
    let bitrate: Int?
    let contentType: String
    let url: String
}
