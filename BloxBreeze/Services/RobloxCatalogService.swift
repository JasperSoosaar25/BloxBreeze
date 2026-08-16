import Foundation

struct RobloxCatalogService: Sendable {
    func fetch(url: URL) async -> RobloxCatalogItem? {
        guard let identity = Self.identity(from: url) else { return nil }
        async let details = fetchDetails(id: identity.id)
        async let thumbnail = fetchThumbnail(id: identity.id)
        let loadedDetails = await details
        let loadedThumbnail = await thumbnail

        return RobloxCatalogItem(
            id: identity.id,
            name: loadedDetails?.name ?? identity.fallbackName,
            description: loadedDetails?.description?.nonEmpty,
            creatorName: loadedDetails?.creator?.name,
            creatorIsVerified: loadedDetails?.creator?.hasVerifiedBadge ?? false,
            price: loadedDetails?.priceInRobux,
            isForSale: loadedDetails?.isForSale,
            thumbnailURL: loadedThumbnail
        )
    }

    static func isCatalogURL(_ url: URL) -> Bool {
        identity(from: url) != nil
    }

    private static func identity(from url: URL) -> (id: Int64, fallbackName: String)? {
        guard let host = url.host?.lowercased(),
              host == "roblox.com" || host.hasSuffix(".roblox.com") else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let catalogIndex = parts.firstIndex(where: { $0.caseInsensitiveCompare("catalog") == .orderedSame }),
              parts.indices.contains(catalogIndex + 1),
              let id = Int64(parts[catalogIndex + 1]) else { return nil }
        let slug = parts.indices.contains(catalogIndex + 2) ? parts[catalogIndex + 2] : "Roblox item"
        let name = slug
            .replacingOccurrences(of: "-", with: " ")
            .removingPercentEncoding ?? slug
        return (id, name)
    }

    private func fetchDetails(id: Int64) async -> EconomyDetails? {
        guard let url = URL(string: "https://economy.roblox.com/v2/assets/\(id)/details") else { return nil }
        guard let data = try? await fetchData(from: url) else { return nil }
        return try? JSONDecoder().decode(EconomyDetails.self, from: data)
    }

    private func fetchThumbnail(id: Int64) async -> URL? {
        guard var components = URLComponents(string: "https://thumbnails.roblox.com/v1/assets") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "assetIds", value: String(id)),
            URLQueryItem(name: "returnPolicy", value: "PlaceHolder"),
            URLQueryItem(name: "size", value: "768x432"),
            URLQueryItem(name: "format", value: "Png"),
            URLQueryItem(name: "isCircular", value: "false")
        ]
        guard let url = components.url,
              let data = try? await fetchData(from: url),
              let response = try? JSONDecoder().decode(ThumbnailResponse.self, from: data),
              let thumbnail = response.data.first,
              thumbnail.state.caseInsensitiveCompare("Completed") == .orderedSame else { return nil }
        return URL(string: thumbnail.imageUrl)
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("BloxBreeze/1.7 (iOS; native Roblox link reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { throw FeedError.invalidResponse }
        return data
    }
}

private struct EconomyDetails: Decodable {
    let name: String
    let description: String?
    let creator: EconomyCreator?
    let priceInRobux: Int?
    let isForSale: Bool?

    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case description = "Description"
        case creator = "Creator"
        case priceInRobux = "PriceInRobux"
        case isForSale = "IsForSale"
    }
}

private struct EconomyCreator: Decodable {
    let name: String
    let hasVerifiedBadge: Bool

    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case hasVerifiedBadge = "HasVerifiedBadge"
    }
}

private struct ThumbnailResponse: Decodable {
    let data: [ThumbnailItem]
}

private struct ThumbnailItem: Decodable {
    let state: String
    let imageUrl: String
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
