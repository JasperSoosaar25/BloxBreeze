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
        request.setValue("BloxBreeze/1.6 (iOS; native media reader)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw FeedError.invalidResponse
        }

        return try Self.parse(data, fallbackItem: item)
    }

    static func parse(_ data: Data, fallbackItem item: NewsItem) throws -> XPostDetail {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payloadText = payload["text"] as? String else {
            throw FeedError.parsing("The public media response did not contain a readable post.")
        }
        let mediaItems = payload["mediaDetails"] as? [[String: Any]] ?? []
        let media = mediaItems.compactMap(Self.makeMedia)
        let cleanText = Self.cleanPostText(payloadText)

        return XPostDetail(
            text: cleanText.isEmpty ? item.body : cleanText,
            media: media
        )
    }

    static func statusID(in value: String) -> String? {
        let patterns = [
            #"/status/(\d+)"#,
            #"(?:^|[^0-9])(\d{10,22})(?:$|[^0-9])"#
        ]
        let searchRange = NSRange(value.startIndex..<value.endIndex, in: value)

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: value, range: searchRange),
                  let range = Range(match.range(at: 1), in: value) else { continue }
            return String(value[range])
        }
        return nil
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

    private static func makeMedia(_ item: [String: Any]) -> XPostMedia? {
        guard let type = item["type"] as? String,
              let mediaURLValue = item["media_url_https"] as? String else { return nil }
        let originalInfo = item["original_info"] as? [String: Any]
        let videoInfo = item["video_info"] as? [String: Any]

        let ratio: Double? = {
            if let values = videoInfo?["aspect_ratio"] as? [NSNumber],
               values.count == 2,
               values[1].doubleValue != 0 {
                return values[0].doubleValue / values[1].doubleValue
            }
            if let width = (originalInfo?["width"] as? NSNumber)?.doubleValue,
               let height = (originalInfo?["height"] as? NSNumber)?.doubleValue,
               height != 0 {
                return width / height
            }
            return nil
        }()

        let previewURL = highQualityImageURL(mediaURLValue)
        if type == "video" || type == "animated_gif" {
            let variants = videoInfo?["variants"] as? [[String: Any]] ?? []
            let mp4Variants = variants.filter {
                ($0["content_type"] as? String) == "video/mp4"
            }
            let mp4 = mp4Variants.max {
                    (($0["bitrate"] as? NSNumber)?.intValue ?? 0) <
                        (($1["bitrate"] as? NSNumber)?.intValue ?? 0)
                }
            let stream = mp4 ?? variants.first(where: {
                ($0["content_type"] as? String) == "application/x-mpegURL"
            })
            guard let urlValue = stream?["url"] as? String,
                  let url = URL(string: urlValue) else { return nil }
            return XPostMedia(kind: .video, url: url, previewURL: previewURL, aspectRatio: ratio)
        }

        guard let imageURL = previewURL else { return nil }
        return XPostMedia(kind: .image, url: imageURL, previewURL: imageURL, aspectRatio: ratio)
    }

    private static func highQualityImageURL(_ value: String) -> URL? {
        guard var components = URLComponents(string: value) else { return nil }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "name" }
        items.append(URLQueryItem(name: "name", value: "orig"))
        components.queryItems = items
        return components.url
    }
}
