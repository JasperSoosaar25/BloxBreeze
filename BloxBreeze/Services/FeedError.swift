import Foundation
import Security

enum FeedError: LocalizedError {
    case invalidResponse
    case server(status: Int, message: String?)
    case parsing(String)
    case missingXToken
    case keychain(OSStatus)

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
        case .missingXToken:
            return "Add an X API bearer token in Settings to load X posts."
        case let .keychain(status):
            return "The Keychain could not complete the request (\(status))."
        }
    }
}
