import SwiftUI
import WidgetKit

// iOS 16/17 compat: containerBackground(for:) is iOS 17+
extension View {
    @ViewBuilder
    func widgetBackground<B: View>(@ViewBuilder background: () -> B) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget, content: background)
        } else {
            self.background(background())
        }
    }
}

// 12.2 — Home screen widget view
struct HomeWidgetView: View {
    let entry: NowPlayingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        content
            .widgetBackground { Color(.systemBackground) }
    }

    @ViewBuilder
    private var content: some View {
        if family == .systemSmall {
            smallContent
        } else {
            mediumContent
        }
    }

    // Small widget: vertical stack — album art, track, artist, partner name at bottom
    @ViewBuilder
    private var smallContent: some View {
        if entry.isPlaying, let track = entry.track, let artist = entry.artist {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    AlbumArtView(url: entry.albumArtURL, size: 56)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 6)
                Text(track)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)
                Text(artist)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 2)
                Spacer(minLength: 4)
                Text("♫ \(entry.partnerName ?? "Partner")")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(12)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(entry.partnerName ?? "Partner") dinlemiyor")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    // Medium widget: horizontal layout with partner name label
    @ViewBuilder
    private var mediumContent: some View {
        if entry.isPlaying, let track = entry.track, let artist = entry.artist {
            HStack(spacing: 10) {
                AlbumArtView(url: entry.albumArtURL, size: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.partnerName ?? "Partner")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Text(track)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        } else {
            Text("\(entry.partnerName ?? "Partner") dinlemiyor")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(12)
        }
    }
}

// 12.3 — Lock screen accessory views
struct AccessoryRectangularView: View {
    let entry: NowPlayingEntry

    var body: some View {
        content
            .widgetBackground { }
    }

    @ViewBuilder
    private var content: some View {
        if entry.isPlaying, let track = entry.track, let artist = entry.artist {
            VStack(alignment: .leading, spacing: 1) {
                Label(track, systemImage: "music.note")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(artist)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
        } else {
            Label("Not listening", systemImage: "music.note.list")
                .font(.system(size: 11))
        }
    }
}

struct AccessoryCircularView: View {
    let entry: NowPlayingEntry

    var body: some View {
        content
            .widgetBackground { }
    }

    @ViewBuilder
    private var content: some View {
        if entry.isPlaying {
            ZStack {
                AlbumArtView(url: entry.albumArtURL, size: 40)
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        } else {
            Image(systemName: "music.note.list")
                .font(.system(size: 16))
        }
    }
}

private struct AlbumArtView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.3))
            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
    }
}
