import Foundation

struct XPublicProfile: Hashable, Sendable {
    let handle: String
    let name: String
    let biography: String
    let location: String?
    let websiteURL: URL?
    let websiteLabel: String?
    let avatarURL: URL?
    let bannerURL: URL?
    let followers: Int
    let following: Int
    let postCount: Int
    let joinedAt: Date?
    let isVerified: Bool
    let recentPosts: [XProfilePost]
}

struct XProfilePost: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
    let publishedAt: Date
    let replies: Int
    let reposts: Int
    let likes: Int
    let views: Int?
}

struct RobloxCatalogItem: Hashable, Sendable {
    let id: Int64
    let name: String
    let description: String?
    let productType: String?
    let assetTypeID: Int?
    let creatorName: String?
    let creatorID: Int64?
    let creatorIsVerified: Bool
    let price: Int?
    let isForSale: Bool?
    let lowestResalePrice: Int?
    let favoriteCount: Int?
    let sales: Int?
    let totalQuantity: Int?
    let remaining: Int?
    let isLimited: Bool
    let isLimitedUnique: Bool
    let createdAt: Date?
    let updatedAt: Date?
    let thumbnailURL: URL?

    var availability: RobloxCatalogAvailability {
        if let lowestResalePrice, lowestResalePrice > 0 {
            return .resale(lowestPrice: lowestResalePrice)
        }
        if isForSale == true {
            return price == 0 ? .free : .forSale(price: price)
        }
        if isForSale == false {
            return .offSale
        }
        return .unknown
    }

    var assetTypeName: String? {
        guard let assetTypeID else { return nil }
        return RobloxAssetType.name(for: assetTypeID)
    }
}

enum RobloxCatalogAvailability: Hashable, Sendable {
    case forSale(price: Int?)
    case free
    case resale(lowestPrice: Int)
    case offSale
    case unknown
}

struct RobloxMarketplaceCollection: Hashable, Sendable {
    let items: [RobloxMarketplacePreview]
    let filterLabels: [String]
    let note: String?
}

struct RobloxMarketplacePreview: Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let description: String?
    let creatorName: String?
    let creatorIsVerified: Bool
    let price: Int?
    let lowestResalePrice: Int?
    let priceStatus: String?
    let favoriteCount: Int?
    let taxonomyName: String?
    let isCollectible: Bool
    let thumbnailURL: URL?

    var catalogURL: URL {
        let slug = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^A-Za-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return URL(string: "https://www.roblox.com/catalog/\(id)/\(slug.isEmpty ? "item" : slug)")!
    }

    var marketLabel: String {
        if let lowestResalePrice, lowestResalePrice > 0 {
            return "\(lowestResalePrice.formatted()) Robux resale"
        }
        if let priceStatus, !priceStatus.isEmpty { return priceStatus }
        if let price {
            return price == 0 ? "Free" : "\(price.formatted()) Robux"
        }
        return "View details"
    }
}

private enum RobloxAssetType {
    static func name(for id: Int) -> String {
        switch id {
        case 2: "T-Shirt"
        case 8: "Hat / accessory"
        case 11: "Shirt"
        case 12: "Pants"
        case 17: "Head"
        case 18: "Face"
        case 19: "Gear"
        case 41: "Hair accessory"
        case 42: "Face accessory"
        case 43: "Neck accessory"
        case 44: "Shoulder accessory"
        case 45: "Front accessory"
        case 46: "Back accessory"
        case 47: "Waist accessory"
        case 61: "Emote"
        case 62: "Video"
        case 64: "T-Shirt accessory"
        case 65: "Shirt accessory"
        case 66: "Pants accessory"
        case 67: "Jacket accessory"
        case 68: "Sweater accessory"
        case 69: "Shorts accessory"
        case 70: "Left shoe"
        case 71: "Right shoe"
        case 72: "Dress / skirt"
        case 76: "Eyebrow accessory"
        case 77: "Eyelash accessory"
        case 79: "Dynamic head"
        default: "Asset type \(id)"
        }
    }
}
