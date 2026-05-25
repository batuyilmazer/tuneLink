import WidgetKit
import SwiftUI

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let track: String?
    let artist: String?
    let albumArtURL: URL?
    let isPlaying: Bool
}

struct NowPlayingResponse: Decodable {
    let playing: Bool
    let track: String?
    let artist: String?
    let albumArt: String?
}

struct Provider: TimelineProvider {
    private let baseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "http://localhost:3000"
    }()

    private var userId: String {
        UserDefaults(suiteName: AppGroup.suiteName)?.string(forKey: AppGroup.Keys.userId) ?? ""
    }

    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: .now, track: "Song Title", artist: "Artist", albumArtURL: nil, isPlaying: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            // Refresh after 5 minutes as a fallback; APNs push triggers earlier reloads
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> NowPlayingEntry {
        guard !userId.isEmpty,
              let url = URL(string: "\(baseURL)/partner-track?userId=\(userId)") else {
            return NowPlayingEntry(date: .now, track: nil, artist: nil, albumArtURL: nil, isPlaying: false)
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NowPlayingResponse.self, from: data)
            let artURL = response.albumArt.flatMap { URL(string: $0) }
            return NowPlayingEntry(
                date: .now,
                track: response.track,
                artist: response.artist,
                albumArtURL: artURL,
                isPlaying: response.playing
            )
        } catch {
            return NowPlayingEntry(date: .now, track: nil, artist: nil, albumArtURL: nil, isPlaying: false)
        }
    }
}
