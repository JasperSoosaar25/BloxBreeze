import Foundation

struct RobloxCatalogService: Sendable {
    func fetch(url: URL) async -> RobloxCatalogItem? {
        guard let identity = Self.identity(from: url) else { return nil }
        async let details = fetchDetails(id: identity.id)
        async let favorites = fetchFavoriteCount(id: identity.id)
        async let thumbnail = fetchThumbnail(id: identity.id)
        let loadedDetails = await details
        let loadedFavorites = await favorites
        let loadedThumbnail = await thumbnail

        return Self.makeItem(
            id: identity.id,
            fallbackName: identity.fallbackName,
            details: loadedDetails,
            favoriteCount: loadedFavorites,
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

    private func fetchFavoriteCount(id: Int64) async -> Int? {
        guard let url = URL(string: "https://catalog.roblox.com/v1/favorites/assets/\(id)/count"),
              let data = try? await fetchData(from: url) else { return nil }
        return try? JSONDecoder().decode(Int.self, from: data)
    }

    private func fetchThumbnail(id: Int64) async -> URL? {
        guard var components = URLComponents(string: "https://thumbnails.roblox.com/v1/assets") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "assetIds", value: String(id)),
            URLQueryItem(name: "returnPolicy", value: "PlaceHolder"),
            URLQueryItem(name: "size", value: "420x420"),
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
        request.setValue("BloxBreeze/1.7.1 (iOS; native Roblox link reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { throw FeedError.invalidResponse }
        return data
    }

    private static func makeItem(
        id: Int64,
        fallbackName: String,
        details: EconomyDetails?,
        favoriteCount: Int?,
        thumbnailURL: URL?
    ) -> RobloxCatalogItem {
        let collectible = details?.collectiblesItemDetails
        return RobloxCatalogItem(
            id: id,
            name: details?.name ?? fallbackName,
            description: details?.description?.nonEmpty,
            productType: details?.productType,
            assetTypeID: details?.assetTypeID,
            creatorName: details?.creator?.name,
            creatorID: details?.creator?.id,
            creatorIsVerified: details?.creator?.hasVerifiedBadge ?? false,
            price: details?.priceInRobux,
            isForSale: collectible?.isForSale ?? details?.isForSale,
            lowestResalePrice: collectible?.collectibleLowestResalePrice,
            favoriteCount: favoriteCount,
            sales: details?.sales,
            totalQuantity: collectible?.totalQuantity,
            remaining: details?.remaining,
            isLimited: collectible?.isLimited ?? details?.isLimited ?? false,
            isLimitedUnique: details?.isLimitedUnique ?? false,
            createdAt: robloxDate(details?.created),
            updatedAt: robloxDate(details?.updated),
            thumbnailURL: thumbnailURL
        )
    }

    static func parseForTesting(
        id: Int64,
        fallbackName: String,
        detailsData: Data,
        favoriteData: Data? = nil
    ) throws -> RobloxCatalogItem {
        let details = try JSONDecoder().decode(EconomyDetails.self, from: detailsData)
        let favorites = favoriteData.flatMap { try? JSONDecoder().decode(Int.self, from: $0) }
        return makeItem(
            id: id,
            fallbackName: fallbackName,
            details: details,
            favoriteCount: favorites,
            thumbnailURL: nil
        )
    }

    private static func robloxDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter.robloxFractional.date(from: value) ??
            ISO8601DateFormatter.robloxStandard.date(from: value)
    }
}

struct RobloxMarketplaceService: Sendable {
    static func isMarketplaceURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              host == "roblox.com" || host.hasSuffix(".roblox.com") else { return false }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.first?.caseInsensitiveCompare("catalog") == .orderedSame else { return false }
        return parts.count == 1 || Int64(parts[1]) == nil
    }

    func fetch(url: URL) async -> RobloxMarketplaceCollection? {
        guard let requestURL = Self.requestURL(from: url),
              let searchData = try? await fetchData(from: requestURL),
              let response = try? JSONDecoder().decode(MarketplaceSearchResponse.self, from: searchData) else {
            return nil
        }

        let assetIDs = response.data
            .filter { $0.itemType.caseInsensitiveCompare("Asset") == .orderedSame }
            .prefix(12)
            .map(\.id)
        let thumbnails = await fetchThumbnails(ids: Array(assetIDs))
        return Self.makeCollection(response: response, sourceURL: url, thumbnails: thumbnails)
    }

