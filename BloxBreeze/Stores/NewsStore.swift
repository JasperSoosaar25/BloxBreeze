import Foundation
import SwiftUI
import UIKit

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var statusMessage: String?
    @Published private(set) var readIDs: Set<String> = []
    @Published private(set) var savedIDs: Set<String> = []
    @Published private(set) var readingDays: Set<String> = []
    @Published var searchText = ""
    @Published var selectedSourceIDs: Set<String> {
        didSet { persist(Array(selectedSourceIDs), key: Keys.selectedSources) }
    }

    private let newsroomService = RobloxNewsroomService()
    private let developerService = DeveloperForumService()
    private let xService = XAPIService()

    private enum Keys {
        static let cache = "news-cache-v1"
        static let lastUpdated = "last-updated-v1"
        static let selectedSources = "selected-sources-v1"
        static let savedIDs = "saved-ids-v1"
        static let readIDs = "read-ids-v1"
        static let readingDays = "reading-days-v1"
    }

    init() {
        let defaults = UserDefaults.standard
        if let cached: [NewsItem] = Self.decode([NewsItem].self, key: Keys.cache) {
            items = cached
        }
        if let timestamp = defaults.object(forKey: Keys.lastUpdated) as? Date {
            lastUpdated = timestamp
        }
        if let selected: [String] = Self.decode([String].self, key: Keys.selectedSources) {
            selectedSourceIDs = Set(selected)
        } else {
            selectedSourceIDs = Set(NewsSource.all.map(\.id))
        }
        savedIDs = Set(Self.decode([String].self, key: Keys.savedIDs) ?? [])
        readIDs = Set(Self.decode([String].self, key: Keys.readIDs) ?? [])
        readingDays = Set(Self.decode([String].self, key: Keys.readingDays) ?? [])
    }

    var hasXToken: Bool {
        guard let token = SecureTokenStore.read() else { return false }
        return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var filteredItems: [NewsItem] {
        items.filter { item in
            let sourceMatches = selectedSourceIDs.contains(item.source.id)
            let queryMatches = searchText.isEmpty || item.searchableText.localizedCaseInsensitiveContains(searchText)
            return sourceMatches && queryMatches
        }
    }

    var savedItems: [NewsItem] {
        items.filter { savedIDs.contains($0.id) }
    }

    var unreadCount: Int {
        filteredItems.filter { !readIDs.contains($0.id) }.count
    }

    var readingStreak: Int {
        let calendar = Calendar.autoupdatingCurrent
        var cursor = calendar.startOfDay(for: .now)
        var streak = 0
        while readingDays.contains(Self.dayFormatter.string(from: cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        var fresh: [NewsItem] = []
        var messages: [String] = []

        do {
            fresh.append(contentsOf: try await newsroomService.fetch())
        } catch {
            messages.append("Newsroom: \(error.localizedDescription)")
        }

        do {
            fresh.append(contentsOf: try await developerService.fetch())
        } catch {
            messages.append("Creator Updates: \(error.localizedDescription)")
        }

        if let token = SecureTokenStore.read(), !token.isEmpty {
            do {
                fresh.append(contentsOf: try await xService.fetch(token: token))
            } catch {
                messages.append("X: \(error.localizedDescription)")
            }
        }

        if !fresh.isEmpty {
            var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            for item in fresh { byID[item.id] = item }
            items = byID.values.sorted { $0.publishedAt > $1.publishedAt }.prefix(250).map { $0 }
            lastUpdated = .now
            persist(items, key: Keys.cache)
            UserDefaults.standard.set(lastUpdated, forKey: Keys.lastUpdated)
        }

        statusMessage = messages.isEmpty ? nil : messages.joined(separator: "\n")
    }

    func saveXToken(_ token: String) async throws {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else { throw FeedError.missingXToken }
        try await xService.validate(token: cleanToken)
        try SecureTokenStore.write(cleanToken)
        await refresh()
    }

    func removeXToken() throws {
        try SecureTokenStore.delete(ignoringMissing: true)
        statusMessage = nil
    }

    func toggleSource(_ source: NewsSource) {
        if selectedSourceIDs.contains(source.id) {
            selectedSourceIDs.remove(source.id)
        } else {
            selectedSourceIDs.insert(source.id)
        }
    }

    func toggleSaved(_ item: NewsItem) {
        if savedIDs.contains(item.id) {
            savedIDs.remove(item.id)
        } else {
            savedIDs.insert(item.id)
        }
        persist(Array(savedIDs), key: Keys.savedIDs)
        if UserDefaults.standard.object(forKey: "gentle-haptics-v1") as? Bool ?? true {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    func markRead(_ item: NewsItem) {
        readIDs.insert(item.id)
        readingDays.insert(Self.dayFormatter.string(from: .now))
        persist(Array(readIDs), key: Keys.readIDs)
        persist(Array(readingDays.suffix(90)), key: Keys.readingDays)
    }

    func clearCache() {
        items.removeAll()
        lastUpdated = nil
        readIDs.removeAll()
        UserDefaults.standard.removeObject(forKey: Keys.cache)
        UserDefaults.standard.removeObject(forKey: Keys.lastUpdated)
        UserDefaults.standard.removeObject(forKey: Keys.readIDs)
    }

    private func persist<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
