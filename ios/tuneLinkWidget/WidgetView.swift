import SwiftUI
import WidgetKit

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

// MARK: - Home Screen Widget

struct HomeWidgetView: View {
    let entry: GroupEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        content
            .widgetBackground { Color(.systemBackground) }
    }

    @ViewBuilder
    private var content: some View {
        if family == .systemMedium {
            mediumContent
        } else {
            smallContent
        }
    }

    // Small: show the most relevant member (first playing, else first with last track)
    @ViewBuilder
    private var smallContent: some View {
        if let member = entry.primary {
            MemberSmallView(member: member)
        } else {
            emptyView
        }
    }

    // Medium: show up to 2 members side by side
    @ViewBuilder
    private var mediumContent: some View {
        let visible = Array(entry.members.prefix(2))
        if visible.isEmpty {
            emptyView
        } else if visible.count == 1 {
            MemberMediumRowView(member: visible[0])
                .padding(10)
        } else {
            VStack(spacing: 0) {
                MemberMediumRowView(member: visible[0])
                Divider()
                MemberMediumRowView(member: visible[1])
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note.list")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("Kimse dinlemiyor")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }
}

// MARK: - Small member cell

private struct MemberSmallView: View {
    let member: MemberStatusWidget

    var body: some View {
        if member.playing, let track = member.track, let artist = member.artist {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    AlbumArtView(url: member.albumArtURL, size: 56)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 6)
                Text(track)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(artist)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 2)
                Spacer(minLength: 4)
                Text("♫ \(member.displayName)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(8)
        } else if let track = member.lastTrack, let artist = member.lastArtist {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    AlbumArtView(url: member.lastAlbumArtURL, size: 56, dimmed: true)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 6)
                Text(track)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(artist)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .padding(.top, 2)
                Spacer(minLength: 4)
                Text(member.lastPlayedDate.map { relativeTime($0) } ?? member.displayName)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(8)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(member.displayName) dinlemiyor")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Medium member row

private struct MemberMediumRowView: View {
    let member: MemberStatusWidget

    var body: some View {
        HStack(spacing: 10) {
            let artURL = member.playing ? member.albumArtURL : member.lastAlbumArtURL
            AlbumArtView(url: artURL, size: 40, dimmed: !member.playing)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                if member.playing, let track = member.track, let artist = member.artist {
                    Text(track)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let track = member.lastTrack {
                    Text(track)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let date = member.lastPlayedDate {
                        Text(relativeTime(date))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Dinlemiyor")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)

            if member.playing {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Lock Screen

struct AccessoryRectangularView: View {
    let entry: GroupEntry

    var body: some View {
        content.widgetBackground { }
    }

    @ViewBuilder
    private var content: some View {
        if let member = entry.primary {
            if member.playing, let track = member.track, let artist = member.artist {
                VStack(alignment: .leading, spacing: 1) {
                    Label(track, systemImage: "music.note")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(artist).lineLimit(1)
                        Text("· \(member.displayName)")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
            } else if let track = member.lastTrack, let artist = member.lastArtist {
                VStack(alignment: .leading, spacing: 1) {
                    Label(track, systemImage: "music.note")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(artist).lineLimit(1)
                        if let date = member.lastPlayedDate {
                            Text("· \(relativeTime(date))")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }
            } else {
                Label("\(member.displayName) dinlemiyor", systemImage: "music.note.list")
                    .font(.system(size: 11))
            }
        } else {
            Label("Not listening", systemImage: "music.note.list")
                .font(.system(size: 11))
        }
    }
}

struct AccessoryCircularView: View {
    let entry: GroupEntry

    var body: some View {
        content.widgetBackground { }
    }

    @ViewBuilder
    private var content: some View {
        if let member = entry.primary {
            if member.playing {
                ZStack {
                    AlbumArtView(url: member.albumArtURL, size: 40)
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            } else if member.lastAlbumArtURL != nil {
                AlbumArtView(url: member.lastAlbumArtURL, size: 40, dimmed: true)
            } else {
                Image(systemName: "music.note.list").font(.system(size: 16))
            }
        } else {
            Image(systemName: "music.note.list").font(.system(size: 16))
        }
    }
}

// MARK: - Shared Helpers

struct AlbumArtView: View {
    let url: URL?
    let size: CGFloat
    var dimmed: Bool = false

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(dimmed ? 0.45 : 1)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.3))
            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
    }
}

func relativeTime(_ date: Date) -> String {
    let seconds = Int(Date.now.timeIntervalSince(date))
    if seconds < 60 { return "\(seconds)s önce" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)dk önce" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)sa önce" }
    return "\(hours / 24)g önce"
}
