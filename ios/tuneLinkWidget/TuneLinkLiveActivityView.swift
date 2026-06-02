import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct TuneLinkLiveActivityView: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TuneLinkActivityAttributes.self) { context in
            LiveActivityLockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityAlbumArt(url: context.state.albumArtURL, size: 52)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        if context.state.isPlaying {
                            Image(systemName: "music.note")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.green)
                        }
                        Text(context.state.friendName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.track)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(context.state.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                LiveActivityAlbumArt(url: context.state.albumArtURL, size: 28)
            } compactTrailing: {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(context.state.isPlaying ? .green : .secondary)
            } minimal: {
                LiveActivityAlbumArt(url: context.state.albumArtURL, size: 24)
            }
        }
    }
}

private struct LiveActivityLockScreenView: View {
    let state: TuneLinkActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            LiveActivityAlbumArt(url: state.albumArtURL, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if state.isPlaying {
                        Image(systemName: "music.note")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    Text(state.friendName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(state.track)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(state.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .activityBackgroundTint(Color(.systemBackground))
    }
}

private struct LiveActivityAlbumArt: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let uiImage = AlbumArtCache.image(for: url) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size * 0.2)
            .fill(Color.secondary.opacity(0.25))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(.secondary)
            )
    }
}