    static func parseForTesting(
        sourceURL: URL,
        searchData: Data,
        thumbnailData: Data? = nil
    ) throws -> RobloxMarketplaceCollection {
        let response = try JSONDecoder().decode(MarketplaceSearchResponse.self, from: searchData)
        let thumbnailResponse = thumbnailData.flatMap {
            try? JSONDecoder().decode(ThumbnailResponse.self, from: $0)
        }
        let thumbnails = thumbnailResponse?.data.reduce(into: [Int64: URL]()) { result, thumbnail in
                guard let targetID = thumbnail.targetId,
                      thumbnail.state.caseInsensitiveCompare("Completed") == .orderedSame,
                      let imageURL = URL(string: thumbnail.imageUrl) else { return }
                result[targetID] = imageURL
            } ?? [:]
        return makeCollection(response: response, sourceURL: sourceURL, thumbnails: thumbnails)
    }

    private static func makeCollection(
        response: MarketplaceSearchResponse,
        sourceURL: URL,
        thumbnails: [Int64: URL]
    ) -> RobloxMarketplaceCollection {
        let items = response.data
            .filter { $0.itemType.caseInsensitiveCompare("Asset") == .orderedSame }
            .prefix(12)
            .map { item in
                RobloxMarketplacePreview(
                    id: item.id,
                    name: item.name,
                    description: item.description?.nonEmpty,
                    creatorName: item.creatorName?.nonEmpty,
                    creatorIsVerified: item.creatorHasVerifiedBadge ?? false,
                    price: item.price,
                    lowestResalePrice: item.lowestResalePrice,
                    priceStatus: item.priceStatus?.nonEmpty,
                    favoriteCount: item.favoriteCount,
                    taxonomyName: item.taxonomy?.first?.taxonomyName.nonEmpty,
                    isCollectible: (item.itemRestrictions ?? []).contains {
                        $0.caseInsensitiveCompare("Collectible") == .orderedSame ||
                            $0.localizedCaseInsensitiveContains("Limited")
                    },
                    thumbnailURL: thumbnails[item.id]
                )
            }
        let presentation = presentation(for: sourceURL)
        return RobloxMarketplaceCollection(
            items: items,
            filterLabels: presentation.labels,
            note: presentation.note
        )
    }

    private static func requestURL(from sourceURL: URL) -> URL? {
        guard isMarketplaceURL(sourceURL),
              var components = URLComponents(string: "https://catalog.roblox.com/v2/search/items/details") else {
            return nil
        }
        let values = queryValues(from: sourceURL)
        var queryItems = [
            URLQueryItem(name: "Category", value: values["category"] ?? "1"),
            URLQueryItem(name: "Limit", value: "28")
        ]

        // Roblox share URLs can contain an opaque taxonomy token that the public search API
        // does not accept. In that case, keep the original address and show live Marketplace
        // picks instead of failing the link as an empty article.
        let supported: [(source: String, destination: String)] = [
            ("keyword", "Keyword"),
            ("creatorname", "CreatorName"),
            ("creatortargetid", "CreatorTargetId"),
            ("creatortype", "CreatorType"),
            ("minprice", "MinPrice"),
            ("maxprice", "MaxPrice"),
            ("sorttype", "SortType"),
            ("sortaggregation", "SortAggregation"),
            ("includenotforsale", "IncludeNotForSale"),
            ("salestypefilter", "SalesTypeFilter"),
            ("subcategory", "Subcategory")
        ]
        for entry in supported {
            guard let value = values[entry.source], !value.isEmpty else { continue }
            queryItems.append(URLQueryItem(name: entry.destination, value: value))
        }
        components.queryItems = queryItems
        return components.url
    }

    private static func presentation(for sourceURL: URL) -> (labels: [String], note: String?) {
        let values = queryValues(from: sourceURL)
        var labels: [String] = []
        if values["taxonomy"] != nil { labels.append("Shared collection") }
        if let keyword = values["keyword"], !keyword.isEmpty { labels.append("Search: \(keyword)") }
        if let sort = values["sorttype"] {
            let names = ["0": "Relevant", "1": "Most favorited", "2": "Best selling", "3": "Recently updated", "4": "Lowest price", "5": "Highest price"]
            if let name = names[sort] { labels.append(name) }
        }
        if values["includenotforsale"]?.lowercased() == "false" { labels.append("Available items") }
        if labels.isEmpty { labels.append("Live Marketplace") }

        let note = values["taxonomy"] == nil ? nil :
            "Roblox's shared category token is preserved in the original address. This native preview shows current Marketplace picks, and every item opens its live details inside BloxBreeze."
        return (labels, note)
    }

