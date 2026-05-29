import WidgetKit
import SwiftUI

struct MemberStatusWidget: Decodable {
    let userId: String
    let displayName: String
    let playing: Bool
    let track: String?
    let artist: String?
    let albumArt: String?
    let timestamp: Double?
    let lastTrack: String?
    let lastArtist: String?
    let lastAlbumArt: String?
    let lastPlayedAt: Double?

    var albumArtURL: URL? { albumArt.flatMap { URL(string: $0) } }
    var lastAlbumArtURL: URL? { lastAlbumArt.flatMap { URL(string: $0) } }
    var lastPlayedDate: Date? { lastPlayedAt.map { Date(timeIntervalSince1970: $0 / 1000) } }
}

struct GroupEntry: TimelineEntry {
    let date: Date
    let members: [MemberStatusWidget]

    var primary: MemberStatusWidget? {
        members.first(where: { $0.playing }) ?? members.first
    }
}

struct Provider: TimelineProvider {
    private let baseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "http://localhost:3000"
    }()

    private var userId: String {
        UserDefaults(suiteName: AppGroup.suiteName)?.string(forKey: AppGroup.Keys.userId) ?? ""
    }

    private var sessionToken: String {
        UserDefaults(suiteName: AppGroup.suiteName)?.string(forKey: AppGroup.Keys.sessionToken) ?? ""
    }

    func placeholder(in context: Context) -> GroupEntry {
        let sample = MemberStatusWidget(
            userId: "sample", displayName: "Arkadaş", playing: true,
            track: "Song Title", artist: "Artist Name", albumArt: nil, timestamp: nil,
            lastTrack: nil, lastArtist: nil, lastAlbumArt: nil, lastPlayedAt: nil
        )
        return GroupEntry(date: .now, members: [sample])
    }

    func getSnapshot(in context: Context, completion: @escaping (GroupEntry) -> Void) {
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GroupEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func fetchEntry() async -> GroupEntry {
        guard !userId.isEmpty,
              let url = URL(string: "\(baseURL)/group-feed?userId=\(userId)") else {
            return GroupEntry(date: .now, members: [])
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: request)
            let members = try JSONDecoder().decode([MemberStatusWidget].self, from: data)
            return GroupEntry(date: .now, members: members)
        } catch {
            return GroupEntry(date: .now, members: [])
        }
    }
}
