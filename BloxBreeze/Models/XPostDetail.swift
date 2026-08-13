import Foundation

struct XPostDetail: Hashable, Sendable {
    let text: String
    let media: [XPostMedia]
}

struct XThreadReply: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let text: String
    let publishedAt: Date
    let articleURL: URL?
}

struct XPostMedia: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case image
        case video
    }

    let kind: Kind
    let url: URL
    let previewURL: URL?
    let aspectRatio: Double?

    var id: String { "\(kind.rawValue):\(url.absoluteString)" }
}

struct ZoomableImageItem: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
}
