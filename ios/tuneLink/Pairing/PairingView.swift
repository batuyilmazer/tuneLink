import SwiftUI
import WidgetKit

struct MemberStatus: Identifiable, Decodable {
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

    var id: String { userId }

    var albumArtURL: URL? { albumArt.flatMap { URL(string: $0) } }
    var lastAlbumArtURL: URL? { lastAlbumArt.flatMap { URL(string: $0) } }
    var lastPlayedDate: Date? { lastPlayedAt.map { Date(timeIntervalSince1970: $0 / 1000) } }
}

struct GroupFeedView: View {
    private let baseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "http://localhost:3000"
    }()

    @AppStorage("userId", store: UserDefaults(suiteName: AppGroup.suiteName))
    private var userId: String = ""

    @State private var members: [MemberStatus] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && members.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if members.isEmpty {
                    emptyState
                } else {
                    memberList
                }
            }
            .navigationTitle("tuneLink")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Çıkış", action: logout)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if isLoading {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Button(action: { Task { await fetchFeed() } }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .task { await fetchFeed() }
    }

    // MARK: - Subviews

    private var memberList: some View {
        List(members) { member in
            MemberRow(member: member)
        }
        .listStyle(.plain)
        .refreshable { await fetchFeed() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: errorMessage != nil ? "exclamationmark.triangle" : "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(errorMessage != nil ? .red : .secondary)
            Text(errorMessage != nil ? "Bağlantı hatası" : "Henüz kimse yok")
                .font(.title3.bold())
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("Arkadaşların uygulamaya giriş yaptığında burada görünecekler.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Network

    private func fetchFeed() async {
        guard !userId.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            var components = URLComponents(string: "\(baseURL)/group-feed")!
            components.queryItems = [URLQueryItem(name: "userId", value: userId)]
            guard let url = components.url else {
                errorMessage = "Invalid server URL"
                return
            }
            let sessionToken = UserDefaults(suiteName: AppGroup.suiteName)?.string(forKey: AppGroup.Keys.sessionToken) ?? ""
            var request = URLRequest(url: url)
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 401 || statusCode == 403 {
                // Session expired — force re-login
                UserDefaults(suiteName: AppGroup.suiteName)?.removeObject(forKey: AppGroup.Keys.sessionToken)
                userId = ""
                return
            }
            if statusCode < 200 || statusCode >= 300 {
                let serverError = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                errorMessage = serverError ?? "Sunucu hatası (\(statusCode))"
                return
            }
            members = try JSONDecoder().decode([MemberStatus].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Logout

    private func logout() {
        Task {
            let defaults = UserDefaults(suiteName: AppGroup.suiteName)
            let sessionToken = defaults?.string(forKey: AppGroup.Keys.sessionToken) ?? ""
            if !userId.isEmpty, !sessionToken.isEmpty, let url = URL(string: "\(baseURL)/auth/logout") {
                var req = URLRequest(url: url)
                req.httpMethod = "DELETE"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
                req.httpBody = try? JSONSerialization.data(withJSONObject: ["userId": userId])
                try? await URLSession.shared.data(for: req)
            }
            defaults?.removeObject(forKey: AppGroup.Keys.deviceToken)
            defaults?.removeObject(forKey: AppGroup.Keys.sessionToken)
            userId = ""
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: MemberStatus

    var body: some View {
        HStack(spacing: 14) {
            albumArt
            info
            Spacer(minLength: 0)
            statusBadge
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var albumArt: some View {
        let url = member.playing ? member.albumArtURL : member.lastAlbumArtURL
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: artPlaceholder
                    }
                }
            } else {
                artPlaceholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(member.playing ? 1.0 : 0.45)
    }

    private var artPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.2))
            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
    }

    @ViewBuilder
    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(member.displayName)
                .font(.subheadline.bold())
                .lineLimit(1)

            if member.playing, let track = member.track, let artist = member.artist {
                Text(track)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let track = member.lastTrack, let artist = member.lastArtist {
                Text(track)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(artist)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else {
                Text("Şu an dinlemiyor")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if member.playing {
            Image(systemName: "music.note")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        } else if let date = member.lastPlayedDate {
            Text(relativeTime(date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private func relativeTime(_ date: Date) -> String {
    let seconds = Int(Date.now.timeIntervalSince(date))
    if seconds < 60 { return "\(seconds)s önce" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)dk önce" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)sa önce" }
    return "\(hours / 24)g önce"
}
