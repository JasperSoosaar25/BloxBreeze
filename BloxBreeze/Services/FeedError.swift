import Foundation

enum FeedError: LocalizedError {
    case invalidResponse
    case server(status: Int, message: String?)
    case parsing(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The news source returned an unreadable response."
        case let .server(status, message):
            if let message, !message.isEmpty {
                return "The source returned \(status): \(message)"
            }
            return "The source returned HTTP \(status)."
        case let .parsing(message):
            return message
        }
    }
}
