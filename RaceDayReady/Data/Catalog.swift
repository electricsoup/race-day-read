//
//  Catalog.swift
//  Race Day Ready
//
//  The shapes of the hosted trend feed: the season's race weekends, costume ideas
//  for each race theme, and the content ideas behind the Pro tab.
//

import Foundation

struct RaceDef: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var short: String
    var dist: Double
    var date: String
    var time: String?
    var theme: String?
    var ideas: String?
}

struct ChallengeDef: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var needs: [String]
    var dist: Double
    var theme: String?
}

struct EventDef: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var short: String
    var date: String
    var when: String?
    var place: String?
    var about: String?
    var forRaces: [String]?
    var slot: String?
}

struct ExtraDef: Codable, Hashable {
    var text: String
    var cat: String
    var shared: Bool?
    var bag: String?
}

struct WeekendDef: Codable, Hashable, Identifiable {
    var id: String
    var type: String
    var name: String
    var short: String
    var start: String
    var end: String
    var timeZone: String?
    var tagline: String?
    var climate: String?
    var expo: [String]?
    var races: [RaceDef]
    var challenges: [ChallengeDef]?
    var events: [EventDef]?
    var extras: [ExtraDef]?
}

struct IdeaDef: Codable, Hashable, Identifiable {
    var id: String
    var kind: String
    var title: String
    var platforms: [String]?
    var when: String?
    var hook: String?
    var sound: String?
    var how: String?
    var expires: String?
    var weekendTypes: [String]?
    var costume: Bool?

    var isExpired: Bool {
        guard let expires else { return false }
        return expires < DayKey.today
    }

    var kindLabel: String {
        switch kind {
        case "trend": return "Trending now"
        case "race": return "Race weekend"
        case "park": return "Park & travel"
        case "post": return "After the trip"
        default: return kind.capitalized
        }
    }

    var whenLabel: String {
        switch when ?? "" {
        case "pretrip": return "Before the trip"
        case "travel": return "Travel day"
        case "expo": return "Expo day"
        case "night": return "Night before a race"
        case "racemorning": return "Race morning"
        case "raceday": return "Race day"
        case "park": return "Park day"
        case "party": return "Party night"
        case "post": return "After the trip"
        default: return "Any time"
        }
    }
}

struct Feed: Codable {
    var version: Int
    var updated: String
    var note: String?
    var weekends: [WeekendDef]
    var themeIdeas: [String: [String]]?
    var ideas: [IdeaDef]

    static let empty = Feed(version: 0, updated: "", note: nil, weekends: [], themeIdeas: [:], ideas: [])
}

enum Platform {
    static let all: [(String, String)] = [("tiktok", "TikTok"), ("reels", "Reels"), ("shorts", "Shorts")]
    static func label(_ key: String?) -> String {
        all.first { $0.0 == key }?.1 ?? (key?.capitalized ?? "Any")
    }
}

/// Loads the bundled feed right away, then the last downloaded copy, then checks for a newer one.
@MainActor
final class FeedStore: ObservableObject {
    /// Where the hosted feed lives. Publish feed/feed.json from the repo to this address (see README).
    static let remoteURL = URL(string: "https://electricsoup.github.io/race-day-ready-feed/feed.json")!

    @Published private(set) var feed: Feed = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("feed-cache.json")
    }

    init() {
        if let url = Bundle.main.url(forResource: "feed", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bundled = try? JSONDecoder().decode(Feed.self, from: data) {
            feed = bundled
        }
        if let data = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode(Feed.self, from: data),
           cached.updated >= feed.updated {
            feed = cached
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            var request = URLRequest(url: Self.remoteURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let remote = try JSONDecoder().decode(Feed.self, from: data)
            if remote.updated >= feed.updated {
                feed = remote
                try? data.write(to: cacheURL, options: .atomic)
            }
            lastError = nil
        } catch {
            lastError = "Couldn't check for new ideas. Showing the ones on your phone."
        }
    }

    func weekend(_ id: String?) -> WeekendDef? {
        guard let id else { return nil }
        return feed.weekends.first { $0.id == id }
    }

    func costumeIdeas(for key: String?) -> [String] {
        guard let key, !key.isEmpty else { return [] }
        return feed.themeIdeas?[key] ?? Starters.themeIdeas[key] ?? []
    }

    /// Ideas that fit this kind of weekend and haven't expired.
    func ideas(for weekendType: String?) -> [IdeaDef] {
        feed.ideas.filter { idea in
            if idea.isExpired { return false }
            guard let types = idea.weekendTypes, !types.isEmpty else { return true }
            return types.contains(weekendType ?? "")
        }
    }
}