    private static func queryValues(from url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return items.reduce(into: [String: String]()) { result, item in
            guard let value = item.value else { return }
            result[item.name.lowercased()] = value
        }
    }

    private func fetchThumbnails(ids: [Int64]) async -> [Int64: URL] {
        guard !ids.isEmpty,
              var components = URLComponents(string: "https://thumbnails.roblox.com/v1/assets") else { return [:] }
        components.queryItems = [
            URLQueryItem(name: "assetIds", value: ids.map { String($0) }.joined(separator: ",")),
            URLQueryItem(name: "returnPolicy", value: "PlaceHolder"),
            URLQueryItem(name: "size", value: "420x420"),
            URLQueryItem(name: "format", value: "Png"),
            URLQueryItem(name: "isCircular", value: "false")
        ]
        guard let url = components.url,
              let data = try? await fetchData(from: url),
              let response = try? JSONDecoder().decode(ThumbnailResponse.self, from: data) else { return [:] }
        return response.data.reduce(into: [Int64: URL]()) { result, thumbnail in
            guard let targetID = thumbnail.targetId,
                  thumbnail.state.caseInsensitiveCompare("Completed") == .orderedSame,
                  let imageURL = URL(string: thumbnail.imageUrl) else { return }
            result[targetID] = imageURL
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("BloxBreeze/1.7.1 (iOS; native Roblox Marketplace reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { throw FeedError.invalidResponse }
        return data
    }
}

private struct EconomyDetails: Decodable {
    let name: String
    let description: String?
    let productType: String?
    let assetTypeID: Int?
    let creator: EconomyCreator?
    let priceInRobux: Int?
    let isForSale: Bool?
    let sales: Int?
    let isLimited: Bool?
    let isLimitedUnique: Bool?
    let remaining: Int?
    let created: String?
    let updated: String?
    let collectiblesItemDetails: CollectiblesItemDetails?

    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case description = "Description"
        case productType = "ProductType"
        case assetTypeID = "AssetTypeId"
        case creator = "Creator"
        case priceInRobux = "PriceInRobux"
        case isForSale = "IsForSale"
        case sales = "Sales"
        case isLimited = "IsLimited"
        case isLimitedUnique = "IsLimitedUnique"
        case remaining = "Remaining"
        case created = "Created"
        case updated = "Updated"
        case collectiblesItemDetails = "CollectiblesItemDetails"
    }
}

private struct EconomyCreator: Decodable {
    let id: Int64?
    let name: String
    let hasVerifiedBadge: Bool

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case hasVerifiedBadge = "HasVerifiedBadge"
    }
}

private struct CollectiblesItemDetails: Decodable {
    let collectibleLowestResalePrice: Int?
    let isForSale: Bool?
    let totalQuantity: Int?
    let isLimited: Bool?

    private enum CodingKeys: String, CodingKey {
        case collectibleLowestResalePrice = "CollectibleLowestResalePrice"
        case isForSale = "IsForSale"
        case totalQuantity = "TotalQuantity"
        case isLimited = "IsLimited"
    }
}

private struct ThumbnailResponse: Decodable {
    let data: [ThumbnailItem]
}

private struct ThumbnailItem: Decodable {
    let targetId: Int64?
    let state: String
    let imageUrl: String
}

private struct MarketplaceSearchResponse: Decodable {
    let data: [MarketplaceSearchItem]
}

private struct MarketplaceSearchItem: Decodable {
    let id: Int64
    let itemType: String
    let name: String
    let description: String?
    let creatorName: String?
    let creatorHasVerifiedBadge: Bool?
    let price: Int?
    let lowestResalePrice: Int?
    let priceStatus: String?
    let favoriteCount: Int?
    let itemRestrictions: [String]?
    let taxonomy: [MarketplaceTaxonomy]?
}

private struct MarketplaceTaxonomy: Decodable {
    let taxonomyName: String
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

private extension ISO8601DateFormatter {
    static let robloxFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let robloxStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
