import Foundation

struct NativeArticle: Codable, Hashable, Sendable {
    let title: String
    let subtitle: String?
    let byline: String?
    let publishedAt: Date
    let heroImageURL: URL?
    let blocks: [NativeArticleBlock]
}

struct NativeArticleBlock: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case heading
        case paragraph
        case bullet
        case quote
        case image
    }

    let id: String
    let kind: Kind
    let text: String?
    let imageURL: URL?
    let caption: String?
    let headingLevel: Int?
}

