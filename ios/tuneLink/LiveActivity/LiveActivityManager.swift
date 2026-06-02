import ActivityKit
import Foundation

@available(iOS 16.2, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    func updateOrStart(with members: [MemberStatus]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let primary = members.first(where: { $0.playing })
            ?? members.first(where: { $0.lastTrack != nil })

        guard let primary else {
            Task { await endAll() }
            return
        }

        let artURL = primary.playing ? primary.albumArtURL : primary.lastAlbumArtURL

        Task {
            if let artURL { await AlbumArtCache.prefetch(artURL) }

            let activeURLs = members.compactMap { $0.playing ? $0.albumArtURL : $0.lastAlbumArtURL }
            AlbumArtCache.evictStale(keeping: activeURLs)

            let state = TuneLinkActivityAttributes.ContentState(
                friendName: primary.displayName,
                track: primary.playing ? (primary.track ?? "") : (primary.lastTrack ?? ""),
                artist: primary.playing ? (primary.artist ?? "") : (primary.lastArtist ?? ""),
                albumArtURL: artURL,
                isPlaying: primary.playing
            )

            if let existing = Activity<TuneLinkActivityAttributes>.activities.first,
               existing.activityState == .active {
                await existing.update(ActivityContent(state: state, staleDate: nil))
            } else {
                await endAll()
                start(with: state)
            }
        }
    }

    func endAll() async {
        for activity in Activity<TuneLinkActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func start(with state: TuneLinkActivityAttributes.ContentState) {
        do {
            _ = try Activity.request(
                attributes: TuneLinkActivityAttributes(),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("[LiveActivity] start failed: \(error)")
        }
    }
}
