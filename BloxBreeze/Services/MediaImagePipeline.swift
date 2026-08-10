import Foundation
import ImageIO
import UIKit

actor MediaImagePipeline {
    static let shared = MediaImagePipeline()

    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 24
        cache.totalCostLimit = 160 * 1_024 * 1_024
        return cache
    }()

    func image(for sourceURL: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: sourceURL as NSURL) {
            return cached
        }

        var lastError: Error = MediaImageError.unavailable
        for candidate in Self.candidateURLs(for: sourceURL) {
            do {
                var request = URLRequest(url: candidate)
                request.cachePolicy = .returnCacheDataElseLoad
                request.timeoutInterval = 35
                request.setValue(
                    "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
                    forHTTPHeaderField: "Accept"
                )
                request.setValue(
                    "BloxBreeze/1.6 (iPhone; native high-quality media reader)",
                    forHTTPHeaderField: "User-Agent"
                )

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      !data.isEmpty,
                      let image = Self.decodeImage(data) else {
                    throw MediaImageError.unavailable
                }

                let cost = Self.cacheCost(for: image)
                cache.setObject(image, forKey: sourceURL as NSURL, cost: cost)
                cache.setObject(image, forKey: candidate as NSURL, cost: cost)
                return image
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    nonisolated static func candidateURLs(for sourceURL: URL) -> [URL] {
        var candidates: [URL] = []

        func append(_ url: URL?) {
            guard let url, !candidates.contains(url) else { return }
            candidates.append(url)
        }

        append(originalTwitterURL(from: sourceURL))
        append(originalDiscourseURL(from: sourceURL))
        append(secureURL(from: sourceURL))
        append(sourceURL)
        return candidates
    }

    nonisolated private static func originalTwitterURL(from url: URL) -> URL? {
        let host = url.host?.lowercased() ?? ""
        var resolved = url

        if host.contains("nitter"),
           let marker = url.absoluteString.range(of: "/pic/") {
            var tail = String(url.absoluteString[marker.upperBound...])
            for _ in 0..<2 {
                guard let decoded = tail.removingPercentEncoding, decoded != tail else { break }
                tail = decoded
            }
            tail = tail.replacingOccurrences(of: "&amp;", with: "&")

            if let absolute = URL(string: tail), absolute.scheme != nil {
                resolved = absolute
            } else {
                let cleanTail = tail.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard let origin = URL(string: "https://pbs.twimg.com/\(cleanTail)") else { return nil }
                resolved = origin
            }
        }

        guard resolved.host?.caseInsensitiveCompare("pbs.twimg.com") == .orderedSame,
              var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else {
            return resolved == url ? nil : resolved
        }
        var query = components.queryItems ?? []
        query.removeAll { $0.name.caseInsensitiveCompare("name") == .orderedSame }
        query.append(URLQueryItem(name: "name", value: "orig"))
        components.queryItems = query
        return components.url
    }

    nonisolated private static func originalDiscourseURL(from url: URL) -> URL? {
        guard url.path.contains("/uploads/optimized/"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let originalPath = components.path.replacingOccurrences(
            of: #"/uploads/optimized/(.+)_\d+_\d+x\d+(\.[A-Za-z0-9]+)$"#,
            with: "/uploads/original/$1$2",
            options: .regularExpression
        )
        guard originalPath != components.path else { return nil }
        components.path = originalPath
        components.query = nil
        return components.url
    }

    nonisolated private static func secureURL(from url: URL) -> URL? {
        guard url.scheme?.lowercased() == "http",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "https"
        return components.url
    }

    nonisolated private static func decodeImage(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return UIImage(data: data) }

        let stride = max(1, Int(ceil(Double(frameCount) / 120.0)))
        var frames: [UIImage] = []
        var duration = 0.0

        for index in Swift.stride(from: 0, to: frameCount, by: stride) {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage, scale: 1, orientation: .up))

            let frameEnd = min(frameCount, index + stride)
            for timingIndex in index..<frameEnd {
                duration += frameDuration(source: source, index: timingIndex)
            }
        }

        guard frames.count > 1 else { return frames.first ?? UIImage(data: data) }
        return UIImage.animatedImage(with: frames, duration: max(duration, 0.1))
    }

    nonisolated private static func frameDuration(
        source: CGImageSource,
        index: Int
    ) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
            as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let unclamped = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
        let clamped = (gif[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue
        let value = unclamped ?? clamped ?? 0.1
        return value < 0.02 ? 0.1 : value
    }

    nonisolated private static func cacheCost(for image: UIImage) -> Int {
        let frameCount = max(1, image.images?.count ?? 1)
        return Int(image.size.width * image.scale * image.size.height * image.scale * 4) * frameCount
    }
}

private enum MediaImageError: Error {
    case unavailable
}
